module Ratings
  class ViewExpressionProfile
    def self.call(user_id:)
      new(user_id:).call
    end

    def initialize(user_id:)
      @user_id = user_id
    end

    def call
      revision = ExpressionProfile.find_by(user_id: @user_id)&.current_revision
      { profile: revision&.profile, annotations: annotations(revision), legacy: revision&.legacy_annotations?, changes: changes(revision) }
    end

    private

    def annotations(revision)
      return [] if revision.nil? || revision.legacy_annotations?

      output = revision.expression_profile_revision_eval.output
      evidence = output.fetch("evidence").index_by { |expression| expression.fetch("expression_id") }
      revision.annotations.map do |annotation|
        { claim: annotation.fetch("claim"), end_offset: annotation.fetch("end_offset"), explanation: annotation.fetch("explanation"),
          evidence: annotation.fetch("expression_ids").filter_map { |id| evidence[id] } }
      end
    end

    def changes(revision)
      current = RatingExpression.joins(rating: { rating_film: :film }).merge(Rating.current)
        .where(rating_films: { user_id: @user_id }).order(:id)
        .pluck("films.id", "rating_expressions.text").group_by(&:first).transform_values { |rows| rows.map(&:last) }
      saved = (revision&.expression_texts || []).group_by { |row| row.fetch("film_id") }
        .transform_values { |rows| rows.pluck("text") }
      titles = Registry::Film.where(id: current.keys | saved.keys).pluck(:id, :title).to_h
      historical_titles = revision&.expression_profile_revision_eval&.output&.fetch("evidence", [])&.to_h do |row|
        [ row.fetch("film_id"), row.fetch("film_title") ]
      end || {}

      (current.keys | saved.keys).filter_map do |film_id|
        before, after = saved.fetch(film_id, []), current.fetch(film_id, [])
        next if before == after

        { title: titles[film_id] || historical_titles[film_id], added: difference(after, before), removed: difference(before, after) }
      end.reject { |change| change[:added].empty? && change[:removed].empty? }
    end

    def difference(texts, other)
      remaining = other.dup
      texts.reject do |text|
        index = remaining.index(text)
        index.present? && remaining.delete_at(index)
      end
    end
  end
end
