module Views
  module Admin
    module Users
      class Show < ::Views::Admin::Base
        def initialize(user:, sessions:)
          @user, @sessions = user, sessions
        end

        def view_template
          dashboard(title: t("identity.user_administration.detail", id: @user.id), resource: :users,
            back_to: admin_users_path, back_label: t("identity.user_administration.back")) do
            render ::Admin::Users::Item.new(user: @user, sessions: @sessions)
          end
        end
      end
    end
  end
end
