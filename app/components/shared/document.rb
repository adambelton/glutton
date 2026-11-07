module Shared
  class Document < Base
    include Phlex::Rails::Helpers::CSRFMetaTags
    include Phlex::Rails::Helpers::CSPMetaTag
    include Phlex::Rails::Helpers::JavascriptTag
    include Phlex::Rails::Helpers::JavascriptImportmapTags
    include Phlex::Rails::Helpers::StylesheetLinkTag

    def initialize(title:, body_class: "ui-page")
      @title, @body_class = title, body_class
    end

    def view_template
      doctype
      html(lang: I18n.locale) do
        head do
          title { t("ui.page_title", title: @title, brand: t("ui.wordmark")) }
          meta(name: "viewport", content: "width=device-width,initial-scale=1")
          meta(name: "application-name", content: t("ui.wordmark"))
          meta(name: "turbo-cache-control", content: "no-cache")
          csrf_meta_tags
          csp_meta_tag
          link(rel: "icon", href: "/icon.png", type: "image/png")
          link(rel: "icon", href: "/icon.svg", type: "image/svg+xml")
          link(rel: "apple-touch-icon", href: "/icon.png")
          javascript_tag(<<~JS, nonce: true)
            try {
              document.documentElement.dataset.theme = localStorage.getItem("glutton.theme") === "dark" ? "dark" : "light";
            } catch {
              document.documentElement.dataset.theme = "light";
            }
          JS
          stylesheet_link_tag "tailwind", "data-turbo-track": "reload"
          javascript_importmap_tags
        end
        body(class: @body_class) { yield }
      end
    end
  end
end
