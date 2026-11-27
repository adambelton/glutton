module Community
  module Curations
    class BrowseCuration
      def self.call(curation:, viewer:, selected_reply_id:, expand_selected_branch:)
        ReadCuration.call(curation:, viewer:, selected_reply_id:, expand_selected_branch:) do |user_id, film_ids|
          Library::CollectionManagement::BrowseFilmCollection.entries_by_film(user_id:, film_ids:)
        end
      end
    end
  end
end
