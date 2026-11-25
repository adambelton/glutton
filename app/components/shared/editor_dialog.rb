module Shared
  class EditorDialog < Base
    def initialize(frame_id:, title: nil)
      @frame_id, @title = frame_id, title
    end

    def view_template
      if @title.present?
        title_id = "#{@frame_id}-title"
        tag(:"turbo-frame", id: @frame_id) do
          tag(:dialog, class: "ui-card ui-editor-dialog", aria: { labelledby: title_id }, data: { editor_dialog_target: "dialog" }) do
            h2(id: title_id) { @title }
            yield
          end
        end
      else
        tag(:"turbo-frame", id: @frame_id, data: { controller: "editor-dialog", action: "turbo:before-cache@document->editor-dialog#close" })
      end
    end
  end
end
