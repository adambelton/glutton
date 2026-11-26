module Community
  class ReportResolutionAction < Shared::Base
    def initialize(report:)
      @report = report
    end

    def view_template
      action = @report.resolution_action
      if action.blank?
        plain t("community.reports.resolution.actions.none")
      elsif action == Reportable::DELETE_RECORD
        plain t("community.reports.resolution.actions.deleted_record")
      else
        attribute = t("community.reports.evidence_attributes.#{action.delete_prefix(Reportable::DELETE_ATTRIBUTE_PREFIX)}")
        plain t("community.reports.resolution.actions.deleted_attribute", attribute:)
      end
    end
  end
end
