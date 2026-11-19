module Admin
  class Navigation < Shared::Base
    def initialize(resource:)
      @resource = resource
    end

    def view_template
      aside(class: "admin-sidebar") do
        a(href: library_path, class: "admin-wordmark", aria: { label: t("admin.back_to_glutton") }) { t("ui.wordmark") }
        nav(class: "admin-navigation", aria: { label: t("admin.navigation") }) do
          link(:users, admin_users_path, t("identity.user_administration.title"))
          link(:films, admin_films_path, t("registry.films"))
          link(:qualities, admin_qualities_path, t("registry.qualities"))
          link(:categories, admin_quality_categories_path, t("registry.categories"))
        end
      end
    end

    private

    def link(resource, path, label)
      a(href: path, aria: { current: ("location" if @resource == resource) }) { label }
    end
  end
end
