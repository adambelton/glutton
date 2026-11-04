class FilmQuality < ApplicationRecord
  belongs_to :film
  belongs_to :quality
  belongs_to :film_quality_eval, optional: true

  validate :evaluation_provenance

  private

  def evaluation_provenance
    if film_quality_eval && !film_quality_eval.supports_association?(film_id:, quality_id:)
      errors.add(:film_quality_eval, :invalid)
    end
  end
end
