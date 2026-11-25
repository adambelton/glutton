module Ratings
  module TasteProfiling
    class ViewTasteProfile
      def self.call(user_id:)
        new(user_id:).call
      end

      def self.inspect_saved(user_id:)
        new(user_id:).inspect_saved
      end

      def initialize(user_id:)
        @user_id = user_id
      end

      def call
        revision = current_revision
        profile_summary(revision).merge(changes: changes(revision, current_notes))
      end

      def inspect_saved
        raise Identity::Errors::Unavailable unless Identity::User.exists?(@user_id)

        revision = current_revision
        profile_summary(revision).merge(revision:, claims: saved_claims(revision))
      end

      private

      def current_revision
        TasteProfile.find_by(user_id: @user_id)&.current_revision
      end

      def profile_summary(revision)
        { profile: revision&.profile, quality_rankings: quality_rankings }
      end

      def saved_claims(revision)
        return [] unless revision.present? && revision.annotations.present?

        evidence = revision.taste_profile_revision_eval.output.fetch("evidence").index_by { |note| note.fetch("rating_id") }
        revision.annotations.map do |annotation|
          citations = annotation.fetch("citations").map do |citation|
            rating_id = citation.fetch("rating_id")
            note = evidence.fetch(rating_id)
            first, last = citation.values_at("start_offset", "end_offset")
            { rating_id:, title: note.fetch("film_title"), release_date: saved_release_date(note), quote: note.fetch("text")[first...last] }
          end
          { claim: annotation.fetch("claim"), explanation: annotation.fetch("explanation"), citations: }
        end
      end

      def saved_release_date(note)
        value = note["film_release_date"]
        Date.iso8601(value) if value.present?
      rescue ArgumentError, TypeError
        nil
      end

      def quality_rankings
        totals = RatingQuality.current_rating_qualities_for_user(user_id: @user_id).group(:quality_id).sum(:score)
        positive, negative = totals.reject { |_, score| score.zero? }.partition { |_, score| score.positive? }
        top = positive.sort_by { |id, score| [ -score, id ] }.first(10).map(&:first)
        bottom = negative.sort_by { |id, score| [ score, id ] }.first(10).map(&:first)
        qualities = Registry::Quality.where(id: top + bottom).index_by(&:id)
        { top: ranked_qualities(top, totals, qualities), bottom: ranked_qualities(bottom, totals, qualities) }
      end

      def ranked_qualities(ids, totals, qualities)
        ids.map do |id|
          quality = qualities.fetch(id)
          { name: quality.name, definition: quality.match_rule, score: totals.fetch(id) }
        end
      end

      def current_notes
        Rating.current.joins(:rating_film).where(rating_films: { user_id: @user_id })
          .order(:id).pluck("rating_films.film_id", "ratings.notes").to_h.compact
      end

      def changes(revision, current)
        saved = (revision&.notes || []).to_h { |row| row.values_at("film_id", "text") }
        films = Registry::Film.where(id: current.keys | saved.keys).pluck(:id, :title, :release_date).to_h do |id, title, release_date|
          [ id, [ title, release_date ] ]
        end
        historical_films = revision&.taste_profile_revision_eval&.output&.fetch("evidence", [])&.to_h do |row|
          [ row.fetch("film_id"), [ row.fetch("film_title"), saved_release_date(row) ] ]
        end || {}

        (current.keys | saved.keys).filter_map do |film_id|
          before, after = saved[film_id], current[film_id]
          next if before == after

          title, release_date = films[film_id] || historical_films[film_id]
          { title:, release_date:, added: Array(after), removed: Array(before) }
        end
      end
    end
  end
end
