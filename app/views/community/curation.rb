module Views
  module Community
    class Curation < ::Views::Base
      def initialize(curation:, nominated_films:, library_films:, discussion:, has_endorsements:, can_contribute:, can_edit:, can_delete:, can_disassociate:)
        @curation, @nominated_films, @library_films = curation, nominated_films, library_films
        @discussion = discussion
        @has_endorsements = has_endorsements
        @can_contribute = can_contribute
        @can_edit = can_edit
        @can_delete = can_delete
        @can_disassociate = can_disassociate
      end

      def view_template
        heading_action = method(:author_actions) if @can_edit || @can_delete || @can_disassociate
        page(title: @curation.title, class: "community-curation-page", heading_action:,
          back_to: community_path, back_label: t("community.curations.back")) do
          render ::Community::CurationTag.new(post_id: @curation.id, protected_post: @curation.protected?, show_tooltips: true)
          author_identity(@curation.author) if @curation.author.present?
          div(class: "community-curation-descriptions") do
            p(class: "community-curation-prompt") { @curation.prompt }
            display_additional_description if @curation.additional_description.present?
          end
          section(aria: { labelledby: "curation-nominated-films" }, data: { controller: "community-film-comments" }) do
            h2(id: "curation-nominated-films", class: "sr-only") { t("community.curations.nominated_films") }
            endorsements_action if @can_contribute
            if @nominated_films.present?
              div(class: "community-nominations-toolbar") do
                div(class: "community-comment-controls", hidden: true, data: { community_film_comments_target: "controls" }) do
                  button(type: :button, class: "muted", disabled: true, data: { community_film_comments_target: "collapse",
                    action: "community-film-comments#collapseAll" }) { t("community.curations.collapse_all") }
                  button(type: :button, class: "muted", data: { community_film_comments_target: "expand",
                    action: "community-film-comments#expandAll" }) { t("community.curations.expand_all") }
                end
                p(class: "muted") { t("community.curations.endorsement_order") }
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
        end
      end

      private

      def author_identity(author)
        div(class: "community-curation-author") do
          render ::Community::MemberAvatar.new(member: author)
          strong { author.community_username.presence || t("community.curations.member") }
        end
      end

      def author_actions
        div(class: "ui-actions ui-actions-fixed community-curation-author-actions justify-end") do
          edit_action if @can_edit
          delete_action if @can_delete
          disassociate_action if @can_disassociate
        end
      end

      def disassociate_action
        render Shared::ConfirmationDialog.new(id: "disassociate-curation", action_label: t("community.curation_protection.disassociate"),
          title: t("community.curation_protection.confirm_title"), description: t("community.curation_protection.confirm_description"),
          cancel_label: t("community.curations.cancel"), url: disassociate_community_curation_path(@curation), method: :patch)
      end

      def display_additional_description
        section(class: "community-curation-additional-description", aria: { labelledby: "curation-additional-description" }) do
          h2(id: "curation-additional-description") { t("community.curation_protection.additional_description_label") }
          p(class: "community-curation-prompt") { @curation.additional_description }
        end
      end

      def edit_action
        render RubyUI::Link.new(href: edit_community_curation_path(@curation), variant: :ghost, size: :lg, class: "ui-action-button") do
          t("community.curation_editing.edit_post")
        end
      end

      def delete_action
        render Shared::ConfirmationDialog.new(id: "delete-curation", action_label: t("community.curation_deletion.delete_post"),
          title: t("community.curation_deletion.confirm_title"), description: t("community.curation_deletion.confirm_description"),
          cancel_label: t("community.curations.cancel"), url: community_curation_path(@curation))
      end

      def endorsements_action
        frame_id = EditCurationEndorsements::FRAME_ID
        render RubyUI::Link.new(href: edit_community_curation_endorsements_path(@curation), variant: :primary, size: :xl,
          class: "mt-4 mb-1", aria: { haspopup: "dialog" }, data: { turbo_frame: frame_id }) do
          t(@has_endorsements ? "community.curation_endorsements.edit_endorsements" : "community.curation_endorsements.endorse_films")
        end
        render Shared::EditorDialog.new(frame_id:)
      end

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
            render ::Community::CurationComments.new(curation: @curation, film_id: film.id, discussion: @discussion, can_reply: @can_contribute)
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
    end
  end
end
