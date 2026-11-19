module Views
  module Admin
    class Base < Shared::Base
      private

      def dashboard(title:, resource: nil, heading: true, back_to: nil, back_label: nil, &)
        render ::Admin::Dashboard.new(title:, resource:, heading:, back_to:, back_label:), &
      end
    end
  end
end
