module Identity
  module AccountAdministration
    class ReplayAccountDeletions
      extend Monitoring::Instrumentation
      instrument_operations :call

      def initialize(deletion_log:)
        @deletion_log = deletion_log
      end

      def call
        @deletion_log.account_ids.sum do |account_id|
          UserRegistered.transaction do
            account = UserRegistered.lock.find_by(deletion_replay_id: account_id)
            if account.present?
              account.destroy_with_activity!
              1
            else
              0
            end
          end
        end
      end
    end
  end
end
