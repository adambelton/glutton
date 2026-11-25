module Community
  module Discussions
    class CurationDiscussion < Discussion
      def self.film_id_for(comment)
        (comment.root || comment).film_endorsement.film_id
      end

      def initialize(curation:, film_id: nil, **options)
        @curation = curation
        @film_id = film_id
        super(post: curation, **options)
      end

      def count_for_film(film_id)
        counts_by_film.fetch(film_id, 0)
      end

      def reveal?(film_id)
        @selected_comment.present? && self.class.film_id_for(@selected_comment) == film_id
      end

      private

      def roots(film_id)
        super.where(film_endorsement_id: @curation.film_endorsements.where(film_id:).select(:id))
      end

      def counts_by_film
        @counts_by_film ||= begin
          authored = @curation.comments.joins(:content)
            .joins("INNER JOIN comments AS discussion_roots ON discussion_roots.id = COALESCE(comments.root_id, comments.id)")
            .joins("INNER JOIN film_endorsements ON film_endorsements.id = discussion_roots.film_endorsement_id")
          authored = authored.where(film_endorsements: { film_id: @film_id }) if @film_id.present?
          authored.group("film_endorsements.film_id").count
        end
      end
    end
  end
end
