module FilmKnowledge
  class TmdbMetadata
    TEXT_FIELDS = %w[overview tagline original_language status homepage imdb_id].freeze
    LIST_FIELDS = { "genres" => { "id" => Integer, "name" => String },
      "production_companies" => { "id" => Integer, "name" => String, "origin_country" => String },
      "production_countries" => { "iso_3166_1" => String, "name" => String },
      "spoken_languages" => { "iso_639_1" => String, "name" => String, "english_name" => String } }.freeze

    def self.from(payload)
      details = {}
      TEXT_FIELDS.each do |key|
        value = payload[key]
        raise InvalidTmdbResponse, "Invalid TMDB #{key}" unless value.nil? || value.is_a?(String)
        details[key] = value.presence
      end
      %w[runtime budget revenue].each do |key|
        value = payload[key]
        raise InvalidTmdbResponse, "Invalid TMDB #{key}" unless value.nil? || (value.is_a?(Integer) && value >= 0)
        details[key] = value
      end
      LIST_FIELDS.each do |key, fields|
        value = payload[key]
        unless value.nil? || (value.is_a?(Array) && value.all? { |entry| entry.is_a?(Hash) && fields.all? { |field, role| entry[field].nil? || entry[field].is_a?(role) } })
          raise InvalidTmdbResponse, "Invalid TMDB #{key}"
        end
        details[key] = value&.map { |entry| fields.keys.index_with { |field| entry[field] } }
      end
      details
    end
  end
end
