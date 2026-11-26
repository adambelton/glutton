module Community
  class Report < ApplicationRecord
    self.table_name = "community_reports"
    self.filter_attributes += %i[evidence_text explanation identity_snapshot]

    EXPLANATION_LIMIT = 1_000
    HIGH_PRIORITY_REASONS = %w[immediate_safety private_information sexual_abuse_or_child_safety self_harm].freeze
    REASONS = (HIGH_PRIORITY_REASONS + %w[harassment_hate_or_impersonation spam_or_scams spoilers other]).freeze

    belongs_to :reportable, polymorphic: true, optional: true
    belongs_to :reporter, class_name: "Identity::UserRegistered", optional: true
    belongs_to :reported_member, class_name: "Identity::UserRegistered", optional: true

    validates :reporter, presence: true, on: :create
    validate :require_source, on: :create
    validates :part, :evidence_text, :identity_snapshot, presence: true
    validates :reason, inclusion: { in: REASONS }
    validates :explanation, length: { maximum: EXPLANATION_LIMIT }

    normalizes :explanation, with: ->(text) { text.strip.presence }

    def self.capture(reportable:, reporter:, part:, reason:, explanation:)
      evidence_text = reportable.reportable_text(part:)
      raise Errors::ReportTargetUnavailable unless evidence_text.present?

      reported_member = reportable.reported_member
      identity_snapshot = { reporter: account_snapshot(reporter) }
      identity_snapshot[:reported_member] = account_snapshot(reported_member) if reported_member.present?
      priority = HIGH_PRIORITY_REASONS.include?(reason) ? 1 : 0
      create(**reportable.report_source_reference, reporter:, reported_member:, part:, reason:, explanation:, evidence_text:, identity_snapshot:, priority:)
    end

    def self.account_snapshot(account)
      { id: account.id, email: account.email_address, username: account.community_username }
    end
    private_class_method :account_snapshot

    def current_text
      reportable&.reportable_text(part:)
    end

    def pending?
      status == "pending"
    end

    def high_priority?
      priority == 1
    end

    def self.require_escalation_access!(moderator:)
      raise Errors::ModerationAccessDenied unless Moderation::Access.review?(user: moderator)
    end

    def escalate!(moderator:)
      self.class.require_escalation_access!(moderator:)
      raise Errors::ReportAlreadyEscalated unless pending?

      update!(status: "escalated")
    end

    private

    def require_source
      errors.add(:reportable, :blank) unless curation_source_id.present? || comment_content_source_id.present?
    end
  end
end
