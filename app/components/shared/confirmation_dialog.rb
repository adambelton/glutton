module Shared
  class ConfirmationDialog < Base
    def initialize(id:, action_label:, title:, description:, cancel_label:, url:)
      @id = id
      @action_label = action_label
      @title = title
      @description = description
      @cancel_label = cancel_label
      @url = url
    end

    def view_template
      div(data: { controller: "confirmation-dialog" }) do
        render DestructiveButton.new(class: "ui-action-button", aria: { haspopup: "dialog" },
          data: { action: "confirmation-dialog#open" }) { @action_label }
        tag(:dialog, class: "ui-card ui-confirmation-dialog",
          aria: { labelledby: "#{@id}-title", describedby: "#{@id}-description" },
          data: { confirmation_dialog_target: "dialog", action: "turbo:before-cache@document->confirmation-dialog#close" }) do
          h2(id: "#{@id}-title") { @title }
          p(id: "#{@id}-description") { @description }
          div(class: "ui-actions") do
            render GhostButton.new(class: "ui-action-button", autofocus: true,
              data: { action: "confirmation-dialog#close" }) { @cancel_label }
            render ActionForm.new(url: @url, method: :delete) do
              render DestructiveButton.new(type: :submit, class: "ui-action-button") { @action_label }
            end
          end
        end
      end
    end
  end
end
