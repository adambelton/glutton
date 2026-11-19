module Views
  module Admin
    module Users
      class Profile < ::Views::Admin::Base
        def initialize(user_id:, profile:)
          @user_id, @profile = user_id, profile
        end

        def view_template
          dashboard(title: t("ratings.profile_inspection.title", id: @user_id), resource: :users,
            back_to: admin_user_path(@user_id), back_label: t("ratings.profile_inspection.back")) do
            render ::Admin::Users::Profile.new(user_id: @user_id, profile: @profile)
          end
        end
      end
    end
  end
end
