require "uri"
require "time"

module Registry
  module WikipediaContext
    NARRATIVE_SECTIONS = %w[plot synopsis story premise plot\ summary plot\ synopsis].freeze

    def self.narrative_section?(section)
      section.to_s.split(" / ").any? { |heading| NARRATIVE_SECTIONS.include?(heading.downcase) }
    end

    # Stored JSON may predate this importer or have been written outside its boundary.
    # Validate the actual packet rather than treating an arbitrary status flag as readiness.
    def self.usable?(context, tmdb_id:)
      return false unless context.is_a?(Hash) && context["tmdb_id"].is_a?(Integer) && context["tmdb_id"] == tmdb_id
      return false unless context["language"] == "en"
      return false unless context["wikidata_id"].is_a?(String) && context["wikidata_id"].match?(/\AQ[1-9][0-9]*\z/)
      return false unless %w[page_id revision_id].all? { |key| context[key].is_a?(Integer) && context[key].positive? }
      return false unless context["title"].is_a?(String) && context["title"].present?
      return false unless context["article_url"] == "https://en.wikipedia.org/w/index.php?curid=#{context['page_id']}" &&
        context["history_url"] == "#{context['article_url']}&action=history" &&
        context["revision_url"] == "https://en.wikipedia.org/w/index.php?oldid=#{context['revision_id']}"
      return false unless %w[retrieved_at revision_timestamp].all? { |key| timestamp?(context[key]) }
      license = context["license"]
      return false unless license.is_a?(Hash) && license["name"].is_a?(String) && license["name"].present? && https_url?(license["url"])
      paragraphs = context["source_paragraphs"]
      return false unless paragraphs.is_a?(Array) && paragraphs.any?
      return false unless paragraphs.each_with_index.all? do |paragraph, index|
        paragraph.is_a?(Hash) && paragraph["id"] == "P#{index + 1}" &&
          (paragraph["section"].nil? || paragraph["section"].is_a?(String)) &&
          paragraph["text"].is_a?(String) && paragraph["text"].match?(/\p{L}/)
      end
      paragraphs.any? { |paragraph| narrative_section?(paragraph["section"]) }
    end

    def self.timestamp?(value)
      value.is_a?(String) && !!Time.iso8601(value)
    rescue ArgumentError
      false
    end
    private_class_method :timestamp?

    def self.https_url?(value)
      return false unless value.is_a?(String)
      uri = URI.parse(value)
      uri.scheme == "https" && uri.host.present? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end
  end
end
