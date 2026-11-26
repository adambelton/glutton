module Community
  module Reportable
    extend ActiveSupport::Concern

    included do
      class_attribute :report_source_key, instance_accessor: false
      has_many :reports, as: :reportable, class_name: "Community::Report", inverse_of: :reportable
    end

    def report_source_reference
      { self.class.report_source_key => id }
    end

    def reportable_text(part:)
      reportable_parts[part].presence
    end
  end
end
