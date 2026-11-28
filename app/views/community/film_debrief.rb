module Views
  module Community
    class FilmDebrief < ::Views::Base
      def initialize(debrief:, discussion:, can_reply:, draft: nil)
        @debrief = debrief
        @film = debrief.film
        @discussion, @can_reply, @draft = discussion, can_reply, draft
      end

      def view_template
        page(title: @film.title, class: "community-film-debrief-page", heading: method(:post_heading),
          back_to: community_path, back_label: t("community.curations.back")) do
          div(class: "community-post-description community-debrief-description") do
            p { t("community.film_debriefs.introduction", title: @film.title) }
          end
          render ::Community::FilmDebriefDiscussion.new(debrief: @debrief, discussion: @discussion, can_reply: @can_reply, draft: @draft)
        end
      end

      private

      def post_heading
        div(class: "community-debrief-poster") { render ::Registry::FilmPoster.new(film: @film) }
        render ::Community::PostHeading.new(title: @film.title, title_content: ::Registry::FilmTitle.new(film: @film),
          badges: method(:badges), attribution: ::Community::GluttonIdentity.new(class_name: "community-film-debrief-author"))
      end

      def badges
        div(class: "community-post-tags") do
          render ::Community::PostBadge.new(label: t("community.film_debriefs.badge"),
            tooltip: t("community.film_debriefs.badge_tooltip"), tooltip_id: "film-debrief-#{@debrief.id}-tooltip")
          render ::Community::DebriefFollowButton.new(debrief: @debrief, viewer: current_user)
        end
      end
    end
  end
end
