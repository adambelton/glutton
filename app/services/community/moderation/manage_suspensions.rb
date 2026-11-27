module Community
  module Moderation
    class ManageSuspensions
      PAGE_SIZE = 20

      def self.browse(viewer:, number:, state:)
        raise Errors::ModerationAccessDenied unless Access.review?(user: viewer)

        suspensions = if state == "lifted"
          Suspension.lifted.order(lifted_at: :desc, id: :desc)
        else
          Suspension.active.order(suspended_at: :desc, id: :desc)
        end
        suspensions = suspensions.includes(member: :community_user)
        CountedPage.load(suspensions, number:, page_size: PAGE_SIZE)
      end

      def self.target(viewer:, member_id:, report_id:)
        raise Errors::ModerationAccessDenied unless Access.review?(user: viewer)

        member = Identity::UserRegistered.find(member_id)
        verify_report_target!(member:, report_id:, lock: false)
        raise Errors::SuspensionUnavailable unless Membership::Access.participation_allowed?(user: member)

        member
      end

      def self.suspend(actor_id:, member_id:, report_id:)
        with_members(actor_id:, member_id:) do |actor, member|
          verify_report_target!(member:, report_id:, lock: true)
          Suspension.start!(member:, moderator: actor)
        end
      end

      def self.lift(actor_id:, suspension_id:)
        member_id = Suspension.where(id: suspension_id).pick(:member_id)
        with_members(actor_id:, member_id:) do |actor, member|
          Suspension.lock.find_by!(id: suspension_id, member:).lift!(moderator: actor)
        end
      end

      def self.with_members(actor_id:, member_id:)
        Suspension.transaction do
          members = Identity::UserRegistered.where(id: [ actor_id, member_id ]).order(:id).lock.index_by(&:id)
          actor = members[actor_id]
          raise Errors::ModerationAccessDenied unless actor.present? && Access.review?(user: actor)

          member = members[member_id]
          raise ActiveRecord::RecordNotFound unless member.present?

          yield actor, member
        end
      end

      def self.verify_report_target!(member:, report_id:, lock:)
        return unless report_id.present?

        reports = Report.unresolved
        reports = reports.lock if lock
        reports.find_by!(id: report_id, reported_member: member)
      end

      private_class_method :with_members, :verify_report_target!
    end
  end
end
