module Community
  module Curations
    class ReadCuration
      def self.call(curation:, viewer:, selected_reply_id: nil, expand_selected_branch: false)
        ActiveRecord::Associations::Preloader.new(records: [ curation ], associations: { visible_film_endorsements: :film }).call
        nominated_films = curation.nominated_films
        library_films = Library::LibraryFilm.where(user: viewer, film_id: nominated_films.map { |film, _| film.id }).index_by(&:film_id)
        discussion = Discussions::CurationDiscussion.new(curation:, selected_reply_id:, expand_selected_branch:)
        has_endorsements = nominated_films.any? { |_, endorsements| endorsements.any? { |endorsement| endorsement.user_id == viewer.id } }
        { curation:, nominated_films:, library_films:, discussion:, has_endorsements:, can_contribute: Membership::PostingAccess.allowed?(user: viewer),
          can_edit: curation.can_edit?(member: viewer) || curation.can_edit_additional_description?(member: viewer),
          can_delete: curation.can_delete?(member: viewer), can_disassociate: curation.can_disassociate?(member: viewer) }
      end
    end
  end
end
