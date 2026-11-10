require "net/http"

module Registry
  module Sources
    class WikipediaClient
      def self.context(title:, wikidata_id:, tmdb_id:)
        new.context(title:, wikidata_id:, tmdb_id:)
      end

      def initialize(http_class: Net::HTTP)
        @request = ProviderRequest.new(host: "en.wikipedia.org", maximum_bytes: 8.megabytes, http_class:)
      end

      def context(title:, wikidata_id:, tmdb_id:)
        payload = request_json(parameters: {
          action: "query", titles: title, redirects: 1, prop: "info|pageprops|revisions",
          rvprop: "ids|timestamp", rvlimit: 1, meta: "siteinfo", siprop: "rightsinfo", format: "json", formatversion: 2
        })
        query = payload["query"]
        invalid! unless query.is_a?(Hash) && query["pages"].is_a?(Array) && query["pages"].size == 1
        page = query["pages"].first
        invalid! unless page.is_a?(Hash)
        raise Registry::Errors::ImportIncomplete.new(stage: :wikipedia, reason: :missing_article) if page.key?("missing") || page["ns"] != 0
        properties = page["pageprops"]
        unless properties.is_a?(Hash) && properties["wikibase_item"] == wikidata_id && !properties.key?("disambiguation")
          raise Registry::Errors::ImportIncomplete.new(stage: :wikipedia, reason: :identity_mismatch)
        end
        revisions = page["revisions"]
        revision = revisions.first if revisions.is_a?(Array) && revisions.size == 1
        invalid! unless revision.is_a?(Hash) && positive_id?(page["pageid"]) && positive_id?(revision["revid"]) &&
          page["title"].is_a?(String) && page["title"].present?
        rights = query["rightsinfo"]
        invalid! unless rights.is_a?(Hash) && rights["text"].is_a?(String) && rights["text"].present? && WikipediaContext.https_url?(rights["url"])
        parsed = request_json(parameters: {
          action: "parse", oldid: revision.fetch("revid"), prop: "text|revid", format: "json", formatversion: 2
        })["parse"]
        unless parsed.is_a?(Hash) && parsed["pageid"] == page["pageid"] && parsed["revid"] == revision["revid"]
          raise Registry::Errors::ImportIncomplete.new(stage: :wikipedia, reason: :identity_mismatch)
        end
        context = {
          "tmdb_id" => tmdb_id, "wikidata_id" => wikidata_id, "language" => "en", "page_id" => page.fetch("pageid"), "title" => page.fetch("title"),
          "revision_id" => revision.fetch("revid"), "revision_timestamp" => revision["timestamp"],
          "revision_url" => "https://en.wikipedia.org/w/index.php?oldid=#{revision.fetch('revid')}",
          "article_url" => "https://en.wikipedia.org/w/index.php?curid=#{page.fetch('pageid')}",
          "history_url" => "https://en.wikipedia.org/w/index.php?curid=#{page.fetch('pageid')}&action=history",
          "retrieved_at" => Time.current.utc.iso8601, "license" => { "name" => rights.fetch("text"), "url" => rights.fetch("url") },
          "source_paragraphs" => WikipediaParagraphs.call(html: parsed["text"])
        }
        invalid! unless WikipediaContext.usable?(context, tmdb_id:)
        context
      end

      private

      def request_json(parameters:)
        payload = @request.get(path: "/w/api.php", parameters:)
        unless payload.is_a?(Hash)
          raise Registry::Errors::ImportIncomplete.new(stage: :wikipedia, reason: :invalid_response)
        end
        if payload.key?("error")
          code = payload["error"].is_a?(Hash) && payload["error"]["code"]
          reason = %w[maxlag ratelimited].include?(code) ? :rate_limited : :invalid_response
          raise Registry::Errors::ImportIncomplete.new(stage: :wikipedia, reason:)
        end
        payload
      rescue ProviderRequest::Error => error
        raise Registry::Errors::ImportIncomplete.new(stage: :wikipedia, reason: error.reason), cause: nil
      end

      def positive_id?(value)
        value.is_a?(Integer) && value.positive?
      end

      def invalid!
        raise Registry::Errors::ImportIncomplete.new(stage: :wikipedia, reason: :invalid_response)
      end
    end
  end
end
