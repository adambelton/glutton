module FilmImportSources
  def wikipedia_context(tmdb_id: 348, wikidata_id: "Q1", text: "The crew encounters a threat.")
    {
      "tmdb_id" => tmdb_id, "wikidata_id" => wikidata_id, "language" => "en", "page_id" => 10, "title" => "Alien (film)",
      "revision_id" => 20, "revision_timestamp" => "2026-11-01T12:00:00Z", "retrieved_at" => "2026-11-03T12:00:00Z",
      "revision_url" => "https://en.wikipedia.org/w/index.php?oldid=20",
      "article_url" => "https://en.wikipedia.org/w/index.php?curid=10", "history_url" => "https://en.wikipedia.org/w/index.php?curid=10&action=history",
      "license" => { "name" => "Creative Commons Attribution-ShareAlike 4.0", "url" => "https://creativecommons.org/licenses/by-sa/4.0/" },
      "source_paragraphs" => [ { "id" => "P1", "section" => "Plot", "text" => text } ]
    }
  end

  def wikidata_source
    Object.new.tap do |wikidata_client|
      wikidata_client.define_singleton_method(:wikipedia_title) { |wikidata_id:| "Alien (film)" }
    end
  end

  def wikipedia_source
    build = method(:wikipedia_context)
    Object.new.tap do |wikipedia_client|
      wikipedia_client.define_singleton_method(:context) { |title:, wikidata_id:, tmdb_id:| build.call(tmdb_id:, wikidata_id:) }
    end
  end

  def tmdb_source(payload: { "id" => 348, "title" => "Alien" })
    Object.new.tap do |tmdb_client|
      tmdb_client.define_singleton_method(:movie) { |tmdb_id:| payload }
      tmdb_client.define_singleton_method(:external_ids) { |tmdb_id:| { "id" => tmdb_id, "wikidata_id" => "Q1" } }
    end
  end
end
