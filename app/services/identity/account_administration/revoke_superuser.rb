module Identity
  module AccountAdministration
    class RevokeSuperuser
      def self.call(user_id:, actor_user_id:)
        User.transaction(requires_new: true) do
          users = User.where(id: [ actor_user_id, user_id ]).order(:id).lock.index_by(&:id)
          actor = users[actor_user_id]
          raise Errors::SuperuserRequired unless actor

          user = users[user_id]
          raise Errors::SuperuserUnavailable unless user

          user.revoke_superuser!(actor:)
        end
      end
    end
  end
end
