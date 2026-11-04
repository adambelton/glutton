module Identity
  class GrantSuperuser
    def self.call(user_id:, actor_user_id:)
      User.transaction(requires_new: true) do
        users = User.where(id: [ actor_user_id, user_id ]).order(:id).lock.index_by(&:id)
        actor = users[actor_user_id]
        raise SuperuserRequired unless actor

        user = users[user_id]
        raise SuperuserUnavailable unless user

        user.grant_superuser!(actor:)
      end
    end
  end
end
