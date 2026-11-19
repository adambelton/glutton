module Views
  module Admin
    module Films
      class Show < ::Views::Admin::Base
        def initialize(detail:)
          @detail = detail
        end

        def view_template
          dashboard(title: @detail.film.title, resource: :films,
            back_to: admin_films_path, back_label: t("registry.back_to_films")) do
            render ::Admin::Films::Item.new(detail: @detail)
          end
        end
      end
    end
  end
end
