module Community
  class CurationFilmBody < Shared::Base
    def initialize(curation:, film:, position:, endorsement_count:, following:, discussion:)
      @curation, @film, @position = curation, film, position
      @endorsement_count, @following, @discussion = endorsement_count, following, discussion
    end

    def view_template
      div(class: "community-nomination-content") do
        header(class: "community-nomination-header") do
          div(class: "community-nominated-film-heading") do
            div(class: "community-nomination-title") do
              span(class: "community-nomination-rank") { t("community.curations.position", position: @position) }
              h3 { render ::Registry::FilmTitle.new(film: @film) }
            end
            span(class: "community-endorsement-badge") { t("community.curations.endorsements", count: @endorsement_count) }
          end
          div(class: "community-nomination-follow") do
            render PostFollowButton.new(url: community_curation_film_notification_path(@curation, @film),
              label: t("community.notifications.film_follow_label", film: @film.title), following: @following)
          end
        end
        render @discussion
      end
    end
  end
end
