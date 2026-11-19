module Ratings
  module TasteProfiling
    class RefreshTasteProfile
      TRACE_NAME = "refresh-taste-profile".freeze
      TRACE_TAGS = [ "ratings", "taste-profile" ].freeze

      def self.call(user_id:, client: Rails.application.config.x.openai_client, tracer_provider: ActivityMonitoring.model_provider)
        new(user_id:, client:, tracer_provider:).call
      end

      def initialize(user_id:, client:, tracer_provider:)
        @user_id, @client, @tracer_provider = user_id, client, tracer_provider
      end

      def call
        current, evidence = with_owner_lock { |user| [ TasteProfile.find_by(user:)&.current_revision, capture_evidence ] }
        notes = texts_by_film(evidence)
        unchanged = notes == texts_by_film(current&.notes || [])
        return current if unchanged

        links = Monitoring::TraceContext.links_for_ratings(evidence.pluck("rating_id"))
        ActivityMonitoring.trace_business_operation("refresh taste profile", parent: nil, links:, attributes: { ActivityMonitoring::Attributes::USER_ID => @user_id }) do
          revision = generate_and_apply(current:, evidence:)
          ActivityMonitoring.current&.set_profile_revision_id(revision.id)
          revision
        end
      end

      private

      def generate_and_apply(current:, evidence:)
        ActivityMonitoring.trace_model(TRACE_NAME, scope: ActivityMonitoring::Scopes::RATINGS, provider: @tracer_provider, tags: TRACE_TAGS,
          input: { notes_count: evidence.size }) do |span, tracer|
          assessment = GenerateTasteProfile.new(evidence:, basis: current&.incremental_synthesis_basis,
            trace_id: span.trace_id, tracer:, trace_tags: TRACE_TAGS)
          assessment.call(client: @client)
          revision = ActivityMonitoring.within_business_context { record_and_apply(current:, assessment:) }
          span.set_attribute("taste_profile_id", revision.taste_profile_id)
          span.set_attribute("taste_profile_revision_id", revision.id)
          span.set_attribute("taste_profile_revision_eval_id", revision.taste_profile_revision_eval_id)
          revision
        end
      end

      def with_owner_lock
        TasteProfile.transaction(requires_new: true) do
          user = Identity::User.lock.find_by(id: @user_id)
          raise Identity::Errors::Unavailable unless user&.active?

          yield user
        end
      end

      def capture_evidence
        Rating.current.joins(rating_film: :film).where.not(notes: nil)
          .where(rating_films: { user_id: @user_id }).order(:id)
          .pluck("ratings.id", "films.id", "films.title", "films.release_date", "ratings.notes", "films.wikipedia_context")
          .map do |rating_id, film_id, title, release_date, text, context|
            { "rating_id" => rating_id, "film_id" => film_id,
              "film_title" => title, "film_release_date" => release_date&.iso8601, "text" => text,
              "source_paragraphs" => context.fetch("source_paragraphs", []),
              "source_revision_id" => context["revision_id"], "source_revision_url" => context["revision_url"] }
          end
      end

      def texts_by_film(evidence)
        evidence.group_by { |note| note.fetch("film_id") }.transform_values { |note| note.pluck("text") }
      end

      def synthesis_evidence(evidence)
        evidence.index_by { |note| note.fetch("film_id") }.transform_values do |note|
          note.except("rating_id", "film_release_date")
        end
      end

      def record_and_apply(current:, assessment:)
        with_owner_lock do |user|
          taste_profile = TasteProfile.find_by(user:)
          unless taste_profile&.current_revision&.id == current&.id &&
              synthesis_evidence(capture_evidence) == synthesis_evidence(assessment.result.fetch("evidence"))
            raise Errors::TasteProfileRefreshFailed.new(reason: :stale_inputs)
          end

          taste_profile ||= TasteProfile.create!(user:)
          evaluation = TasteProfileRevisionEval.record!(taste_profile:, assessment:)
          revision = taste_profile.publish_revision!(evaluation:)
          RatingQualityReassessmentRequest.mark_pending!(user:, revision:)
          ReassessRatingQualitiesJob.enqueue!(user_id: user.id, profile_revision_id: revision.id)
          revision
        end
      end
    end
  end
end
