module Shared
  class FilmSearchDropdown < Base
    def initialize(css_class: nil, **attributes)
      @css_class, @attributes = css_class, attributes
    end

    def view_template
      section(class: [ "film-search-dropdown", @css_class ], **@attributes) { yield if block_given? }
    end
  end
end
