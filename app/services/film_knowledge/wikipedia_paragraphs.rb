require "nokogiri"

module FilmKnowledge
  class WikipediaParagraphs
    EXCLUDED_SECTIONS = [ "cast", "references", "notes", "external links", "see also", "bibliography", "further reading" ].freeze

    def self.call(html:)
      unless html.is_a?(String) && html.valid_encoding?
        raise ImportIncomplete.new(stage: :wikipedia, reason: :invalid_response)
      end
      document = Nokogiri::HTML.fragment(html)
      root = document.at_css(".mw-parser-output")
      raise ImportIncomplete.new(stage: :wikipedia, reason: :invalid_response) unless root

      root.css("table, figure, blockquote, script, style, .mw-editsection, sup.reference, .mw-ref, .reflist, .references, .navbox, .infobox, .hatnote, .metadata, .sidebar, .thumb, .toc, .noprint").remove
      headings, paragraphs = {}, []
      root.css("h2, h3, h4, h5, h6, p").each do |node|
        text = node.text.gsub(/\p{Space}+/, " ").strip
        if node.name != "p"
          level = node.name.delete_prefix("h").to_i
          headings.delete_if { |depth, _| depth >= level }
          headings[level] = text
        elsif text.match?(/\p{L}/) && headings.values.none? { |heading| EXCLUDED_SECTIONS.include?(heading.downcase) }
          paragraphs << { "id" => "P#{paragraphs.size + 1}", "section" => headings.values.join(" / ").presence, "text" => text }
        end
      end
      unless paragraphs.any? { |paragraph| WikipediaContext.narrative_section?(paragraph["section"]) }
        raise ImportIncomplete.new(stage: :wikipedia, reason: :insufficient_context)
      end
      paragraphs
    end
  end
end
