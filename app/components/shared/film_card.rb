module Shared
  class FilmCard < Base
    def initialize(layout:, **attrs)
      @layout = layout
      @attrs = attrs
    end

    def view_template(&)
      article(class: [ "film-card", @layout ], **@attrs, &)
    end
  end
end
