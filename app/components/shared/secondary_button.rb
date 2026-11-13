module Shared
  class SecondaryButton < RubyUI::Button
    def initialize(**attrs)
      super(variant: :secondary, **attrs)
    end
  end
end
