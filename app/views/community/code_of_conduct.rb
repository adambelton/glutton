module Views
  module Community
    class CodeOfConduct < ::Views::Base
      def initialize(code:)
        @code = code
      end

      def view_template
        page(title: t("community.conduct.title"), pending_reminder: false) do
          render ::Community::CodeOfConductText.new(code: @code)
        end
      end
    end
  end
end
