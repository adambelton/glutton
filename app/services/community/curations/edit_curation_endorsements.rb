module Community
  module Curations
    class EditCurationEndorsements
      def self.load_for_edit(curation_id:, community_user:)
        raise Errors::PostingUnavailable unless community_user&.ready_to_post?

        PostCommunityCuration.transaction do
          curation = PostCommunityCuration.lock.find(curation_id)
          endorsements = active_endorsements(curation:, community_user:)
          state = endorsement_state(endorsements)
          snapshot = verifier.generate([ curation.id, community_user.user_id, state ])
          editor(curation:, community_user:, endorsements:, film_ids: endorsements.keys, comments: {}, snapshot:, saved_film_ids: endorsements.keys)
        end
      end

      def self.call(curation_id:, community_user:, film_ids:, comments:, snapshot:)
        Membership::WithProfileForUpdate.call(community_user:) do |community_user|
          raise Errors::PostingUnavailable unless community_user&.ready_to_post?

          curation = PostCommunityCuration.lock.find(curation_id)
          endorsements = active_endorsements(curation:, community_user:)
          snapshot_post_id, snapshot_user_id, state = verifier.verified(snapshot)
          same_editor = snapshot_post_id == curation.id && snapshot_user_id == community_user.user_id
          saved_film_ids = same_editor ? state.map { |_, film_id, *| film_id } : endorsements.keys
          stale = !same_editor || state != endorsement_state(endorsements)
          if stale
            curation.errors.add(:base, :stale_endorsements)
          else
            curation.edit_endorsements(community_user:, endorsements:, film_ids:, comments:) do |new_film_ids|
              BrowseEligibleCurationFilms.lock_for_submission(community_user:, film_ids: new_film_ids)
            end
          end

          if curation.errors.any?
            editor(curation:, community_user:, endorsements:, film_ids:, comments:, snapshot:, saved_film_ids:, stale:) do |missing_film_ids|
              Registry::CatalogueQueries::BrowseCatalogue.films_for_ids(film_ids: missing_film_ids)
            end
          else
            { curation: }
          end
        end
      end

      def self.active_endorsements(curation:, community_user:)
        curation.film_endorsements.active.where(user_id: community_user.user_id).preload(:film, comments: :content).order(:id).index_by(&:film_id)
      end

      def self.endorsement_state(endorsements)
        endorsements.values.map do |endorsement|
          content = endorsement.opening_comment&.content
          revision = [ content.id, content.updated_at.iso8601(6), Digest::SHA256.hexdigest(content.body) ] if content.present?
          [ endorsement.id, endorsement.film_id, revision ]
        end
      end

      def self.editor(curation:, community_user:, endorsements:, film_ids:, comments:, snapshot:, saved_film_ids:, stale: false)
        search_films = BrowseEligibleCurationFilms.choices(community_user:)
        saved_films = endorsements.values.map(&:film)
        if stale
          saved_films += yield((film_ids & saved_film_ids) - endorsements.keys)
        end
        published_comments = endorsements.transform_values(&:opening_comment).compact
        { curation:, search_films:, films: (saved_films + search_films).uniq, film_ids:, comments:, published_comments:,
          snapshot:, saved_film_ids:, stale: }
      end

      def self.verifier
        Rails.application.message_verifier(:curation_endorsement_editor)
      end

      private_class_method :active_endorsements, :endorsement_state, :editor, :verifier
    end
  end
end
