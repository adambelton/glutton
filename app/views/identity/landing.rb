module Views
  module Identity
    class Landing < ::Views::Base
      def initialize(examples:, films:)
        @examples, @films = examples, films
      end

      def view_template
        render Shared::Layout.new(title: t("identity.entry.title")) do
          main(id: "main-content", tabindex: "-1", class: "landing-demo") do
            header(class: "demo-intro") do
              h1 { hero_heading }
              t("identity.entry.demo.description").each { |paragraph| p { paragraph } }
            end
            feature_section(:ratings) do
              if @examples.present?
                render ::Identity::PreviewCarousel.new(feature: :ratings, labels: @examples.map { |example| example.fetch(:film).title }) do |index|
                  example = @examples.fetch(index)
                  render ::Ratings::Form.new(film: example.fetch(:film), value: example.fetch(:rating),
                    notes: t("identity.entry.demo.examples.#{example.fetch(:key)}.notes"), readonly: true, dismissible: true)
                end
              else
                empty_preview
              end
            end
            feature_section(:recommendations) do
              films = ::Identity::MarketingSamples::RECOMMENDATION_FILM_IDS.filter_map { |id| @films[id] }
              if films.present?
                render ::Identity::PreviewCarousel.new(feature: :recommendations, labels: films.map(&:title)) do |index|
                  film = films.fetch(index)
                  match_percentage = ::Identity::MarketingSamples::RECOMMENDATION_MATCHES.fetch(film.tmdb_id)
                  render ::Recommendations::FilmCard.new(film:, match_percentage:, readonly: true)
                end
              else
                empty_preview
              end
            end
            feature_section(:library) do
              if @films.present?
                render ::Identity::LibraryPreview.new(films: @films)
              else
                empty_preview
              end
            end
            feature_section(:profile) do
              div(class: "demo-browser account-page") do
                h3 { t("account.profile") }
                render ::Account::TasteProfile.new(profile: sample_profile)
              end
            end
            frequently_asked_questions
            section(class: "demo-entry", aria: { label: t("identity.entry.demo.get_started") }) do
              h2 { t("identity.entry.demo.get_started") }
              p { t("identity.entry.demo.invitation") }
              entry_actions
              p(class: "muted") { t("identity.entry.guest_explanation") }
              p { text_link(t("identity.privacy_notice.title"), privacy_notice_path) }
              p(class: "preview-attribution") do
                a(href: "https://www.themoviedb.org", rel: "noreferrer") { t("identity.entry.attribution") }
                plain " "
                plain t("identity.entry.tmdb_disclaimer")
              end
            end
          end
        end
      end

      private

      def hero_heading
        t("identity.entry.heading.template", more: "%{more}", horror: "%{horror}", line_break: "%{line_break}").split(/(%{more}|%{horror}|%{line_break})/).each do |part|
          case part
          when "%{more}"
            span(class: "hero-more") { t("identity.entry.heading.more") }
          when "%{line_break}"
            br(class: "hero-line-break")
          when "%{horror}"
            span(class: "hero-horror") { t("identity.entry.heading.horror") }
          else
            plain part
          end
        end
      end

      def feature_section(feature)
        section(class: "marketing-feature", aria: { labelledby: "#{feature}-preview-heading" }) do
          header(class: "marketing-feature-intro") do
            p(class: "preview-eyebrow") { t("identity.entry.features.#{feature}.eyebrow") }
            h2(id: "#{feature}-preview-heading") { t("identity.entry.features.#{feature}.title") }
            p { t("identity.entry.features.#{feature}.description") }
          end
          div(class: "marketing-preview") do
            yield
          end
        end
      end

      def entry_actions
        div(class: "preview-actions") do
          render Shared::ActionForm.new(url: guest_session_path) do
            render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("identity.entry.demo.try_as_guest") }
          end
          text_link(t("ui.register"), new_registration_path)
        end
      end

      def frequently_asked_questions
        section(class: "marketing-faq", aria: { labelledby: "faq-heading" }) do
          h2(id: "faq-heading") { t("identity.entry.faq.title") }
          t("identity.entry.faq.questions").each do |question|
            details do
              summary { question.fetch(:question) }
              div(class: "marketing-faq-answer") do
                question.fetch(:answer).each { |paragraph| p { paragraph } }
              end
            end
          end
        end
      end

      def empty_preview
        p(class: "preview-empty") { t("identity.entry.empty") }
      end

      def sample_profile
        { profile: t("identity.entry.profile_sample.paragraphs").join("\n\n"),
          quality_rankings: ::Identity::MarketingSamples::PROFILE_QUALITY_RANKINGS.transform_values do |qualities|
            qualities.map do |quality|
              t("identity.entry.profile_sample.qualities.#{quality.fetch(:key)}").merge(score: quality.fetch(:score))
            end
          end }
      end
    end
  end
end
