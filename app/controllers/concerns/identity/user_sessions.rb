module Identity
  module UserSessions
    extend ActiveSupport::Concern

    class AccountDeleted < StandardError; end

    included do
      rescue_from AccountDeleted do
        render plain: "This account has been deleted.", status: :gone
      end
    end

    private

    def current_user
      return @current_user if defined?(@current_user)

      user = User.find_by(id: session[:user_id]) if session[:user_id].is_a?(Integer)
      raise AccountDeleted if user.is_a?(DeletedUser)

      @current_user = user&.active? ? user : nil
      session.delete(:user_id) unless @current_user
      @current_user
    end

    def ensure_guest_user!
      user = current_user
      return user if user

      user = GuestUser.create!
      reset_session
      session[:user_id] = user.id
      @current_user = user
    end
  end
end
