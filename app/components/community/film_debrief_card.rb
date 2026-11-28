module Community
  class FilmDebriefCard < Shared::Base
    def initialize(entry:, can_post:)
      @film, @debrief, @can_post = entry.film, entry.debrief, can_post
      @comment_count = entry.comment_count
    end

    def view_template
      @title_id = "film-debrief-#{@film.id}-title"
      if @debrief.present?
        article do
          a(class: "community-film-debrief-card", href: community_post_path(@debrief), aria: { labelledby: @title_id }) do
            film_details
          end
        end
      else
        article(class: "community-film-debrief-card", aria: { labelledby: @title_id }) do
          film_details
        end
      end
    end

    private

    def film_details
      div(class: "community-post-card-artwork") do
        render ::Registry::FilmPoster.new(film: @film, placeholder: :wordmark)
      end
      if @debrief.present?
        below_title = PostBadge.new(label: t("community.film_debriefs.badge"))
        attribution = GluttonIdentity.new(class_name: "muted community-post-card-attribution")
        status = method(:post_status)
      elsif @can_post
        below_title = method(:create_action)
      end
      render PostCardDetails.new(title_id: @title_id, below_title:, attribution:, status:) { render ::Registry::FilmTitle.new(film: @film) }
    end

    def post_status
      p { t("community.curations.comments", count: @comment_count) }
    end

    def create_action
      form_with(url: community_posts_path, local: true, class: "community-film-debrief-create") do
        input(type: :hidden, name: "post_type", value: "film_debrief")
        input(type: :hidden, name: "film_id", value: @film.id)
        render RubyUI::Button.new(type: :submit, variant: :primary, size: :lg, class: "ui-action-button h-auto max-w-full whitespace-normal") do
          t("community.film_debriefs.create")
        end
      end
    end
  end
end
