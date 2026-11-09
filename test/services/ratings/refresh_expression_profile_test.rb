require "test_helper"
require_relative "../../support/film_import_sources"

class Ratings::RefreshExpressionProfileTest < ActiveSupport::TestCase
  include FilmImportSources
  setup do
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "A specific portrayal", release_date: Date.new(1982, 6, 25))
    @rating_film = Ratings::RatingFilm.create!(user: @user, film: @film)
  end

  test "synthesis uses current original expressions with film context and persists their provenance" do
    first = submit([ "Replaced evidence" ])
    current = revise(first, [ "  The quiet dread worked.\n" ])
    foreign = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: @film)
    foreign.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, expression_texts: [ "Other viewer" ])

    revision = refresh do |expressions:, **|
      assert_equal [ { "film_title" => @film.title, "source_paragraphs" => [], "expressions" => [ { "expression_id" => current.rating_expressions.sole.id, "text" => "  The quiet dread worked.\n" } ] } ], expressions
      synthesis("  Likes quiet dread in this portrayal.  ").merge("raw_response" => "private provider detail")
    end

    assert_equal revision, current_revision
    assert_equal "Likes quiet dread in this portrayal.", revision.profile
    evaluation = revision.expression_profile_eval
    assert_equal @user.id, revision.expression_profile.user_id
    assert_equal revision.expression_profile, evaluation.expression_profile
    assert_equal revision.profile, evaluation.output.fetch("profile")
    expression = evaluation.output.fetch("evidence").sole
    assert_equal current.id, expression.fetch("rating_id")
    assert_equal current.rating_expressions.sole.id, expression.fetch("expression_id")
    assert_equal [ expression.slice("film_id", "text") ], revision.expression_texts
    assert_equal @film.id, expression.fetch("film_id")
    assert_equal "  The quiet dread worked.\n", expression.fetch("text")
    assert_equal synthesis.except("profile"), evaluation.output.fetch("synthesis").except("prompt")
    assert_raises(ActiveRecord::ReadOnlyRecord) { revision.save! }
    assert_raises(ActiveRecord::ReadOnlyRecord) { evaluation.save! }
  end

  test "OpenAI synthesizes from imported paragraphs and records the exact instructions" do
    context = wikipedia_context(text: "The crew waits for a transmission.")
    film = Registry::Film.new(tmdb_id: 348).import!(tmdb_data: { title: "Dead Air", release_date: nil,
      tmdb_metadata: { "details" => {} } }, wikipedia_context: context)
    rating_film = Ratings::RatingFilm.create!(user: @user, film:)
    rating = rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT,
      expression_texts: [ "I liked the long wait.", "The anticipation worked." ])
    expressions = rating.rating_expressions.order(:id).map { |expression| { "expression_id" => expression.id, "text" => expression.text } }
    ids = expressions.pluck("expression_id")
    request = nil
    responses = Object.new
    narrative = "The viewer responds to dread built through anticipation. In that setting, a long wait can be part of the appeal."
    conclusions = [
      { "anchor" => "The viewer responds to dread built through anticipation.", "claim" => "Anticipation can build dread the viewer enjoys.", "explanation" => "Both reactions connect the wait to anticipation.", "expression_ids" => ids },
      { "anchor" => "In that setting, a long wait can be part of the appeal.", "claim" => "A long wait can work when it builds dread.", "explanation" => "The viewer explicitly praised the long wait.", "expression_ids" => [ ids.first ] }
    ]
    responses.define_singleton_method(:create) do |**payload|
      request = payload
      content = [ Struct.new(:type, :text).new(type: :output_text, text: JSON.generate("profile" => narrative, "conclusions" => conclusions)) ]
      Struct.new(:status, :output, :model, :usage).new(status: :completed, output: [ Struct.new(:type, :content).new(type: :message, content:) ],
        model: "resolved-luna", usage: Struct.new(:input_tokens, :output_tokens).new(input_tokens: 300, output_tokens: 40))
    end
    adapter = Ratings::ExpressionProfileSynthesizer.new(openai_client: Struct.new(:responses).new(responses:))

    revision = Ratings::RefreshExpressionProfile.call(user_id: @user.id, synthesizer: adapter)
    output = revision.expression_profile_eval.output

    assert_equal [ { "film_title" => "Dead Air", "source_paragraphs" => context.fetch("source_paragraphs"),
      "expressions" => expressions } ], JSON.parse(request.fetch(:input))
    assert_equal false, request.fetch(:store)
    assert_equal "gpt-6.1-terra", request.fetch(:model)
    assert_equal "low", request.dig(:reasoning, :effort)
    assert_equal 3_200, request.fetch(:max_output_tokens)
    assert_equal request.fetch(:model), output.dig("synthesis", "settings", "requested_model")
    assert_equal request.dig(:reasoning, :effort), output.dig("synthesis", "settings", "effort")
    assert_equal [ 20, 20 ], output.fetch("evidence").pluck("source_revision_id")
    assert_equal "resolved-luna", output.dig("synthesis", "model")
    assert_equal request.fetch(:instructions), output.dig("synthesis", "prompt", "instructions")
    assert_equal Digest::SHA256.hexdigest(request.fetch(:instructions)), output.dig("synthesis", "prompt", "sha256")
    assert_equal narrative, revision.profile
    assert_equal conclusions.pluck("claim"), output.fetch("annotations").pluck("claim")
    assert_equal conclusions.map { |claim| narrative.index(claim.fetch("anchor")) + claim.fetch("anchor").length },
      output.fetch("annotations").pluck("end_offset")
    assert_equal conclusions.pluck("explanation"), output.fetch("annotations").pluck("explanation")
    assert_equal true, request.dig(:text, :format_, :strict)
    assert_equal "json_schema", request.dig(:text, :format_, :type)

    Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: rating_film.id, previous_rating_id: rating.id,
      value: Ratings::Rating::Values::BRILLIANT, expression_texts: [ "I disliked the long wait." ])
    assert_no_difference "Ratings::ExpressionProfileEval.count" do
      error = assert_raises(Ratings::ExpressionProfileRefreshFailed) do
        Ratings::RefreshExpressionProfile.call(user_id: @user.id, synthesizer: adapter)
      end
      assert_equal :invalid_response, error.reason
    end
    assert_equal revision, current_revision
  end

  test "rejects an annotation whose anchor is ambiguous or missing" do
    submit([ "I like quiet dread." ])
    [ "Quiet dread", "Missing claim" ].each do |anchor|
      synthesizer = lambda do |expressions:, **|
        id = expressions.sole.fetch("expressions").sole.fetch("expression_id")
        synthesis("Quiet dread works. Quiet dread unsettles.").merge("conclusions" => [
          { "anchor" => anchor, "claim" => "Enjoys dread.", "explanation" => "The viewer praised quiet dread.", "expression_ids" => [ id ] }
        ])
      end
      assert_no_difference "Ratings::ExpressionProfileRevision.count" do
        error = assert_raises(Ratings::ExpressionProfileRefreshFailed) do
          Ratings::RefreshExpressionProfile.call(user_id: @user.id, synthesizer:, tracer_provider: nil)
        end
        assert_equal :invalid_response, error.reason
      end
    end
  end

  test "a manual refresh regenerates an old annotation format without changing the original revision" do
    rating = submit([ "The quiet made it unsettling." ])
    expression = rating.rating_expressions.sole
    profile = Ratings::ExpressionProfile.create!(user: @user)
    output = { "evidence" => [ { "expression_id" => expression.id, "rating_id" => rating.id, "film_id" => @film.id,
      "film_title" => @film.title, "film_release_date" => nil, "text" => expression.text } ],
      "profile" => "Legacy narrative.", "trace_id" => nil, "synthesis" => synthesis.except("profile"),
      "annotations" => [ { "text" => "Legacy narrative.", "explanation" => "Old annotation", "expression_ids" => [ expression.id ] } ] }
    old_revision = Ratings::ExpressionProfileEval.record!(expression_profile: profile, assessment: Struct.new(:result).new(output)).apply_profile!
    Ratings::ExpressionProfileRefreshRequest.find_by!(user: @user).acknowledge!
    synthesizer = lambda do |**|
      synthesis("The viewer likes quiet dread.").merge("conclusions" => [
        { "anchor" => "quiet dread.", "claim" => "Likes quiet dread.", "explanation" => "Quiet helped make the film unsettling.",
          "expression_ids" => [ expression.id ] }
      ])
    end

    result = Ratings::RefreshExpressionProfiles.call(user_id: @user.id, synthesizer:)

    assert_equal current_revision.id, result.fetch(:revisions).fetch(@user.id)
    assert_equal "Likes quiet dread.", current_revision.expression_profile_eval.output.fetch("annotations").sole.fetch("claim")
    assert_equal "Legacy narrative.", old_revision.reload.profile
    assert old_revision.legacy_annotations?
  end

  test "an incomplete OpenAI response leaves the previous profile current" do
    rating = submit([ "I liked the quiet dread." ])
    revision = refresh { |**| synthesis }
    revise(rating, [ "The loud shocks worked." ])
    responses = Object.new
    responses.define_singleton_method(:create) { |**| Struct.new(:status).new(:incomplete) }
    adapter = Ratings::ExpressionProfileSynthesizer.new(openai_client: Struct.new(:responses).new(responses:))

    assert_no_difference "Ratings::ExpressionProfileEval.count" do
      error = assert_raises(Ratings::ExpressionProfileRefreshFailed) do
        Ratings::RefreshExpressionProfile.call(user_id: @user.id, synthesizer: adapter)
      end
      assert_equal :invalid_response, error.reason
    end
    assert_equal revision, current_revision
  end

  test "synthesis sends the full context for a large rating history" do
    captured_input = nil
    responses = Object.new
    responses.define_singleton_method(:create) do |input:, **|
      captured_input = JSON.parse(input)
      content = Struct.new(:type, :text).new(type: :output_text, text: JSON.generate("profile" => "Profile", "conclusions" => []))
      Struct.new(:status, :output, :model, :usage).new(status: :completed,
        output: [ Struct.new(:type, :content).new(type: :message, content: [ content ]) ],
        model: "stub", usage: Struct.new(:input_tokens, :output_tokens).new(input_tokens: 1, output_tokens: 1))
    end
    adapter = Ratings::ExpressionProfileSynthesizer.new(openai_client: Struct.new(:responses).new(responses:))
    expressions = Array.new(100) do |index|
      { "film_title" => "Film #{index}", "source_paragraphs" => [ "Source text. " * 2_900 ],
        "expressions" => [ { "expression_id" => index + 1, "text" => "I liked the atmosphere." } ] }
    end

    adapter.call(expressions:, instructions: Ratings::ExpressionProfileAssessment::INSTRUCTIONS,
      schema: Ratings::ExpressionProfileAssessment::SCHEMA)

    assert_equal expressions, captured_input
  end

  test "an oversized synthesis input is rejected before contacting the provider" do
    adapter = Ratings::ExpressionProfileSynthesizer.new(openai_client: Object.new)

    error = assert_raises(Ratings::ExpressionProfileRefreshFailed) do
      limit = Ratings::ExpressionProfileSynthesizer::CONFIGURATION.fetch("maximum_request_bytes")
      adapter.call(expressions: [ "x" * limit ], instructions: "Describe this viewer.", schema: Ratings::ExpressionProfileAssessment::SCHEMA)
    end
    assert_equal :input_limit, error.reason
  end

  test "recording rejects an invalid evaluation snapshot" do
    result = { "evidence" => [ { "text" => "Unlinked expression" } ], "profile" => "Profile",
      "synthesis" => synthesis.except("profile"), "trace_id" => nil }
    assessment = Struct.new(:result).new(result)
    submit([ "Evidence" ])
    expression_profile = refresh { |**| synthesis }.expression_profile

    assert_no_difference "Ratings::ExpressionProfileEval.count" do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        Ratings::ExpressionProfileEval.record!(expression_profile:, assessment:)
      end
      assert error.record.errors.of_kind?(:output, :invalid)
    end
  end

  test "a recorded evaluation cannot be applied twice" do
    submit([ "Evidence" ])
    revision = refresh { |**| synthesis }
    evaluation = revision.expression_profile_eval

    assert_no_difference "Ratings::ExpressionProfileRevision.count" do
      error = assert_raises(Ratings::ExpressionProfileRefreshFailed) { evaluation.apply_profile! }
      assert_equal :already_applied, error.reason
    end
    assert_equal revision, current_revision
  end

  test "unchanged or initially empty evidence does not synthesize" do
    assert_nil refresh { flunk "Empty evidence must skip synthesis" }
    assert_nil expression_profile
    rating = submit([])
    assert_nil refresh { flunk "A rating without expressions cannot create a profile" }
    assert_nil expression_profile
    revise(rating, [ "The ending was unsettling." ])
    revision = refresh { |**| synthesis }
    another_film = Registry::Film.create!(title: "No expressions")
    another_rating_film = Ratings::RatingFilm.create!(user: @user, film: another_film)
    another_rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)

    assert_no_difference [ "Ratings::ExpressionProfile.count", "Ratings::ExpressionProfileRevision.count", "Ratings::ExpressionProfileEval.count" ] do
      assert_no_queries_match(/"expression_profile_evals"/) do
        current = refresh { flunk "Unchanged evidence must skip synthesis" }
        assert_equal revision, current
        assert_equal "Likes quiet dread.", current.profile
      end
    end
  end

  test "revising only the rating skips synthesis even though expression IDs change" do
    original_rating = submit([ "Quiet dread", "The ending" ])
    revision = refresh { |**| synthesis }
    replacement = revise(original_rating, [ "Quiet dread", "The ending" ])
    assert_not_equal original_rating.rating_expressions.ids, replacement.rating_expressions.ids

    assert_equal revision, refresh { flunk "Identical saved texts must skip synthesis" }
    assert_equal revision, expression_profile.revisions.sole
  end

  test "changes that cancel before refresh leave the existing revision current" do
    original_rating = submit([ "Quiet dread" ])
    revision = refresh { |**| synthesis }
    changed = revise(original_rating, [ "Quiet dread", "The ending" ])
    revise(changed, [ "Quiet dread" ])

    assert_equal revision, refresh { flunk "Cancelled expression changes must skip synthesis" }
    assert_equal revision, expression_profile.revisions.sole
  end

  test "the same expression attached to a different film changes the synthesis input" do
    original_rating = submit([ "The ending worked." ])
    original = refresh { |**| synthesis }
    revise(original_rating, [])
    another_film = Registry::Film.create!(title: "Another portrayal")
    another_rating_film = Ratings::RatingFilm.create!(user: @user, film: another_film)
    another_rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, expression_texts: [ "The ending worked." ])

    revision = refresh do |expressions:, **|
      assert_equal another_film.title, expressions.sole.fetch("film_title")
      assert_equal [ "The ending worked." ], expressions.sole.fetch("expressions").pluck("text")
      synthesis
    end

    assert_equal original.expression_profile_id, revision.expression_profile_id
    assert_equal revision, current_revision
  end

  test "removing the last expression records a cleared revision without synthesis" do
    rating = submit([ "The ending was unsettling." ])
    original = refresh { |**| synthesis }
    revise(rating, [])

    cleared = refresh { flunk "Removed evidence must not trigger synthesis" }

    assert_equal cleared, current_revision
    assert_empty cleared.expression_profile_eval.output.fetch("evidence")
    assert_empty cleared.profile
    assert_nil cleared.expression_profile_eval.output.fetch("synthesis")
    assert_equal "Likes quiet dread.", original.reload.profile
    assert_equal cleared, refresh { flunk "Unchanged empty evidence must skip synthesis" }
  end

  test "identical profile text records newly examined evidence and skips a repeat call" do
    rating = submit([ "The quiet dread worked." ])
    original = refresh { |**| synthesis }
    replacement = revise(rating, [ "The quiet dread was effective." ])

    revision = refresh { |**| synthesis("  Likes quiet dread.  ") }

    assert_not_equal original.id, revision.id
    assert_equal original.expression_profile, revision.expression_profile
    assert_equal [ original, revision ], expression_profile.revisions.order(:id).to_a
    assert_equal original.profile, revision.profile
    assert_equal replacement.id, revision.expression_profile_eval.output.fetch("evidence").sole.fetch("rating_id")
    assert_equal revision, refresh { flunk "The changed evidence has already been examined" }
  end

  test "provider and response failures preserve the current revision" do
    rating = submit([ "Old evidence" ])
    original = refresh { |**| synthesis }
    revise(rating, [ "New evidence" ])

    assert_no_difference [ "Ratings::ExpressionProfile.count", "Ratings::ExpressionProfileRevision.count", "Ratings::ExpressionProfileEval.count" ] do
      error = assert_raises(Ratings::ExpressionProfileRefreshFailed) do
        refresh { |**| raise Timeout::Error, "private provider failure" }
      end
      assert_equal :provider_failure, error.reason
      assert_nil error.cause
      refute_includes error.message, "private provider failure"

      error = assert_raises(Ratings::ExpressionProfileRefreshFailed) do
        refresh { |**| synthesis.merge("usage" => { "input" => -1, "output" => 4 }) }
      end
      assert_equal :invalid_response, error.reason
    end
    assert_equal original, current_revision
  end

  test "failure applying the first revision leaves no parent or evaluation" do
    submit([ "Evidence" ])
    failure = -> { raise ActiveRecord::StatementInvalid, "injected revision persistence failure" }
    Ratings::ExpressionProfileRevision.set_callback(:create, :after, failure)

    assert_no_difference [ "Ratings::ExpressionProfile.count", "Ratings::ExpressionProfileRevision.count", "Ratings::ExpressionProfileEval.count" ] do
      assert_raises(ActiveRecord::StatementInvalid) { refresh { |**| synthesis } }
    end
  ensure
    Ratings::ExpressionProfileRevision.skip_callback(:create, :after, failure, raise: false) if failure.present?
  end

  test "persistence failure rolls back the replacement revision" do
    rating = submit([ "Old evidence" ])
    original = refresh { |**| synthesis }
    revise(rating, [ "New evidence" ])
    failure = -> { raise ActiveRecord::StatementInvalid, "injected profile persistence failure" }
    Ratings::ExpressionProfileRevision.set_callback(:create, :after, failure)

    assert_no_difference [ "Ratings::ExpressionProfile.count", "Ratings::ExpressionProfileRevision.count", "Ratings::ExpressionProfileEval.count" ] do
      assert_raises(ActiveRecord::StatementInvalid) { refresh { |**| synthesis("New profile") } }
    end
    assert_equal original, current_revision
  ensure
    Ratings::ExpressionProfileRevision.skip_callback(:create, :after, failure, raise: false) if failure.present?
  end

  test "expired guest cleanup removes private profile revisions" do
    submit([ "Guest evidence" ])
    revision = refresh { |**| synthesis }

    travel Identity::UserGuest::EXPIRY_DURATION + 1.second do
      assert_equal 1, Identity::CleanupExpiredAccounts.call.fetch(:guests_deleted)
    end

    assert_not Ratings::ExpressionProfile.exists?(revision.expression_profile_id)
    assert_not Ratings::ExpressionProfileRevision.exists?(revision.id)
    assert_not Ratings::ExpressionProfileEval.exists?(revision.expression_profile_eval_id)
  end

  test "a rating revised during synthesis invalidates the result" do
    rating = submit([ "Old evidence" ])

    assert_no_difference [ "Ratings::ExpressionProfile.count", "Ratings::ExpressionProfileRevision.count", "Ratings::ExpressionProfileEval.count" ] do
      error = assert_raises(Ratings::ExpressionProfileRefreshFailed) do
        refresh do |**|
          revise(rating, [ "New evidence" ])
          synthesis
        end
      end
      assert_equal :stale_inputs, error.reason
    end
  end

  test "a competing completion wins and the older result cannot replace it" do
    submit([ "Evidence" ])
    winner = nil

    error = assert_raises(Ratings::ExpressionProfileRefreshFailed) do
      refresh do |**|
        winner = refresh { |**| synthesis("Competing profile") }
        synthesis("Older result")
      end
    end

    assert_equal :stale_inputs, error.reason
    assert_equal winner.expression_profile, Ratings::ExpressionProfile.sole
    assert_equal winner, Ratings::ExpressionProfileRevision.sole
    assert_equal "Competing profile", winner.profile
    assert_equal winner.expression_profile_eval, Ratings::ExpressionProfileEval.sole
  end

  test "an inactive viewer cannot synthesize or record a profile" do
    submit([ "Guest evidence" ])
    travel Identity::UserGuest::EXPIRY_DURATION + 1.second do
      assert_no_difference [ "Ratings::ExpressionProfile.count", "Ratings::ExpressionProfileRevision.count", "Ratings::ExpressionProfileEval.count" ] do
        assert_raises(Ratings::IdentityUnavailable) { refresh { flunk "Inactive viewer must skip synthesis" } }
      end
    end
  end

  test "exported spans contain usage and revision linkage without private evidence or result text" do
    submit([ "private original expression" ])
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))

    revision = refresh(tracer_provider: provider) do |**|
      synthesis("private synthesized profile").merge("secret" => "private-provider-key")
    end

    spans = exporter.finished_spans.index_by(&:name)
    root = spans.fetch("refresh-expression-profile")
    generation = spans.fetch("synthesize-expression-profile")
    assert_equal revision.expression_profile_id, root.attributes.fetch("expression_profile_id")
    assert_equal revision.id, root.attributes.fetch("expression_profile_revision_id")
    assert_equal revision.expression_profile_eval_id, root.attributes.fetch("expression_profile_eval_id")
    assert_equal root.trace_id.unpack1("H*"), revision.expression_profile_eval.output.fetch("trace_id")
    assert_equal root.span_id, generation.parent_span_id
    assert_equal({ "input" => 12, "output" => 4 }, JSON.parse(generation.attributes.fetch("langfuse.observation.usage_details")))
    attributes = spans.values.map(&:attributes).to_json
    refute_includes attributes, "private original expression"
    refute_includes attributes, "private synthesized profile"
    refute_includes attributes, "private-provider-key"
    refute_includes revision.expression_profile_eval.inspect, "private original expression"
    refute_includes revision.expression_profile_eval.inspect, "private synthesized profile"
    refute_includes revision.inspect, "private synthesized profile"
    refute_includes revision.inspect, "private original expression"
    %w[output profile expression_texts].each do |attribute|
      assert_equal "[FILTERED]", ActiveRecord::Base.inspection_filter.filter_param(attribute, "private stored data")
    end
  ensure
    provider&.shutdown
  end

  private

  def expression_profile
    Ratings::ExpressionProfile.find_by(user: @user)
  end

  def current_revision
    expression_profile&.current_revision
  end

  def submit(expressions)
    Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      value: Ratings::Rating::Values::PRETTY_GOOD, expression_texts: expressions)
  end

  def revise(rating, expressions)
    Ratings::ReviseRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      previous_rating_id: rating.id, value: Ratings::Rating::Values::BRILLIANT, expression_texts: expressions)
  end

  def refresh(tracer_provider: nil, &synthesizer)
    adapter = lambda do |expressions:, **options|
      response = synthesizer.call(expressions:, **options)
      profile = response.fetch("profile").strip
      response.merge("profile" => profile, "conclusions" => [
        { "anchor" => profile, "claim" => profile, "explanation" => "The viewer described this reaction.",
          "expression_ids" => expressions.flat_map { |film| film.fetch("expressions").pluck("expression_id") } }
      ])
    end
    Ratings::RefreshExpressionProfile.call(user_id: @user.id, synthesizer: adapter, tracer_provider:)
  end

  def synthesis(profile = "Likes quiet dread.")
    { "profile" => profile, "provider" => "stub", "model" => "stub-model", "usage" => { "input" => 12, "output" => 4 } }
  end
end
