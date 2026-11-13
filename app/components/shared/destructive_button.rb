module Shared
  class DestructiveButton < RubyUI::Button
    def initialize(**attrs)
      super(variant: :destructive, **attrs)
    end
  end
end
