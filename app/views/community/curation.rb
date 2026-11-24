module Views
  module Community
    class Curation < ::Views::Base
      include Phlex::Rails::Helpers::ImagePath

      def initialize(curation:, nominated_films:, library_films:)
        @curation, @nominated_films, @library_films = curation, nominated_films, library_films
      end

      def view_template
        page(title: @curation.title, class: "community-curation-page") do
          render ::Community::CurationTag.new
          p(class: "community-curation-prompt") { @curation.prompt }
          section(data: { controller: "community-film-comments" }) do
            h2 { t("community.curations.nominated_films") }
            if @nominated_films.present?
              div(class: "community-nominations-toolbar") do
                p(class: "muted") { t("community.curations.endorsement_order") }
                div(class: "community-comment-controls", hidden: true, data: { community_film_comments_target: "controls" }) do
                  button(type: :button, class: "muted", data: { community_film_comments_target: "expand",
                    action: "community-film-comments#expandAll" }) { t("community.curations.expand_all") }
                  button(type: :button, class: "muted", disabled: true, data: { community_film_comments_target: "collapse",
                    action: "community-film-comments#collapseAll" }) { t("community.curations.collapse_all") }
                end
              end
              ol(class: "community-nominations") do
                @nominated_films.each.with_index(1) do |(film, endorsements), position|
                  nomination(film, endorsements:, position:)
                end
              end
            else
              p(class: "ui-empty") { t("community.curations.no_nominations") }
            end
          end
          text_link(t("community.curations.back"), community_path)
        end
      end

      private

      def nomination(film, endorsements:, position:)
        li(class: "community-nomination", id: "nomination-#{film.id}") do
          div(class: "community-nomination-media") do
            render ::Registry::FilmPoster.new(film:)
            library_actions(film)
          end
          div(class: "community-nomination-content") do
            div(class: "community-nominated-film-heading") do
              div(class: "community-nomination-title") do
                span(class: "community-nomination-rank") { t("community.curations.position", position:) }
                h3 { render ::Registry::FilmTitle.new(film:) }
              end
              span(class: "community-endorsement-badge") { t("community.curations.endorsements", count: endorsements.size) }
            end
            comments(endorsements.filter_map { |endorsement| endorsement.comment&.content })
          end
        end
      end

      def library_actions(film)
        library_film = @library_films[film.id]
        watched = library_film&.watched?
        watchlist_label = if watched
          t("community.curations.watchlist_unavailable_when_watched")
        elsif library_film.present?
          t("library.search.in_watchlist")
        else
          t("library.detail.add_to_watchlist")
        end

        div(class: "library-card-actions community-nomination-actions") do
          library_button(::Library::BookmarkPlusIcon.new, film:, label: watchlist_label,
            path: (watchlist_community_curation_path(@curation) unless library_film.present?), in_collection: library_film.present? && !watched)
          library_button(::Library::EyeCheckIcon.new, film:, label: t(watched ? "library.search.in_watched" : "library.detail.add_to_watched"),
            path: (watched_community_curation_path(@curation) unless watched), in_collection: watched)
        end
      end

      def library_button(icon, film:, label:, path:, in_collection:)
        render ::Library::CardAction.new(url: path, params: { film_id: film.id }, label:, tooltip: label, in_collection:) { render icon }
      end

      def comments(contents)
        label = t("community.curations.comments", count: contents.size)
        if contents.empty?
          p(class: "muted community-comment-count") { label }
        else
          details(class: "community-film-comments", data: { community_film_comments_target: "film",
            action: "toggle->community-film-comments#updateControls" }) do
            summary { label }
            contents.each { |content| comment(content) }
          end
        end
      end

      def comment(content)
        author = content.author
        article(class: "community-comment") do
          if author.community_avatar_preset.present?
            img(class: "community-comment-avatar", src: image_path("community-avatars/#{author.community_avatar_preset}.png"),
              alt: "", width: 32, height: 32, loading: "lazy")
          end
          div(class: "community-comment-content") do
            strong { author.community_username.presence || t("community.curations.member") }
            p(class: "community-curation-prompt") { content.body }
            div(class: "community-comment-actions") do
              button(type: :button, disabled: true) { t("community.curations.reply") }
              button(type: :button, disabled: true) { t("community.curations.report") }
            end
          end
        end
      end
    end
  end
end
