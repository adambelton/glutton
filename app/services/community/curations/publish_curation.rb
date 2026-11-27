module Community
  module Curations
    class PublishCuration
      def self.call(community_user:, title:, description:, reference_film_ids:, reference_comments:)
        Membership::WithProfileForUpdate.call(community_user:) do |community_user|
          raise Errors::PostingUnavailable unless community_user&.ready_to_post?

          PostCommunityCuration.new(community_user:, title:, description:).publish(reference_film_ids:, reference_comments:) do |film_ids|
            BrowseEligibleCurationFilms.lock_for_submission(community_user:, film_ids:)
          end
        end
      end
    end
  end
end
