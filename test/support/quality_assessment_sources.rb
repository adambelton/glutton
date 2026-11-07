require_relative "film_import_sources"

module QualityAssessmentSources
  include FilmImportSources

  class Client
    attr_reader :requests

    def initialize(support: {}, default_support: 0.7, before_answer: nil)
      @support, @default_support, @before_answer = support, default_support, before_answer
      @requests = []
    end

    def model
      TypeSafeClient::CONFIGURATION.fetch("model")
    end

    def configuration
      { "model" => model }
    end

    def input_cost(input_tokens:)
      input_tokens * TypeSafeClient::CONFIGURATION.fetch("input_token_price_usd")
    end

    def answer(state:, questions:, phase:)
      @requests << { state:, questions:, phase: }
      @before_answer&.call
      answers = questions.to_h do |id, question|
        answer = case question.fetch("type")
        when "noul"
          { "type" => "noul", "noul" => @support.fetch(id, @default_support) }
        when "choice"
          chosen = question.fetch("criteria").keys.first
          { "type" => "choice", "choice" => chosen,
            "probabilities" => question.fetch("criteria").keys.to_h { |key| [ key, key == chosen ? 1.0 : 0.0 ] } }
        end
        [ id, answer ]
      end
      { "model" => model, "answers" => answers, "usage" => { "input_tokens" => 100, "output_tokens" => 10 } }
    end
  end

  def imported_assignment_film(tmdb_id: 800001, context: wikipedia_context(tmdb_id: tmdb_id))
    Registry::Film.new(tmdb_id:).import!(tmdb_data: { title: "Assessment fixture", release_date: nil, tmdb_metadata: { "details" => {} } }, wikipedia_context: context)
  end

  def assessment_quality(category: quality_categories(:tone), name: "Supported quality")
    Registry::Quality.create!(name:, quality_category: category, match_rule: "A supported property is established.", not_sufficient: "An unsupported property is not established.")
  end

  def quality_definition_snapshots
    Registry::Quality.order(:id).map do |quality|
      { "id" => quality.id, "name" => quality.name, "quality_category_id" => quality.quality_category_id,
        "match_rule" => quality.match_rule, "not_sufficient" => quality.not_sufficient }
    end
  end

  def film_source_snapshot(film:)
    { "title" => film.title, "tmdb_id" => film.tmdb_id, "tmdb_metadata" => film.tmdb_metadata,
      "wikidata_id" => film.wikidata_id, "wikipedia_context" => film.wikipedia_context }.deep_dup
  end

  def quality_category_snapshots
    Registry::QualityCategory.order(:id).map do |quality_category|
      { "id" => quality_category.id, "name" => quality_category.name, "maximum_qualities" => quality_category.maximum_qualities }
    end
  end
end
