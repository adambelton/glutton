module Shared
  class GhostButton < RubyUI::Button
    def initialize(**attrs)
      super(variant: :ghost, **attrs)
    end
  end
end
