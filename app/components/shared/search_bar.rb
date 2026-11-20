module Shared
  class SearchBar < Base
    Mode = Data.define(:key, :label, :form)

    def initialize(label:, modes:, selected:, toggle_position: :start)
      @label, @modes, @selected = label, modes, selected
      @toggle_position = toggle_position
    end

    def view_template
      div(class: "search-bar", data: { controller: "search-bar" }) do
        mode_buttons if @toggle_position == :start
        @modes.each { |mode| mode_panel(mode) }
        mode_buttons if @toggle_position == :end
      end
    end

    private

    def mode_buttons
      div(class: "search-bar-modes", role: "group", aria: { label: @label }) do
        @modes.each { |mode| mode_button(mode) }
      end
    end

    def mode_button(mode)
      button(type: "button", value: mode.key, aria: { pressed: (@selected == mode.key).to_s },
        data: { search_bar_target: "button", action: "search-bar#select" }) { mode.label }
    end

    def mode_panel(mode)
      div(class: "search-bar-panel", hidden: @selected != mode.key,
        data: { mode: mode.key, search_bar_target: "panel" }) { render mode.form }
    end
  end
end
