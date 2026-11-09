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
    assert_nil assess(rating, no_call_client)
  end

  test "assesses only qualities without direct evidence against the captured profile" do
    rating = submit([ "Dread builds slowly." ])
    revision = publish_profile
    phases = []
    http = Http.new(lambda do |payload|
      questions = payload.fetch("questions")
      state = payload.fetch("state")
      phases << state.keys
      if state.key?("expressions")
        response(questions, { "expression_#{rating.rating_expressions.sole.id}_quality_#{@quality.id}" => 0.60 })
      else
        assert_equal revision.profile, state.fetch("expression_profile")
        assert_equal [ @other_quality.id.to_s ], state.fetch("qualities").keys
        response(questions, questions.keys.index_with(0.60))
      end
    end)
    client = TypeSafeClient.new(token: "test-token", http_class: http, profile: :ratings)

    evaluation = assess(rating, client)

    assert_equal 2, phases.size
    assert_equal revision.id, evaluation.output.dig("implicit_assessment", "profile_revision_id")
    assert_equal({ @quality.id => [ "explicitly_expressed", 5 ], @other_quality.id => [ "implicitly_expressed", 4 ] },
      evaluation.rating_qualities.pluck(:quality_id, :classification, :score).to_h { |id, classification, score| [ id, [ classification, score ] ] })
    assert_nil assess(rating, no_call_client)
  end

  test "profile reassessment preserves explicit judgments when the initial evaluation publishes during JEV work" do
    rating = submit([ "Dread builds slowly." ])
    revision = publish_profile
    expression_id = rating.rating_expressions.sole.id
    initial = nil
    phases = []
    client = Client.new(lambda do |state:, questions:, phase:|
      phases << phase
      if phase == "assess-explicit-quality-evidence"
        initial_client = Client.new(lambda do |questions:, **|
          response(questions, { "expression_#{expression_id}_quality_#{@quality.id}" => 0.99 })
        end)
        # Record an initial assessment that started before the profile was published.
        initial_assessment = Ratings::RatingQualityAssessment.new(expressions: state.fetch(:expressions),
          qualities: state.fetch(:qualities), profile_revision_id: nil, profile: nil, trace_id: nil).call(client: initial_client)
        initial = Ratings::RatingQualityEval.record!(rating:, assessment: initial_assessment)
        rating.apply_quality_evaluation!(evaluation: initial)
        response(questions, { "expression_#{expression_id}_quality_#{@other_quality.id}" => 0.99 })
      else
        response(questions, questions.keys.index_with(0.99))
      end
    end)

    result = Ratings::AssessRatingQualities.call(rating_id: rating.id, client:, tracer_provider: nil)

    assert_equal [ "assess-explicit-quality-evidence", "assess-implicit-quality-evidence", "assess-implicit-quality-evidence" ], phases
    assert_equal revision.id, result.profile_revision_id
    assert_equal initial.id, result.output.fetch("explicit_source_evaluation_id")
    assert_equal({ @quality.id => 5, @other_quality.id => 4 }, result.rating_qualities.pluck(:quality_id, :score).to_h)
    assert_equal({ @quality.id => 5, @other_quality.id => 2 }, initial.rating_qualities.pluck(:quality_id, :score).to_h)
  end

  test "a newer cleared revision replaces an older applied profile and preserves score history" do
    previous = submit([ "Dread builds slowly." ])
    revision = publish_profile
    rating = @rating_film.revise_rating!(previous_rating_id: previous.id, value: Ratings::Rating::Values::NOT_FOR_ME)
    client = Client.new(lambda do |state:, questions:, phase:|
      assert_equal "assess-implicit-quality-evidence", phase
      assert_equal revision.profile, state.fetch(:expression_profile)
      cleared = publish_profile
      assert_empty cleared.profile
      response(questions, { @quality.id.to_s => 0.60, @other_quality.id.to_s => 0.59 })
    end)

    evaluation = assess(rating, client)

    assert_equal revision.id, evaluation.output.dig("implicit_assessment", "profile_revision_id")
    assert_equal({ @quality.id => -2, @other_quality.id => -1 }, evaluation.rating_qualities.pluck(:quality_id, :score).to_h)

    next_evaluation = assess(rating, no_call_client)
    assert_empty next_evaluation.output.dig("implicit_assessment", "calls")
    assert_equal [ -1, -1 ], next_evaluation.rating_qualities.pluck(:score)
    assert_equal [ -2, -1 ], evaluation.rating_qualities.order(:quality_id).pluck(:score)
    assert_nil assess(rating, no_call_client)

    older_assessment = Struct.new(:result, :input).new(evaluation.output, [])
    older_evaluation = Ratings::RatingQualityEval.record!(rating:, assessment: older_assessment)
    assert_no_difference "Ratings::RatingQuality.count" do
      assert_nil rating.apply_quality_evaluation!(evaluation: older_evaluation)
    end
  end

  test "an older assessment finishing last cannot publish over a newer profile revision" do
    previous = submit([ "Dread builds slowly." ])
    publish_profile
    rating = @rating_film.revise_rating!(previous_rating_id: previous.id, value: Ratings::Rating::Values::BRILLIANT)
    newer_evaluation = nil
    client = Client.new(lambda do |questions:, **|
      cleared = publish_profile
      newer_evaluation = assess(rating, no_call_client)
      assert_equal cleared.id, newer_evaluation.output.dig("implicit_assessment", "profile_revision_id")
      response(questions, questions.keys.index_with(0.99))
    end)

    result = assess(rating, client)

    assert_nil result
    assert_equal newer_evaluation, rating.rating_quality_evals.sole
    assert_equal [ 2, 2 ], newer_evaluation.rating_qualities.pluck(:score)
  end

  test "no expressions produce baseline rows and an empty call history" do
    evaluation = assess(submit([]), no_call_client)

    assert_empty evaluation.input
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
    assert_nil actual
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

  test "assessment tracing links provider usage to the evaluation without exporting expressions or profiles" do
    rating = submit([ "Private expression for tracing test." ])
    revision = publish_profile
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
    http = Http.new(->(payload) { response(payload.fetch("questions")) })
    client = TypeSafeClient.new(token: "private-test-key", http_class: http, profile: :ratings, tracer: provider.tracer("glutton.ratings", "1"))

    evaluation = Ratings::AssessRatingQualities.call(rating_id: rating.id, client:, tracer_provider: provider)
    spans = exporter.finished_spans.index_by(&:name)
    root = spans.fetch("assess-rating-qualities")
    %w[assess-explicit-quality-evidence assess-implicit-quality-evidence].each do |name|
      generation = spans.fetch(name)
      assert_equal root.span_id, generation.parent_span_id
      assert_equal root.trace_id, generation.trace_id
      assert_equal Ratings::AssessRatingQualities::TRACE_TAGS, generation.attributes.fetch("langfuse.trace.tags")
      assert_equal "jev-1.14.0", generation.attributes.fetch("langfuse.observation.model.name")
      assert_equal({ "input" => 10, "output" => 2 }, JSON.parse(generation.attributes.fetch("langfuse.observation.usage_details")))
    end
    assert_equal root.trace_id.unpack1("H*"), evaluation.output.fetch("trace_id")
    assert_equal evaluation.id, root.attributes.fetch("rating_quality_eval_id")
    assert_equal client.configuration, evaluation.reload.output.dig("configuration", "provider")
    assert_equal client.configuration, evaluation.output.dig("implicit_assessment", "configuration")
    assert_equal 2, http.requests.size
    assert_equal http.requests.map { |request| JSON.parse(request.body) }, evaluation.input.pluck("request")
    assert_equal evaluation.input.pluck("phase"), evaluation.output.fetch("provider_responses").pluck("phase")
    assert_equal http.requests.map { |request| response(JSON.parse(request.body).fetch("questions")) },
      evaluation.output.fetch("provider_responses").pluck("response")
    assert_includes http.requests.first.body, "Private expression for tracing test."
    assert_includes http.requests.last.body, revision.profile
    refute_includes spans.values.map(&:attributes).to_json, revision.profile
    refute_includes spans.values.map(&:attributes).to_json, "Private expression for tracing test."
    refute_includes spans.values.map(&:attributes).to_json, "private-test-key"
  ensure
    provider&.shutdown
  end

  private

  def publish_profile
    synthesizer = lambda do |input:, **|
      expressions = input.is_a?(Hash) ? input.fetch("added") : input
      paragraph = {
        "anchor" => "The viewer enjoys slowly building dread.", "claim" => "Enjoys slowly building dread.",
        "explanation" => "The viewer described dread.",
        "expression_ids" => [ expressions.first.fetch("expressions").first.fetch("expression_id") ]
      }
      { "provider" => "stub", "model" => "stub", "usage" => { "input" => 0, "output" => 0 },
        "profile" => paragraph.fetch("anchor"), "conclusions" => [ paragraph ] }
    end
    Ratings::RefreshExpressionProfile.call(user_id: @user.id, synthesizer:, tracer_provider: nil)
  end

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
