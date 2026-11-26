module Views
  module Community
    class EditCurationEndorsements < ::Views::Base
      FRAME_ID = "curation-endorsement-editor".freeze

      def initialize(curation:, films:, search_films:, film_ids:, comments:, published_comments:, snapshot:, saved_film_ids:, stale:, dialog:)
        @curation, @films, @search_films, @film_ids, @comments = curation, films, search_films, film_ids, comments
        @published_comments = published_comments
        @snapshot, @saved_film_ids, @stale, @dialog = snapshot, saved_film_ids, stale, dialog
      end

      def view_template
        title = t("community.curation_endorsements.title", title: @curation.title)
        if @dialog
          render Shared::EditorDialog.new(frame_id: FRAME_ID, title:) { editor_form }
        else
          page(title:, narrow: true, back_to: community_curation_path(@curation), back_label: t("community.curations.back_to_curation")) do
            editor_form
          end
        end
      end

      private

      def editor_form
        errors(@curation.errors.full_messages)
        if @stale
          a(href: edit_community_curation_endorsements_path(@curation), class: "ui-link") do
            t("community.curation_endorsements.reload")
          end
        end
        baseline = { "endorsements[film_ids][]" => @saved_film_ids }
        form_with(url: community_curation_endorsements_path(@curation), method: :patch,
          data: track_form_changes(baseline:, ignored: [ "endorsements[snapshot]" ])) do
          input(type: :hidden, name: "endorsements[snapshot]", value: @snapshot)
          render ::Community::CurationFilmPicker.new(films: @films, search_films: @search_films, selected_film_ids: @film_ids,
              comments: @comments, published_comments: @published_comments, saved_film_ids: @saved_film_ids,
              heading: t("community.curation_endorsements.films"), divide_selected_films: true, in_dialog: @dialog,
            field_prefix: "curation_endorsements", film_ids_name: "endorsements[film_ids]", comments_name: "endorsements[comments]")
          div(class: "ui-actions ui-actions-fixed ui-actions-mobile-full justify-end") do
            render RubyUI::Link.new(href: community_curation_path(@curation), variant: :ghost, class: "ui-action-button",
              data: { action: ("editor-dialog#close:prevent" if @dialog) }) { t("community.curations.cancel") }
            render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button",
              disabled: @film_ids.sort == @saved_film_ids.sort && @comments.values.none?(&:present?),
              data: { unchanged_form_target: "save" }) { t("community.curation_endorsements.save") }
          end
        end
      end
    end
  end
end
