module Community
  class Report < ApplicationRecord
    self.table_name = "community_reports"
    self.filter_attributes += %i[evidence explanation identity_snapshot resolution_summary]

    EXPLANATION_LIMIT = 1_000
    RESOLUTION_SUMMARY_LIMIT = 4_000
    RESOLUTION_OUTCOMES = %w[no_violation violation_confirmed].freeze
    HIGH_PRIORITY_REASONS = %w[immediate_safety private_information sexual_abuse_or_child_safety self_harm].freeze
    REASONS = (HIGH_PRIORITY_REASONS + %w[harassment_hate_or_impersonation spam_or_scams spoilers other]).freeze

    belongs_to :reportable, polymorphic: true, optional: true
    belongs_to :reporter, class_name: "Identity::UserRegistered", optional: true
    belongs_to :reported_member, class_name: "Identity::UserRegistered", optional: true
    belongs_to :resolved_by, class_name: "Identity::UserRegistered", optional: true

    scope :unresolved, -> { where(status: %w[pending escalated]) }
    scope :resolved, -> { where(status: "resolved") }

    validates :reporter, :reportable, presence: true, on: :create
    validates :evidence, :identity_snapshot, presence: true, unless: :resolved?
    validates :resolution_outcome, inclusion: { in: RESOLUTION_OUTCOMES }, if: :resolved?
    validates :resolution_summary, presence: true, length: { maximum: RESOLUTION_SUMMARY_LIMIT }, if: :resolved?
    validates :reason, inclusion: { in: REASONS }
    validates :explanation, length: { maximum: EXPLANATION_LIMIT }

    normalizes :explanation, :resolution_summary, with: ->(text) { text.strip.presence }

    def self.capture(reportable:, reporter:, evidence:, reason:, explanation:)
      reported_member = reportable.reported_member
      identity_snapshot = { reporter: account_snapshot(reporter) }
      identity_snapshot[:reported_member] = account_snapshot(reported_member) if reported_member.present?
      priority = HIGH_PRIORITY_REASONS.include?(reason) ? 1 : 0
      create(reportable:, reporter:, reported_member:, reason:, explanation:, evidence:, identity_snapshot:, priority:)
    end

    def self.account_snapshot(account)
      { id: account.id, email: account.email_address, username: account.community_username }
    end
    private_class_method :account_snapshot

    def current_evidence
      reportable&.reportable_attributes
    end

    def pending?
      status == "pending"
    end

    def resolved?
      status == "resolved"
    end

    def high_priority?
      priority == 1
    end

    def self.require_review_access!(moderator:)
      raise Errors::ModerationAccessDenied unless Moderation::Access.review?(user: moderator)
    end

    def escalate!(moderator:)
      self.class.require_review_access!(moderator:)
      raise Errors::ReportAlreadyResolved if resolved?
      raise Errors::ReportAlreadyEscalated unless pending?

      update!(status: "escalated")
    end

    def resolve(moderator:, expected_status:, outcome:, summary:)
      self.class.require_review_access!(moderator:)
      raise Errors::ReportAlreadyResolved if resolved?
      raise Errors::ReportReviewChanged unless status == expected_status

      assign_attributes(status: "resolved", resolved_by: moderator, resolved_at: Time.current,
        resolution_outcome: outcome, resolution_summary: summary,
        reporter: nil, reported_member: nil, reportable: nil,
        evidence: nil, identity_snapshot: nil, explanation: nil)
      return reload if save

      self
    end
  end
end
