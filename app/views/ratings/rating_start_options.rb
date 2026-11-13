module Views
  module Ratings
    class RatingStartOptions < ::Views::Base
      def view_template
        page(title: t("ratings.browser.title"), heading_outside_card: true) do
          h2 { t("ratings.onboarding.heading") }
          p { t("ratings.onboarding.intro") }
          div(class: "ui-actions") do
            render Shared::ActionForm.new(url: choose_films_rating_path,
              method: :get) do
              render Shared::GhostButton.new(type: :submit, class: "ui-action-button") { t("ratings.onboarding.choose") }
            end
            render Shared::ActionForm.new(url: surprise_rating_path,
              data: { turbo: false }) do
              render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("ratings.onboarding.surprise") }
            end
          end
        end
      end
    end
  end
end
