module Community
  class Report < ApplicationRecord
    self.table_name = "community_reports"
    self.filter_attributes += %i[evidence explanation identity_snapshot resolution_summary]

    EXPLANATION_LIMIT = 1_000
    RESOLUTION_SUMMARY_LIMIT = 4_000
    ACCEPTED_OUTCOME = "violation_confirmed"
    RESOLUTION_OUTCOMES = [ ACCEPTED_OUTCOME, "no_violation" ].freeze
    NO_RESOLUTION_ACTION = "none"
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
    validate :validate_resolution_action, if: :will_save_change_to_resolution_outcome?
    validates :reason, inclusion: { in: REASONS }
    validates :explanation, length: { maximum: EXPLANATION_LIMIT }

    normalizes :explanation, :resolution_summary, with: ->(text) { text.strip.presence }

    attr_reader :selected_resolution_action

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

    def review_revision
      review_verifier.generate([ id, reportable.reportable_revision ]) if reportable.present?
    end

    def require_reviewed_source!(source:, revision:)
      unless source.present? && reportable_type == source.class.polymorphic_name && reportable_id == source.id &&
          revision.present? && review_verifier.verified(revision) == [ id, source.reportable_revision ]
        raise Errors::ReportSourceChanged
      end
    end

    def pending?
      status == "pending"
    end

    def resolved?
      status == "resolved"
    end

    def accepted?
      resolution_outcome == ACCEPTED_OUTCOME
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

    def resolve(moderator:, expected_status:, outcome:, summary:, action:)
      self.class.require_review_access!(moderator:)
      raise Errors::ReportAlreadyResolved if resolved?
      raise Errors::ReportReviewChanged unless status == expected_status

      @selected_resolution_action = action.presence
      assign_attributes(status: "resolved", resolved_by: moderator, resolved_at: Time.current,
        resolution_outcome: outcome, resolution_summary: summary,
        resolution_action: (@selected_resolution_action unless @selected_resolution_action == NO_RESOLUTION_ACTION),
        reporter: nil, reported_member: nil, reportable: nil,
        evidence: nil, identity_snapshot: nil, explanation: nil)
      return reload if save

      self
    end

    private

    def validate_resolution_action
      if accepted?
        if selected_resolution_action.blank?
          errors.add(:resolution_action, :blank)
        elsif selected_resolution_action != NO_RESOLUTION_ACTION && !Reportable.deletion_action?(selected_resolution_action)
          errors.add(:resolution_action, :invalid)
        end
      elsif selected_resolution_action.present?
        errors.add(:resolution_action, :requires_acceptance)
      end
    end

    def review_verifier
      Rails.application.message_verifier(:community_report_review_revision)
    end
  end
end
