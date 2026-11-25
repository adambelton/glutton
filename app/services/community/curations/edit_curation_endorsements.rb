module Community
  module Curations
    class EditCurationEndorsements
      def self.load_for_edit(curation_id:, member:)
        raise Errors::PostingUnavailable unless Membership::PostingAccess.allowed?(user: member)

        PostCommunityCuration.transaction do
          curation = PostCommunityCuration.lock.find(curation_id)
          endorsements = active_endorsements(curation:, member:)
          state = endorsement_state(endorsements)
          snapshot = verifier.generate([ curation.id, member.id, state ])
          editor(curation:, member:, endorsements:, film_ids: endorsements.keys, comments: {}, snapshot:, saved_film_ids: endorsements.keys)
        end
      end

      def self.call(curation_id:, member_id:, film_ids:, comments:, snapshot:)
        PostCommunityCuration.transaction do
          member = Identity::UserRegistered.lock.find_by(id: member_id)
          raise Errors::PostingUnavailable unless member.present? && Membership::PostingAccess.allowed?(user: member)

          curation = PostCommunityCuration.lock.find(curation_id)
          endorsements = active_endorsements(curation:, member:)
          snapshot_post_id, snapshot_member_id, state = verifier.verified(snapshot)
          same_editor = snapshot_post_id == curation.id && snapshot_member_id == member.id
          saved_film_ids = same_editor ? state.map { |_, film_id, *| film_id } : endorsements.keys
          stale = !same_editor || state != endorsement_state(endorsements)
          if stale
            curation.errors.add(:base, :stale_endorsements)
          else
            curation.edit_endorsements(member:, endorsements:, film_ids:, comments:) do |new_film_ids|
              EligibleCurationFilms.new(member:).lock_for_submission(film_ids: new_film_ids)
            end
          end

          if curation.errors.any?
            editor(curation:, member:, endorsements:, film_ids:, comments:, snapshot:, saved_film_ids:, stale:)
          else
            { curation: }
          end
        end
      end

      def self.active_endorsements(curation:, member:)
        curation.film_endorsements.active.where(user: member).preload(:film, comments: :content).order(:id).index_by(&:film_id)
      end

      def self.endorsement_state(endorsements)
        endorsements.values.map do |endorsement|
          content = endorsement.opening_comment&.content
          revision = [ content.id, content.updated_at.iso8601(6), Digest::SHA256.hexdigest(content.body) ] if content.present?
          [ endorsement.id, endorsement.film_id, revision ]
        end
      end

      def self.editor(curation:, member:, endorsements:, film_ids:, comments:, snapshot:, saved_film_ids:, stale: false)
        search_films = EligibleCurationFilms.new(member:).choices
        saved_films = endorsements.values.map(&:film)
        if stale
          saved_films += ::Registry::Film.where(id: (film_ids & saved_film_ids) - endorsements.keys)
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
