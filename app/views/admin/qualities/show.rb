module Views
  module Admin
    module Qualities
      class Show < ::Views::Admin::Base
        def initialize(detail:)
          @detail = detail
        end

        def view_template
          dashboard(title: @detail.quality.name, resource: :qualities,
            back_to: admin_qualities_path, back_label: t("registry.back_to_qualities")) do
            render ::Admin::Qualities::Item.new(detail: @detail)
          end
        end
      end
    end
  end
end
