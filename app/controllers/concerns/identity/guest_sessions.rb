module Identity
  module GuestSessions
    extend ActiveSupport::Concern

    private

    def current_user
      return @current_user if defined?(@current_user)

      user = User.find_by(id: session[:user_id]) if session[:user_id].is_a?(Integer)
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
