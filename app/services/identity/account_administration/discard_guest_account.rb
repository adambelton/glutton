module Identity
  module AccountAdministration
    class DiscardGuestAccount
      def self.call(user_id:)
        UserGuest.transaction do
          guest = UserGuest.lock.find_by(id: user_id)
          raise Identity::Errors::Unavailable unless guest&.active?

          guest.destroy_with_activity!
        end
      end
    end
  end
end
