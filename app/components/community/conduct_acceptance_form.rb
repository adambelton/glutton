module Community
  class ConductAcceptanceForm < Shared::Base
    def initialize(user:, code: CodeOfConduct.current)
      @user = user
      @code = code
    end

    def view_template
      section do
        h2 { t("community.conduct.title") }
        if @code.accepted_by?(member: @user)
          p { t("community.conduct.accepted") }
          text_link(t("community.conduct.read"), community_code_of_conduct_path)
        else
          render CodeOfConductText.new(code: @code, nested: true)
          acceptance_form
        end
      end
    end

    private

    def acceptance_form
      form_with(url: community_code_of_conduct_acceptance_path) do
        input(type: :hidden, name: "code_version", value: @code.version)
        label(class: "community-conduct-consent") do
          input(type: :checkbox, name: "accepted", value: "1", required: true)
          span { t("community.conduct.agreement") }
        end
        render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("community.conduct.accept") }
      end
    end
  end
end
