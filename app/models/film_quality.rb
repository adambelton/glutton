class FilmQuality < ApplicationRecord
  belongs_to :film
  belongs_to :quality

  validate :supported_evidence

  private

  def supported_evidence
    unless evidence_references.is_a?(Array) && evidence_references.any? &&
        evidence_references.all? { |reference| reference.is_a?(String) && reference.present? }
      errors.add(:evidence_references, :invalid)
    end
  end
end
