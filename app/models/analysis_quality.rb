class AnalysisQuality < ApplicationRecord
  belongs_to :film_analysis
  belongs_to :film_quality

  def readonly?
    persisted?
  end
end
