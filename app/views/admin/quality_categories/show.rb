module Views
  module Admin
    module QualityCategories
      class Show < ::Views::Admin::Base
        def initialize(detail:)
          @detail = detail
        end

        def view_template
          dashboard(title: @detail.category.name, resource: :categories,
            back_to: admin_quality_categories_path, back_label: t("registry.back_to_categories")) do
            render ::Admin::QualityCategories::Item.new(detail: @detail)
          end
        end
      end
    end
  end
end
