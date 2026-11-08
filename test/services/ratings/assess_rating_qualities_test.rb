require "test_helper"
require_relative "../../support/tmdb_http"

class Ratings::AssessRatingQualitiesTest < ActiveSupport::TestCase
  Client = Struct.new(:handler) do
    def configuration
      { "model" => "jev-1.14.0" }
    end

    def answer(**request)
      handler.call(**request)
    end
  end

  class Http < TmdbHttp::Connection
    def initialize(handler)
      super(response: nil)
      @handler = handler
    end

    def request(request)
      @requests << request
      payload = JSON.parse(request.body)
      yield TmdbHttp::Response.new(code: 200, body: @handler.call(payload).to_json)
    end
  end

  setup do
    @film = Registry::Film.create!(title: "Assessed film")
    @user = Identity::UserGuest.create!
    @rating_film = Ratings::RatingFilm.create!(user: @user, film: @film)
    category = quality_categories(:tone)
    @quality, @other_quality = [ "Dread", "Isolation" ].map do |name|
      quality = category.qualities.create!(name:)
      Registry::FilmQuality.create!(film: @film, quality:)
      quality
    end
  end

  test "bundles expression and quality pairs and applies only judgments that meet the threshold" do
    rating = submit([ "Dread builds slowly.", "I liked the sound." ])
    expressions = rating.rating_expressions.order(:id).to_a
    requests = []
    client = Client.new(lambda do |**request|
      requests << request
      response(request.fetch(:questions), {
        "expression_#{expressions.first.id}_quality_#{@quality.id}" => 0.60,
        "expression_#{expressions.last.id}_quality_#{@other_quality.id}" => 0.59
      })
    end)

    evaluation = assess(rating, client)

    assert_equal 0.60, evaluation.reload.output.fetch("minimum_support")
    assert_equal 4, requests.sole.fetch(:questions).size
    assert_equal [ :expressions, :qualities ], requests.sole.fetch(:state).keys.sort
    assert_equal [ expressions.first.id ], evaluation.output.fetch("decisions").first.fetch("supporting_expression_ids")
    assert_equal({ @quality.id => 5, @other_quality.id => 2 }, evaluation.rating_qualities.pluck(:quality_id, :score).to_h)
    assert_equal evaluation, assess(rating, no_call_client)
  end

  test "no expressions produce baseline rows and an empty call history" do
    evaluation = assess(submit([]), no_call_client)

    assert_empty evaluation.output.fetch("calls")
    assert_equal({ @quality.id => 2, @other_quality.id => 2 }, evaluation.rating_qualities.pluck(:quality_id, :score).to_h)
  end

  test "a film with no accepted qualities requires no evaluation or request" do
    film = Registry::Film.create!(title: "Unclassified film")
    rating_film = Ratings::RatingFilm.create!(user: @user, film:)
    rating = rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, expression_texts: [ "A expression." ])

    assert_nil assess(rating, no_call_client)
    assert_empty rating.rating_quality_evals
    assert_empty rating.rating_qualities
  end

  test "invalid responses and provider failures create no evaluation or score rows" do
    rating = submit([ "Dread builds slowly." ])
    malformed_http = Http.new(->(payload) { response(payload.fetch("questions")).merge("answers" => {}) })
    malformed = TypeSafeClient.new(token: "test-token", http_class: malformed_http)
    failed = Client.new(->(**) { raise Ratings::QualityAssessmentFailed.new(reason: :timeout) })

    assert_no_difference [ "Ratings::RatingQualityEval.count", "Ratings::RatingQuality.count" ] do
      assert_equal :invalid_response, assert_raises(Ratings::QualityAssessmentFailed) { assess(rating, malformed) }.reason
      assert_equal :timeout, assert_raises(Ratings::QualityAssessmentFailed) { assess(rating, failed) }.reason
    end
  end

  test "a revision while the provider runs prevents the old assessment from applying" do
    rating = submit([ "Dread builds slowly." ])
    client = Client.new(lambda do |questions:, **|
      Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @rating_film.id, previous_rating_id: rating.id,
        value: Ratings::Rating::Values::NOT_FOR_ME)
      response(questions)
    end)

    assert_equal :stale_rating, assert_raises(Ratings::QualityAssessmentFailed) { assess(rating, client) }.reason
    assert_empty rating.rating_quality_evals
    assert_empty rating.rating_qualities
  end

  test "the first completed application wins when assessments overlap" do
    rating = submit([ "Dread builds slowly." ])
    winner = nil
    other_client = Client.new(->(questions:, **) { response(questions) })
    client = Client.new(lambda do |questions:, **|
      winner = assess(rating, other_client)
      response(questions, questions.keys.index_with(0.99))
    end)

    actual = assess(rating, client)
    assert_equal winner, actual
    assert_equal winner, rating.rating_quality_evals.sole
    assert_equal({ @quality.id => 2, @other_quality.id => 2 }, winner.rating_qualities.pluck(:quality_id, :score).to_h)
  end

  test "a storage failure on the second score rolls back the evaluation and first score" do
    rating = submit([])
    Ratings::RatingQuality.with_connection do |connection|
      connection.add_check_constraint(:rating_qualities,
        "quality_id <> #{@other_quality.id}", name: "reject_second_quality_for_rollback_test")
    end

    assert_no_difference [ "Ratings::RatingQualityEval.count", "Ratings::RatingQuality.count" ] do
      assert_raises(ActiveRecord::StatementInvalid) { assess(rating, no_call_client) }
    end
  end

  test "assessment tracing links provider usage to the evaluation without exporting expressions" do
    rating = submit([ "Private expression for tracing test." ])
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
    http = Http.new(->(payload) { response(payload.fetch("questions")) })
    client = TypeSafeClient.new(token: "private-test-key", http_class: http, tracer: provider.tracer("glutton.ratings", "1"))

    evaluation = Ratings::AssessRatingQualities.call(rating_id: rating.id, client:, tracer_provider: provider)
    spans = exporter.finished_spans.index_by(&:name)
    root = spans.fetch("assess-rating-qualities")
    generation = spans.fetch("assess-explicit-quality-evidence")

    assert_equal root.span_id, generation.parent_span_id
    assert_equal root.trace_id.unpack1("H*"), evaluation.output.fetch("trace_id")
    assert_equal evaluation.id, root.attributes.fetch("rating_quality_eval_id")
    assert_equal client.configuration, evaluation.reload.output.dig("configuration", "provider")
    assert_equal "jev-1.14.0", generation.attributes.fetch("langfuse.observation.model.name")
    assert_equal({ "input" => 10, "output" => 2 }, JSON.parse(generation.attributes.fetch("langfuse.observation.usage_details")))
    assert_includes http.requests.sole.body, "Private expression for tracing test."
    refute_includes spans.values.map(&:attributes).to_json, "Private expression for tracing test."
    refute_includes spans.values.map(&:attributes).to_json, "private-test-key"
  ensure
    provider&.shutdown
  end

  private

  def submit(expressions)
    @rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, expression_texts: expressions)
  end

  def assess(rating, client)
    Ratings::AssessRatingQualities.call(rating_id: rating.id, client:)
  end

  def no_call_client
    Client.new(->(**) { flunk "Provider should not be called" })
  end

  def response(questions, probabilities = {})
    { "model" => "jev-1.14.0", "usage" => { "input_tokens" => 10, "output_tokens" => 2 },
      "answers" => questions.keys.to_h { |id| [ id, { "type" => "noul", "noul" => probabilities.fetch(id, 0.1) } ] } }
  end
end
