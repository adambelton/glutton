CountedPage = Data.define(:entries, :number, :total, :total_pages) do
  def self.load(relation, number:, page_size:)
    total = relation.count
    entries = relation.offset((number - 1) * page_size).limit(page_size).to_a
    total_pages = [ (total + page_size - 1) / page_size, 1 ].max
    new(entries:, number:, total:, total_pages:)
  end
end
