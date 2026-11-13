module Shared
  class PrimaryButton < RubyUI::Button
    def initialize(**attrs)
      super(variant: :primary, **attrs)
    end
  end
end
