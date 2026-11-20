class CollectionSearchParameters < Data.define(:query, :page)
  MAX_QUERY_LENGTH = 254

  def self.parse(query:, page:, max_digits:)
    return unless query.is_a?(String) && query.valid_encoding? && query.length <= MAX_QUERY_LENGTH

    page = self.page(page, max_digits:)
    return unless page.present?

    new(query: query.strip, page:)
  end

  def self.page(value, max_digits:)
    return unless value.is_a?(String) && value.valid_encoding? && value.length <= max_digits && value.match?(/\A[1-9][0-9]*\z/)

    value.to_i
  end
end
