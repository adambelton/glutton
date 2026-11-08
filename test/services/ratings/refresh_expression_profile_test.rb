require "test_helper"

class Ratings::RefreshExpressionProfileTest < ActiveSupport::TestCase
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

    revision = refresh do |expressions:|
      assert_equal [ { "film_title" => @film.title, "film_release_date" => "1982-06-25", "text" => "  The quiet dread worked.\n" } ], expressions
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
    assert_equal({ "provider" => "stub", "model" => "stub-model", "usage" => { "input" => 12, "output" => 4 } }, evaluation.output.fetch("synthesis"))
    assert_raises(ActiveRecord::ReadOnlyRecord) { revision.save! }
    assert_raises(ActiveRecord::ReadOnlyRecord) { evaluation.save! }
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

    revision = refresh do |expressions:|
      assert_equal another_film.title, expressions.sole.fetch("film_title")
      assert_equal "The ending worked.", expressions.sole.fetch("text")
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
    Ratings::RefreshExpressionProfile.call(user_id: @user.id, synthesizer:, tracer_provider:)
  end

  def synthesis(profile = "Likes quiet dread.")
    { "profile" => profile, "provider" => "stub", "model" => "stub-model", "usage" => { "input" => 12, "output" => 4 } }
  end
end
