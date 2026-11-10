module Identity
  module Authentication
    extend ActiveSupport::Concern

    included do
      class_attribute :unauthenticated_actions, default: [].freeze
      rescue_from Identity::Errors::Required, with: -> { head :unauthorized }
      before_action :require_identity
    end

    class_methods do
      def allow_unauthenticated_access(only:)
        self.unauthenticated_actions = (unauthenticated_actions + Array(only).map(&:to_s)).uniq.freeze
        skip_before_action :require_identity, only:
      end

      def authentication_required_for?(action)
        !unauthenticated_actions.include?(action.to_s)
      end
    end

    private

    def require_identity
      return if current_user.present?

      if request.get? && request.format.html?
        remember_entry_destination
        redirect_to new_session_path
      else
        raise Identity::Errors::Required
      end
    end
  end
end
