module Views
  module Admin
    module Users
      class Index < ::Views::Admin::Base
        def initialize(page:, query:)
          @page, @query = page, query
        end

        def view_template
          dashboard(title: t("identity.user_administration.title"), resource: :users, heading: false) do
            render ::Admin::Collection.new(page: @page, path: admin_users_path, label: t("admin.search.users"), query: @query, private_search: true) do
              render ::Admin::Users::Collection.new(users: @page.entries)
            end
          end
        end
      end
    end
  end
end
