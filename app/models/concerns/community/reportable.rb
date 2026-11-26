module Community
  module Reportable
    extend ActiveSupport::Concern

    DELETE_RECORD = "delete_record"
    DELETE_ATTRIBUTE_PREFIX = "delete_attribute:"

    included do
      has_many :reports, as: :reportable, class_name: "Community::Report", inverse_of: :reportable
    end

    def self.deletion_action?(choice)
      choice == DELETE_RECORD || choice&.start_with?(DELETE_ATTRIBUTE_PREFIX)
    end

    def reportable_revision(evidence: reportable_attributes)
      Digest::SHA256.hexdigest([ self.class.polymorphic_name, id, evidence.sort ].to_json)
    end

    def lock_for_report_deletion!
      lock!
    end

    def report_deletion_actions
      deletable_attributes = independently_deletable_attributes & reportable_attributes.keys
      [ *deletable_attributes.map { |attribute| "#{DELETE_ATTRIBUTE_PREFIX}#{attribute}" }, DELETE_RECORD ]
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

    def independently_deletable_attributes
      []
    end

    def delete_reportable_record!(moderator:)
      destroy!
    end
  end
end
