module Identity
  module AccountAdministration
    class RevokeUserSession
      def self.call(user_id:, session_id:, actor_user_id:, actor_session_id:)
        User.transaction do
          users = User.where(id: [ actor_user_id, user_id ]).order(:id).lock.index_by(&:id)
          actor = users[actor_user_id]
          unless actor&.superuser? && Session.exists?(id: actor_session_id, user_id: actor.id)
            raise Errors::SuperuserRequired
          end

          user = users[user_id] || raise(Errors::Unavailable)
          session = Session.lock.find_by(id: session_id, user_id: user.id) || raise(Errors::SessionUnavailable)
          session.revoke_by!(actor:)
        end
      end
    end
  end
end
