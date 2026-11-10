require "net/http"

module Registry
  module Sources
    class WikidataClient
      def self.wikipedia_title(wikidata_id:)
        new.wikipedia_title(wikidata_id:)
      end

      def initialize(http_class: Net::HTTP)
        @request = ProviderRequest.new(host: "www.wikidata.org", maximum_bytes: 8.megabytes, http_class:)
      end

      def wikipedia_title(wikidata_id:)
        unless wikidata_id.is_a?(String) && wikidata_id.match?(/\AQ[1-9][0-9]*\z/)
          raise Registry::Errors::ImportIncomplete.new(stage: :wikidata, reason: :missing_identity)
        end
        payload = request_json(parameters: {
          action: "wbgetentities", ids: wikidata_id, props: "sitelinks", sitefilter: "enwiki", format: "json", formatversion: 2
        })
        entities = payload["entities"]
        entity = entities[wikidata_id] if entities.is_a?(Hash)
        unless entity.is_a?(Hash) && !entity.key?("missing") && entity["id"] == wikidata_id
          raise Registry::Errors::ImportIncomplete.new(stage: :wikidata, reason: :identity_mismatch)
        end
        sitelinks = entity["sitelinks"]
        sitelink = sitelinks["enwiki"] if sitelinks.is_a?(Hash)
        unless sitelink.is_a?(Hash) && sitelink["site"] == "enwiki" && sitelink["title"].is_a?(String) && sitelink["title"].present?
          raise Registry::Errors::ImportIncomplete.new(stage: :wikidata, reason: :missing_article)
        end
        sitelink.fetch("title")
      end

      private

      def request_json(parameters:)
        payload = @request.get(path: "/w/api.php", parameters:)
        unless payload.is_a?(Hash)
          raise Registry::Errors::ImportIncomplete.new(stage: :wikidata, reason: :invalid_response)
        end
        if payload.key?("error")
          code = payload["error"].is_a?(Hash) && payload["error"]["code"]
          reason = %w[maxlag ratelimited].include?(code) ? :rate_limited : :invalid_response
          raise Registry::Errors::ImportIncomplete.new(stage: :wikidata, reason:)
        end
        payload
      rescue ProviderRequest::Error => error
        raise Registry::Errors::ImportIncomplete.new(stage: :wikidata, reason: error.reason), cause: nil
      end
    end
  end
end
