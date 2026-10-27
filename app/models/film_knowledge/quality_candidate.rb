module FilmKnowledge
  class QualityCandidate
    include ActiveModel::Validations

    attr_reader :film_quality_id, :name, :dimension, :evidence_references

    def initialize(attributes, analysis_content:)
      @film_quality_id = attributes["film_quality_id"]
      @name = attributes["name"]
      @dimension = attributes["dimension"]
      @evidence_references = attributes["evidence_references"]
      @analysis_content = analysis_content
    end

    validate :identity
    validate :supported_evidence

    private

    def identity
      if film_quality_id
        errors.add(:film_quality_id, :invalid) unless film_quality_id.is_a?(Integer) && film_quality_id.positive? && name.blank?
      else
        errors.add(:name, :blank) unless name.is_a?(String) && name.present?
        errors.add(:dimension, :inclusion) unless FilmQuality::Dimensions::ALL.include?(dimension)
      end
    end

    def supported_evidence
      unless evidence_references.is_a?(Array) && evidence_references.any? &&
          (evidence_references - @analysis_content.evidence_ids).empty?
        errors.add(:evidence_references, :invalid)
      end
    end
  end
end
