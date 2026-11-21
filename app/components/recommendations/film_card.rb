module Recommendations
  class FilmCard < Shared::Base
    def initialize(film:, match_percentage: nil, readonly: false)
      @film, @match_percentage, @readonly = film, match_percentage, readonly
    end

    def view_template
      details = @film.tmdb_details
      video_id = details.youtube_trailer_id
      render Shared::FilmCard.new(layout: "recommendation-film", data: ({ controller: "recommendation-trailer",
        action: "keydown.esc->recommendation-trailer#collapse resize@window->recommendation-trailer#fitViewport" } if video_id.present? && !@readonly)) do
        media(details:, video_id:)
        div(class: "recommendation-artwork") { render ::Registry::FilmPoster.new(film: @film) }
        div(class: "recommendation-details") do
          header(class: "recommendation-heading") do
            h2 { render ::Registry::FilmTitle.new(film: @film) }
            div(class: "recommendation-metadata") do
              match_score if @match_percentage.present? || !@readonly
              render ::Registry::FilmLinks.new(film: @film, readonly: @readonly)
            end
          end
          div(class: "recommendation-response") do
            render Shared::FilmSynopsis.new(text: details.overview, id: "recommendation-synopsis-#{@film.id}")
            actions
          end
        end
      end
    end

    private

    def media(details:, video_id:)
      if video_id.present?
        trailer(video_id:)
      elsif (backdrop_path = details.backdrop_path).present?
        img(class: "recommendation-media recommendation-backdrop", src: "https://image.tmdb.org/t/p/w780#{backdrop_path}",
          alt: t("recommendations.backdrop_for", title: @film.title), width: 780, height: 439, referrerpolicy: "no-referrer")
      else
        div(class: "recommendation-media recommendation-placeholder", aria: { hidden: "true" })
      end
    end

    def actions
      div(class: "film-actions recommendation-actions") do
        params = { film_id: @film.id }
        render Shared::ActionForm.new(url: accept_recommendation_path, params:, readonly: @readonly) do
          render Shared::PrimaryButton.new(type: :submit, disabled: @readonly, class: "ui-action-button") { t("recommendations.accept") }
        end
        render Shared::ActionForm.new(url: reject_recommendation_path, params:, readonly: @readonly) do
          render Shared::GhostButton.new(type: :submit, disabled: @readonly, class: "ui-action-button") { t("recommendations.reject") }
        end
        render Shared::ActionForm.new(url: add_to_watched_from_recommendations_path, params:, readonly: @readonly) do
          label = t("library.detail.add_to_watched")
          render Shared::IconButton.new(type: :submit, disabled: @readonly, variant: :secondary, size: :xl, class: "ui-action-button",
            aria: { label: }, data: ({ tooltip: label } unless @readonly)) do
            render ::Library::EyeCheckIcon.new
          end
        end
      end
    end

    def match_score
      unless @match_percentage.present?
        return p(class: "recommendation-match recommendation-match-limited") { t("recommendations.match.limited") }
      end

      tooltip_id = "recommendation-match-tooltip-#{@film.id}" unless @readonly
      p(class: "recommendation-match", tabindex: ("0" if tooltip_id.present?), aria: ({ describedby: tooltip_id } if tooltip_id.present?)) do
        span(class: "recommendation-match-mark", aria: { hidden: "true" })
        span(class: "recommendation-match-value") { t("recommendations.match.percentage", percentage: @match_percentage) }
        span(id: tooltip_id, role: "tooltip") { t("recommendations.match.label") } if tooltip_id.present?
      end
    end

    def trailer(video_id:)
      div(class: "recommendation-media recommendation-trailer") do
        div(class: "recommendation-trailer-frame") do
          if @readonly
            div(class: "recommendation-trailer-thumbnail") do
              img(src: "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg", alt: t("recommendations.trailer_for", title: @film.title),
                width: 480, height: 360, loading: "lazy", referrerpolicy: "no-referrer", class: "recommendation-trailer-still")
              span(class: "recommendation-trailer-play", aria: { hidden: "true" }) do
                svg(viewBox: "0 0 24 24", width: 28, height: 28, fill: "currentColor", aria: { hidden: true }) do |icon|
                  icon.path(d: "M8 5v14l11-7Z")
                end
              end
            end
          else
            trailer_player(video_id:)
          end
        end
      end
    end

    def trailer_player(video_id:)
      iframe(id: "recommendation-trailer-player", src: "https://www.youtube.com/embed/#{video_id}", title: t("recommendations.trailer_for", title: @film.title),
        loading: "lazy", allowfullscreen: true, referrerpolicy: "strict-origin-when-cross-origin")
      render Shared::IconButton.new(variant: :plain, class: "recommendation-trailer-toggle", hidden: true,
        aria: { controls: "recommendation-trailer-player", expanded: "false", label: t("recommendations.expand_trailer") },
        data: { recommendation_trailer_target: "toggle", action: "recommendation-trailer#toggle",
          expand_label: t("recommendations.expand_trailer"), collapse_label: t("recommendations.collapse_trailer") }) do
        svg(viewBox: "0 0 24 24", width: "20", height: "20", fill: "none", stroke: "currentColor",
          stroke_width: "1.75", stroke_linecap: "round", stroke_linejoin: "round", aria: { hidden: true }) do |icon|
          icon.path(class: "trailer-expand-icon", d: "M9 3H3v6m12-6h6v6M3 15v6h6m12-6v6h-6")
          icon.path(class: "trailer-collapse-icon", d: "M3 9h6V3m12 6h-6V3M9 21v-6H3m12 6v-6h6")
        end
      end
    end
  end
end
