module Community
  module Curations
    class ReadCuration
      def self.call(curation:, viewer:, selected_reply_id: nil, expand_selected_branch: false)
        community_user = viewer.community_user
        ActiveRecord::Associations::Preloader.new(records: [ curation ], associations: { visible_film_endorsements: :film }).call
        nominated_films = curation.nominated_films
        library_films = yield viewer.id, nominated_films.map { |film, _| film.id }
        discussion = Discussions::CurationDiscussion.new(curation:, selected_reply_id:, expand_selected_branch:)
        has_endorsements = nominated_films.any? { |_, endorsements| endorsements.any? { |endorsement| endorsement.user_id == viewer.id } }
        { curation:, nominated_films:, library_films:, discussion:, has_endorsements:, can_contribute: Membership::PostingAccess.allowed?(user: viewer),
          can_edit: curation.can_edit?(community_user:) || curation.can_edit_additional_description?(community_user:),
          can_delete: curation.can_delete?(community_user:), can_disassociate: curation.can_disassociate?(community_user:) }
      end
    end
  end
end
