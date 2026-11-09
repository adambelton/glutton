module Ratings
  class ExpressionProfileEvidenceChanges
    attr_reader :added, :removed, :retained

    def initialize(previous:, current:)
      current_by_id = current.index_by { |expression| expression.fetch("expression_id") }
      @retained = previous.to_h do |expression|
        id = expression.fetch("expression_id")
        match = current_by_id[id]
        [ id, (match if match.present? && key(match) == key(expression)) ]
      end.compact
      unmatched = (current - @retained.values).group_by { |expression| key(expression) }
      @removed = previous.reject do |expression|
        id = expression.fetch("expression_id")
        next true if @retained.key?(id)

        match = unmatched.fetch(key(expression), []).shift
        @retained[id] = match if match.present?
        match.present?
      end
      @added = current - @retained.values
    end

    private

    def key(expression)
      expression.values_at("film_id", "text")
    end
  end
end
