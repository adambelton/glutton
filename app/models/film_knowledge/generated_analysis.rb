module FilmKnowledge
  class GeneratedAnalysis
    def self.schema
      text = { type: "string" }
      list = ->(items) { { type: "array", items: } }
      object = ->(properties) { { type: "object", properties:, required: properties.keys, additionalProperties: false } }
      entry = object.call(id: text, text:, source_ids: list.call(text))
      object.call(
        content: object.call(format_version: { type: "integer", enum: [ 1 ] }, context: text,
          narrative: list.call(entry), moments: list.call(entry), synthesis: text,
          sources: list.call(object.call(id: text, reference: text)), gaps: list.call(text)),
        quality_candidates: list.call(object.call(film_quality_id: { type: [ "integer", "null" ] },
          name: { type: [ "string", "null" ] }, dimension: { type: "string", enum: FilmQuality::Dimensions::ALL },
          evidence_references: list.call(text)))
      )
    end

    def self.parse!(text, source:, vocabulary:)
      document = JSON.parse(text)
      content = document["content"] if document.is_a?(Hash)
      candidates = document["quality_candidates"] if document.is_a?(Hash)
      valid = document.is_a?(Hash) && document.keys.sort == %w[content quality_candidates] &&
        content.is_a?(Hash) && content.keys.sort == %w[context format_version gaps moments narrative sources synthesis] && content["format_version"] == 1 &&
        %w[context synthesis].all? { |key| content[key].is_a?(String) && content[key].present? } &&
        content["sources"] == [ source ] && content["gaps"].is_a?(Array) &&
        content["gaps"].all? { |gap| gap.is_a?(String) && gap.present? }
      raise GenerationFailed.new(:invalid_document) unless valid
      entries = %w[narrative moments].flat_map do |section|
        rows = content[section]
        unless rows.is_a?(Array) && rows.all? { |row| row.is_a?(Hash) && row.keys.sort == %w[id source_ids text] && %w[id text].all? { |key| row[key].is_a?(String) && row[key].present? } && row["source_ids"] == [ source["id"] ] }
          raise GenerationFailed.new(:invalid_evidence)
        end
        rows
      end
      ids = entries.pluck("id")
      raise GenerationFailed.new(:invalid_evidence) unless ids.uniq == ids
      if (content["narrative"].empty? || content["moments"].empty?) && content["gaps"].empty?
        raise GenerationFailed.new(:missing_gaps)
      end
      analysis_content = AnalysisContent.new(content)
      unless candidates.is_a?(Array) && candidates.all? do |candidate|
          next false unless candidate.is_a?(Hash) && FilmQuality::Dimensions::ALL.include?(candidate["dimension"])
          quality_candidate = QualityCandidate.new(candidate, analysis_content:)
          quality_candidate.valid? && (!candidate["film_quality_id"] || vocabulary.any? { |quality| quality["id"] == candidate["film_quality_id"] && quality["dimension"] == candidate["dimension"] })
        end
        raise GenerationFailed.new(:invalid_candidates)
      end
      { content:, quality_candidates: candidates }
    rescue JSON::ParserError
      raise GenerationFailed.new(:invalid_json), cause: nil
    end
  end
end
