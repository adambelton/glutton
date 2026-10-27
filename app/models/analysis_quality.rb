class AnalysisQuality < ApplicationRecord
  belongs_to :film_analysis
  belongs_to :film_quality

  around_create :protect_history

  def readonly?
    persisted?
  end

  private

  def protect_history
    Film.find(film_analysis.film_id).with_lock do
      FilmAnalysis.find(film_analysis_id).ensure_editable!
      yield
    end
  end
end
