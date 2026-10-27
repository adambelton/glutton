require "uri"

module FilmKnowledge
  class GeneratedAnalysis
    def self.schema
      text = { type: "string" }
      list = ->(items) { { type: "array", items: } }
      object = ->(properties) { { type: "object", properties:, required: properties.keys, additionalProperties: false } }
      support = object.call(source_id: text, excerpt: text, locator: text,
        basis: { type: "string", enum: %w[plot dialogue audible visual experience context] })
      entry = object.call(id: text, text:, kind: { type: "string", enum: %w[factual experiential interpretation] },
        source_ids: list.call(text), support: list.call(support), independent_support_count: { type: "integer" })
      source = object.call(id: text, reference: text, title: text, origin: text,
        kind: { type: "string", enum: %w[article review screenplay subtitles captions] }, film_version: text,
        version_match: { type: "string", enum: %w[matched unknown] })
      object.call(
        content: object.call(format_version: { type: "integer", enum: [ 1 ] }, context: text,
          narrative: list.call(entry), moments: list.call(entry), synthesis: text,
          sources: list.call(source), gaps: list.call(text)),
        quality_candidates: list.call(object.call(film_quality_id: { type: [ "integer", "null" ] },
          name: { type: [ "string", "null" ] }, dimension: { type: "string", enum: FilmQuality::Dimensions::ALL },
          evidence_references: list.call(text)))
      )
    end

    def self.parse!(text, vocabulary:)
      new(JSON.parse(text), vocabulary:).attributes!
    rescue JSON::ParserError
      raise GenerationFailed.new(:invalid_json), cause: nil
    end

    def initialize(document, vocabulary:)
      @document, @vocabulary = document, vocabulary
    end

    def attributes!
      unless @document.is_a?(Hash) && @document.keys.sort == %w[content quality_candidates]
        raise GenerationFailed.new(:invalid_document)
      end
      @content = @document["content"]
      unless @content.is_a?(Hash) && @content.keys.sort == %w[context format_version gaps moments narrative sources synthesis] &&
          @content["format_version"] == 1 && %w[context synthesis].all? { |key| text?(@content[key]) } &&
          @content["gaps"].is_a?(Array) && @content["gaps"].all? { |gap| text?(gap) }
        raise GenerationFailed.new(:invalid_document)
      end
      validate_sources!
      entries = %w[narrative moments].flat_map do |section|
        rows = @content[section]
        raise GenerationFailed.new(:invalid_evidence) unless rows.is_a?(Array) && rows.all? { |row| valid_entry?(row) }
        rows
      end
      ids = entries.pluck("id")
      raise GenerationFailed.new(:invalid_evidence) unless ids.uniq == ids
      if (@content["narrative"].empty? || @content["moments"].empty?) && @content["gaps"].empty?
        raise GenerationFailed.new(:missing_gaps)
      end
      validate_candidates!
      { content: @content, quality_candidates: @document["quality_candidates"] }
    end

    private

    def text?(value)
      value.is_a?(String) && value.present?
    end

    def url(value)
      return unless text?(value)
      uri = URI.parse(value)
      return unless %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil?
      host = uri.host.downcase
      return if %w[opensubtitles.com opensubtitles.org].any? { |domain| host == domain || host.end_with?(".#{domain}") }
      uri.fragment = nil
      uri.to_s.delete_suffix("/")
    rescue URI::InvalidURIError
      nil
    end

    def validate_sources!
      @sources = @content["sources"]
      unless @sources.is_a?(Array) && @sources.any? && @sources.all? do |source|
          source.is_a?(Hash) && source.keys.sort == %w[film_version id kind origin reference title version_match] &&
            %w[id reference title origin film_version].all? { |key| text?(source[key]) } &&
            %w[article review screenplay subtitles captions].include?(source["kind"]) &&
            %w[matched unknown].include?(source["version_match"]) && url(source["reference"]) &&
            (!%w[subtitles captions].include?(source["kind"]) || (source["film_version"].strip.downcase != "unknown" && source["version_match"] == "matched"))
        end
        raise GenerationFailed.new(:invalid_sources)
      end
      if @sources.pluck("id").uniq.size != @sources.size || @sources.map { |source| url(source["reference"]) }.uniq.size != @sources.size
        raise GenerationFailed.new(:invalid_sources)
      end
    end

    def valid_entry?(entry)
      return false unless entry.is_a?(Hash) && entry.keys.sort == %w[id independent_support_count kind source_ids support text] &&
        %w[id text].all? { |key| text?(entry[key]) } && %w[factual experiential interpretation].include?(entry["kind"])
      source_ids = entry["source_ids"]
      return false unless source_ids.is_a?(Array) && source_ids.any? && source_ids.uniq == source_ids &&
        (source_ids - @sources.pluck("id")).empty?
      supports = entry["support"]
      return false unless supports.is_a?(Array) && supports.size == source_ids.size &&
        supports.all? { |support| valid_support?(support) } && supports.pluck("source_id").sort == source_ids.sort
      origins = @sources.select { |source| source_ids.include?(source["id"]) }.map { |source| source["origin"].strip.downcase }.uniq
      entry["independent_support_count"] == origins.size && (entry["kind"] != "factual" || origins.size >= 2)
    end

    def valid_support?(support)
      return false unless support.is_a?(Hash) && support.keys.sort == %w[basis excerpt locator source_id] &&
        %w[source_id excerpt locator].all? { |key| text?(support[key]) } &&
        %w[plot dialogue audible visual experience context].include?(support["basis"])
      source = @sources.find { |item| item["id"] == support["source_id"] }
      return false unless source
      case source["kind"]
      when "subtitles", "captions"
        allowed = source["kind"] == "subtitles" ? %w[dialogue] : %w[dialogue audible]
        allowed.include?(support["basis"]) && support["locator"].match?(/\A\d{2}:\d{2}:\d{2}[.,]\d{3} --> \d{2}:\d{2}:\d{2}[.,]\d{3}; cue \d+\z/)
      else
        true
      end
    end

    def validate_candidates!
      candidates = @document["quality_candidates"]
      analysis_content = AnalysisContent.new(@content)
      unless candidates.is_a?(Array) && candidates.all? do |candidate|
          next false unless candidate.is_a?(Hash) && candidate.keys.sort == %w[dimension evidence_references film_quality_id name] &&
            FilmQuality::Dimensions::ALL.include?(candidate["dimension"])
          quality_candidate = QualityCandidate.new(candidate, analysis_content:)
          quality_candidate.valid? && (!candidate["film_quality_id"] || @vocabulary.any? { |quality| quality["id"] == candidate["film_quality_id"] && quality["dimension"] == candidate["dimension"] })
        end
        raise GenerationFailed.new(:invalid_candidates)
      end
    end
  end
end
