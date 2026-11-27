module Community
  module Reportable
    extend ActiveSupport::Concern

    DELETE_RECORD = "delete_record"
    DELETE_ATTRIBUTE_PREFIX = "delete_attribute:"
    REASONS_WITH_SPOILERS = %w[immediate_safety private_information sexual_abuse_or_child_safety self_harm
      harassment_hate_or_impersonation spam_or_scams spoilers other].freeze
    REASONS_WITHOUT_SPOILERS = REASONS_WITH_SPOILERS.excluding("spoilers").freeze

    included do
      has_many :reports, as: :reportable, class_name: "Community::Report", inverse_of: :reportable
    end

    def self.deletion_action?(choice)
      choice == DELETE_RECORD || choice&.start_with?(DELETE_ATTRIBUTE_PREFIX)
    end

    def reportable_revision(evidence: reportable_attributes)
      Digest::SHA256.hexdigest([ self.class.polymorphic_name, id, evidence.sort ].to_json)
    end

    def report_reasons
      REASONS_WITHOUT_SPOILERS
    end

    def lock_for_report_deletion!
      lock!
    end

    def report_deletion_actions
      deletable_attributes = independently_deletable_attributes & reportable_attributes.keys
      actions = deletable_attributes.map { |attribute| "#{DELETE_ATTRIBUTE_PREFIX}#{attribute}" }
      actions << DELETE_RECORD if report_record_deletable?
      actions
    end

    def delete_reported_content!(moderator:, action:)
      Report.require_review_access!(moderator:)
      raise Errors::ReportDeletionUnavailable unless report_deletion_actions.include?(action)

      if action == DELETE_RECORD
        delete_reportable_record!(moderator:)
      else
        self[action.delete_prefix(DELETE_ATTRIBUTE_PREFIX)] = nil
        save!(touch: false)
      end
    end

    private

    def report_record_deletable?
      false
    end

    def independently_deletable_attributes
      []
    end

    def delete_reportable_record!(moderator:)
      destroy!
    end
  end
end
