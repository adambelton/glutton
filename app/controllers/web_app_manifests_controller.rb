class WebAppManifestsController < ActionController::Base
  def show
    name = I18n.t("app.name")
    render json: {
      id: "/", name:, short_name: name, start_url: root_path, scope: "/", display: "standalone",
      background_color: "#090e14", theme_color: "#090e14",
      icons: [
        { src: "/glutton-app-icon-192.png", sizes: "192x192", type: "image/png" },
        { src: "/glutton-app-icon-512.png", sizes: "512x512", type: "image/png" }
      ]
    }, content_type: "application/manifest+json"
  end
end
