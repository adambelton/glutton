module Views
  module Account
    class Show < Base
      def initialize(profile:, can_refresh_taste_profile:)
        @profile = profile
        @can_refresh_taste_profile = can_refresh_taste_profile
      end

      def view_template
        page(title: t("account.title"), class: "account-page", heading_outside_card: true) do
          render ::Identity::AccountNavigation.new(section: :profile)
          section(aria: { labelledby: "taste-profile-heading" }) do
            h2(id: "taste-profile-heading") { t("account.profile") }
            render ::Account::TasteProfile.new(profile: @profile)
          end
          section(aria: { labelledby: "pending-evidence-heading" }) do
            h2(id: "pending-evidence-heading") { t("account.pending") }
            pending_evidence
            render Shared::ActionForm.new(url: refresh_taste_profile_account_path) do
              render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("account.refresh") }
            end
          end if @can_refresh_taste_profile
        end
      end

      private

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
