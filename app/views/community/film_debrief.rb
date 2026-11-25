module Views
  module Community
    class FilmDebrief < ::Views::Base
      def initialize(debrief:)
        @debrief = debrief
        @film = debrief.film
      end

      def view_template
        page(title: @film.title, class: "community-film-debrief-page", back_to: community_path, back_label: t("community.curations.back")) do
          div(class: "community-post-tags") do
            render ::Community::PostBadge.new(label: t("community.film_debriefs.badge"),
              tooltip: t("community.film_debriefs.badge_tooltip"), tooltip_id: "film-debrief-#{@debrief.id}-tooltip")
          end
          div(class: "community-curation-descriptions") do
            p { t("community.film_debriefs.introduction", title: @film.title) }
          end
        end
      end
    end
  end
end
