module Community
  class ConductAcceptanceForm < Shared::Base
    def initialize(user:, source:)
      @user = user
      @source = source
      @code = CodeOfConduct.current
    end

    def view_template
      section do
        h2 { t("community.conduct.title") }
        text_link(t("community.conduct.read"), community_code_of_conduct_path(version: @code.version))
        if CodeOfConductAcceptance.exists?(user_id: @user.id, code_version: @code.version)
          p { t("community.conduct.accepted_version", version: @code.version) }
        else
          acceptance_form
        end
      end
    end

    private

    def acceptance_form
      form_with(url: community_code_of_conduct_acceptance_path) do
        input(type: :hidden, name: "code_version", value: @code.version)
        input(type: :hidden, name: "source", value: @source)
        label(class: "community-conduct-consent") do
          input(type: :checkbox, name: "accepted", value: "1", required: true)
          span { t("community.conduct.agreement") }
        end
        render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("community.conduct.accept") }
      end
    end
  end
end
