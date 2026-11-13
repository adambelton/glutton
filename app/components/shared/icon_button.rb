module Shared
  class IconButton < RubyUI::Button
    def initialize(**attrs)
      super(icon: true, **attrs)
    end
  end
end
