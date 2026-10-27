module FilmKnowledge
  class AnalysisContent
    FORMAT_VERSION = 1

    def initialize(document)
      @document = document
    end

    def valid?
      return false unless @document.is_a?(Hash)

      @document["format_version"] == FORMAT_VERSION &&
        %w[context synthesis].all? { |key| text?(@document[key]) } &&
        valid_sources? && valid_entries?("narrative") && valid_entries?("moments") &&
        evidence_ids.uniq == evidence_ids && @document["gaps"].is_a?(Array) &&
        @document["gaps"].all? { |gap| text?(gap) }
    end

    def evidence_ids
      return [] unless @document.is_a?(Hash)

      (Array(@document["narrative"]) + Array(@document["moments"])).filter_map do |entry|
        entry["id"] if entry.is_a?(Hash)
      end
    end

    private

    def text?(value)
      value.is_a?(String) && value.present?
    end

    def valid_sources?
      sources = @document["sources"]
      sources.is_a?(Array) && sources.any? && sources.all? do |source|
        source.is_a?(Hash) && text?(source["id"]) && text?(source["reference"])
      end && sources.pluck("id").uniq.size == sources.size
    end

    def valid_entries?(section)
      entries = @document[section]
      entries.is_a?(Array) && entries.any? && entries.all? do |entry|
        entry.is_a?(Hash) && text?(entry["id"]) && text?(entry["text"]) &&
          entry["source_ids"].is_a?(Array) && entry["source_ids"].any? &&
          (entry["source_ids"] - @document["sources"].pluck("id")).empty?
      end
    end
  end
end
