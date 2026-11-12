module Registry
  module Sources
    # Read boundary for untrusted provider JSON, including older filtered packets.
    # Storage retains the complete response; only fields consumed by Glutton are adapted.
    class TmdbMetadata
      def initialize(metadata)
        @metadata = metadata
        @details = metadata.fetch("details", {})
        @details = {} unless @details.is_a?(Hash)
      end

      def original_title
        text(@details.fetch("original_title", @metadata["original_title"]))
      end

      def overview
        text(@details["overview"])
      end

      def tagline
        text(@details["tagline"])
      end

      def original_language
        text(@details["original_language"])
      end

      def status
        text(@details["status"])
      end

      def imdb_id
        text(@details["imdb_id"])
      end

      def poster_path
        text(@details["poster_path"])
      end

      def youtube_trailer_id
        videos = @details["videos"]
        return unless videos.is_a?(Hash) && videos["results"].is_a?(Array)

        trailers = videos["results"].select do |video|
          video.is_a?(Hash) && video["site"] == "YouTube" && video["type"] == "Trailer" &&
            video["official"] == true && video["key"].is_a?(String) && video["key"].match?(/\A[A-Za-z0-9_-]{11}\z/)
        end
        trailer = trailers.find { |video| video["iso_639_1"] == "en" } || trailers.first
        trailer&.fetch("key")
      end

      def runtime
        value = @details["runtime"]
        value if value.is_a?(Integer) && value >= 0
      end

      def vote_count
        value = @details["vote_count"]
        value if value.is_a?(Integer) && value >= 0
      end

      def popularity
        value = @details["popularity"]
        value if value.is_a?(Numeric) && value.finite? && value >= 0
      end

      def genre_names
        names("genres")
      end

      def production_company_names
        names("production_companies")
      end

      def production_country_names
        names("production_countries")
      end

      def spoken_language_names
        names("spoken_languages", preferred: "english_name")
      end

      private

      def text(value)
        value.presence if value.is_a?(String)
      end

      def names(key, preferred: "name")
        entries = @details[key]
        return [] unless entries.is_a?(Array)

        entries.filter_map do |entry|
          next unless entry.is_a?(Hash)
          text(entry[preferred]) || text(entry["name"])
        end
      end
    end
  end
end
