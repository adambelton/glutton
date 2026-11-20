class TmdbFilmSearchParameters < Data.define(:query, :page, :batch)
  def self.parse(query:, page:, batch:, allow_blank_query: false)
    return unless query.is_a?(String) && query.valid_encoding?

    length = query.strip.length
    return if length > 200 || (length.zero? && !allow_blank_query)

    return unless page.is_a?(String) && page.valid_encoding? && page.match?(/\A[1-9]\d{0,2}\z/) && page.to_i <= 500
    return unless batch.is_a?(String) && batch.match?(/\A(?:[1-9]\d{0,2}|last)\z/)

    new(query:, page: page.to_i, batch:)
  end
end
