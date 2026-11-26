module Community
  module Reportable
    extend ActiveSupport::Concern

    included do
      has_many :reports, as: :reportable, class_name: "Community::Report", inverse_of: :reportable
    end
  end
end
