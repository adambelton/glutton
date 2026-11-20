module Views
  module Admin
    module Users
      class Index < ::Views::Admin::Base
        SEARCH_PARAMETER = "account_email_or_id".freeze

        def initialize(page:, query:)
          @page, @query = page, query
        end

        def view_template
          dashboard(title: t("identity.user_administration.title"), resource: :users, heading: false) do
            search = collection_search(path: admin_users_path, label: t("admin.search.users"), query: @query,
              method: :post, parameter: SEARCH_PARAMETER)
            pagination = collection_pagination(page: @page, path: admin_users_path, query: @query,
              method: :post, parameter: SEARCH_PARAMETER)
            render ::Admin::Collection.new(page: @page, query: @query, search:, pagination:) do
              render ::Admin::Users::Collection.new(users: @page.entries)
            end
          end
        end
      end
    end
  end
end
