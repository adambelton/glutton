module Views
  module Account
    class Show < Base
      def initialize(profile:)
        @profile = profile
      end

      def view_template
        page(title: t("account.title"), class: "account-page") do
          nav(class: "account-tabs", aria: { label: t("account.sections") }) do
            a(href: account_path, aria: { current: "page" }) { t("account.profile") }
          end
          section(aria: { labelledby: "taste-profile-heading" }) do
            h2(id: "taste-profile-heading") { t("account.profile") }
            profile_content
          end
          section(aria: { labelledby: "pending-evidence-heading" }) do
            h2(id: "pending-evidence-heading") { t("account.pending") }
            pending_evidence
            render Shared::ActionButton.new(text: t("account.refresh"), url: refresh_taste_profile_account_path)
          end
        end
      end

      private

      def profile_content
        if @profile[:profile].blank?
          p { t("account.empty") }
          return
        end

        annotations = @profile.fetch(:annotations)
        narrative = @profile.fetch(:profile)
        div(class: "profile-narrative") do
          offset = 0
          annotations.each.with_index(1) do |annotation, number|
            ending = annotation.fetch(:end_offset)
            plain narrative[offset...ending]
            plain " "
            a(href: "#profile-evidence-#{number}", class: "profile-annotation", data: { turbo: "false" },
              aria: { label: t("account.supporting_evidence", number:) }) { t("account.evidence_marker", number:) }
            offset = ending
          end
          plain narrative[offset..]
        end
        evidence_list(annotations) if annotations.present?
      end

      def evidence_list(annotations)
        section(aria: { labelledby: "profile-evidence-heading" }) do
          h3(id: "profile-evidence-heading") { t("account.evidence_list") }
          ol(class: "profile-evidence-list") do
            annotations.each.with_index(1) do |annotation, number|
              li(id: "profile-evidence-#{number}", tabindex: "-1") do
                strong { annotation.fetch(:claim) }
                p { annotation.fetch(:explanation) }
                ul do
                  annotation.fetch(:evidence).each do |note|
                    li { cited_note(note) }
                  end
                end
              end
            end
          end
        end
      end

      def cited_note(note)
        text = note.fetch("text")
        citations = note.fetch("citations").sort_by { |citation| citation.fetch("start_offset") }
        p { note.fetch("film_title") }
        p { t("account.earlier_rating_evidence") } if note.fetch("earlier_version")
        citations.each do |citation|
          blockquote { text[citation.fetch("start_offset")...citation.fetch("end_offset")] }
        end
        details do
          summary { t("account.view_full_notes") }
          blockquote { highlighted_notes(text, citations) }
        end
        text_link(t("account.edit_rating", film: note.fetch("film_title")), edit_rating_path(film_id: note.fetch("film_id")))
      end

      def highlighted_notes(text, citations)
        cursor = 0
        citations.each do |citation|
          ending = citation.fetch("end_offset")
          next if ending <= cursor

          start = [ cursor, citation.fetch("start_offset") ].max
          plain text[cursor...start]
          mark { text[start...ending] }
          cursor = ending
        end
        plain text[cursor..]
      end

      def pending_evidence
        if @profile[:changes].empty?
          p { t("account.no_pending_evidence") }
          return
        end

        @profile[:changes].each do |change|
          h3 { change[:title] || t("account.unknown_film") }
          notes_list("account.added", change.fetch(:added))
          notes_list("account.removed", change.fetch(:removed))
        end
      end

      def notes_list(label, notes)
        return if notes.empty?

        p { t(label) }
        ul { notes.each { |note| li { note } } }
      end
    end
  end
end
