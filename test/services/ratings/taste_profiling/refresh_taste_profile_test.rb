require "test_helper"
require_relative "../../../support/film_import_sources"

require Rails.root.join("test/support/taste_profile_openai_stub")

class Ratings::RefreshTasteProfileTest < ActiveSupport::TestCase
  include TasteProfileOpenaiStub
  include FilmImportSources
  setup do
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "A specific portrayal", release_date: Date.new(1982, 6, 25))
    @rating_film = Ratings::RatingFilm.create!(user: @user, film: @film)
  end

  test "synthesis uses current original notes with film context and persists their provenance" do
    first = submit([ "Replaced evidence" ])
    current = revise(first, [ "  The quiet dread worked.\n" ])
    foreign = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: @film)
    foreign.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, notes: "Other viewer")

    revision = refresh do |notes:, **|
      assert_nil notes.fetch("previous_profile")
      change = notes.fetch("note_changes").sole
      assert_equal [ @film.id, @film.title, [], nil, current.notes, nil, current.id ],
        change.values_at("film_id", "film_title", "source_paragraphs", "before", "after", "before_rating_id", "after_rating_id")
      synthesis("  Likes quiet dread in this portrayal.  ").merge("raw_response" => "private provider detail")
    end

    assert_equal revision, current_revision
    assert_equal "Likes quiet dread in this portrayal.", revision.profile
    evaluation = revision.taste_profile_revision_eval
    assert_equal @user.id, revision.taste_profile.user_id
    assert_equal revision.taste_profile, evaluation.taste_profile
    assert_equal revision.profile, evaluation.output.fetch("profile")
    notes = evaluation.output.fetch("evidence").sole
    assert_equal current.id, notes.fetch("rating_id")
    assert_equal [ notes.slice("film_id", "text") ], revision.notes
    assert_equal @film.id, notes.fetch("film_id")
    assert_equal "  The quiet dread worked.\n", notes.fetch("text")
    assert_equal synthesis.except("profile").merge("provider" => "openai"), evaluation.output.fetch("synthesis").slice("provider", "model", "usage")
    assert_raises(ActiveRecord::ReadOnlyRecord) { revision.save! }
    assert_raises(ActiveRecord::ReadOnlyRecord) { evaluation.save! }
  end

  test "OpenAI synthesizes from imported paragraphs and records the exact instructions" do
    context = wikipedia_context(text: "The crew waits for a transmission.")
    film = Registry::Film.new(tmdb_id: 348).import!(tmdb_data: { title: "Dead Air", release_date: nil,
      tmdb_metadata: { "details" => {} } }, wikipedia_context: context)
    rating_film = Ratings::RatingFilm.create!(user: @user, film:)
    rating = rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT,
      notes: "I liked the long wait.\n\nThe anticipation worked.")
    request = nil
    responses = Object.new
    narrative = "The viewer responds to dread built through anticipation. In that setting, a long wait can be part of the appeal."
    conclusions = [
      { "anchor" => "The viewer responds to dread built through anticipation.", "claim" => "Anticipation can build dread the viewer enjoys.", "explanation" => "Both reactions connect the wait to anticipation.", "citations" => [ citation(rating.id, "The anticipation worked.") ] },
      { "anchor" => "In that setting, a long wait can be part of the appeal.", "claim" => "A long wait can work when it builds dread.", "explanation" => "The viewer explicitly praised the long wait.", "citations" => [ citation(rating.id, "I liked the long wait.") ] }
    ]
    responses.define_singleton_method(:create) do |**payload|
      request = payload
      content = [ Struct.new(:type, :text).new(type: :output_text, text: JSON.generate("profile" => narrative, "conclusions" => conclusions)) ]
      Struct.new(:status, :output, :model, :usage).new(status: :completed, output: [ Struct.new(:type, :content).new(type: :message, content:) ],
        model: "resolved-luna", usage: Struct.new(:input_tokens, :output_tokens).new(input_tokens: 300, output_tokens: 40))
    end
    client = Struct.new(:responses).new(responses)

    revision = Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client:)
    output = revision.taste_profile_revision_eval.output

    payload = JSON.parse(request.fetch(:input))
    assert_nil payload.fetch("previous_profile")
    assert_equal [ film.id, "Dead Air", context.fetch("source_paragraphs"), nil, rating.notes, nil, rating.id ],
      payload.fetch("note_changes").sole.values_at("film_id", "film_title", "source_paragraphs", "before", "after", "before_rating_id", "after_rating_id")
    assert_equal false, request.fetch(:store)
    assert_equal "gpt-6.1-terra", request.fetch(:model)
    assert_equal "low", request.dig(:reasoning, :effort)
    assert_equal 3_200, request.fetch(:max_output_tokens)
    assert_equal request.fetch(:model), output.dig("synthesis", "settings", "requested_model")
    assert_equal request.dig(:reasoning, :effort), output.dig("synthesis", "settings", "effort")
    assert_equal [ 20 ], output.fetch("evidence").pluck("source_revision_id")
    assert_equal "resolved-luna", output.dig("synthesis", "model")
    assert_equal request.fetch(:instructions), output.dig("synthesis", "prompt", "instructions")
    assert_equal Digest::SHA256.hexdigest(request.fetch(:instructions)), output.dig("synthesis", "prompt", "sha256")
    assert_equal narrative, revision.profile
    evaluation = revision.taste_profile_revision_eval
    assert_equal JSON.parse(JSON.generate(request)),
      evaluation.input.sole.fetch("request")
    assert_equal({ "profile" => narrative, "conclusions" => conclusions }, output.fetch("provider_response"))
    assert_equal output.fetch("annotations"), revision.reload.annotations
    assert_equal conclusions.pluck("claim"), output.fetch("annotations").pluck("claim")
    assert_equal conclusions.map { |claim| narrative.index(claim.fetch("anchor")) + claim.fetch("anchor").length },
      output.fetch("annotations").pluck("end_offset")
    assert_equal conclusions.pluck("explanation"), output.fetch("annotations").pluck("explanation")
    assert_equal true, request.dig(:text, :format, :strict)
    assert_equal "json_schema", request.dig(:text, :format, :type)

    Ratings::RatingRecording::ReviseRating.call(user_id: @user.id, rating_film_id: rating_film.id, previous_rating_id: rating.id,
      value: Ratings::Rating::Values::BRILLIANT, notes: "I disliked the long wait.")
    assert_no_difference "Ratings::TasteProfileRevisionEval.count" do
      error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) do
        Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client:)
      end
      assert_equal :invalid_response, error.reason
    end
    assert_equal revision, current_revision
  end

  test "rejects an annotation whose anchor is ambiguous or missing" do
    submit([ "I like quiet dread." ])
    [ "Quiet dread", "Missing claim" ].each do |anchor|
      synthesizer = lambda do |input:, **|
        id = input.fetch("note_changes").sole.fetch("after_rating_id")
        synthesis("Quiet dread works. Quiet dread unsettles.").merge("conclusions" => [
          { "anchor" => anchor, "claim" => "Enjoys dread.", "explanation" => "The viewer praised quiet dread.", "citations" => [ citation(id, "I like quiet dread.") ] }
        ])
      end
      assert_no_difference "Ratings::TasteProfileRevision.count" do
        error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) do
          Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client: taste_profile_openai_stub(synthesizer), tracer_provider: nil)
        end
        assert_equal :invalid_response, error.reason
      end
    end
  end

  test "only exact unambiguous excerpts become character ranges into the original notes" do
    rating = submit([ "👻 The sound worked. The pacing worked. The ending was too loud." ])
    valid_quotes = [ "The sound worked.", "The ending was too loud." ]
    [ "I liked the sound.", "worked." ].each do |quote|
      synthesizer = lambda do |**|
        synthesis.merge("conclusions" => [
          { "anchor" => "Likes quiet dread.", "claim" => "Likes quiet dread.", "explanation" => "The viewer discussed the sound.",
            "citations" => [ citation(rating.id, quote) ] }
        ])
      end
      error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) do
        Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client: taste_profile_openai_stub(synthesizer), tracer_provider: nil)
      end
      assert_equal :invalid_response, error.reason
      assert_nil current_revision
    end

    synthesizer = lambda do |**|
      synthesis.merge("conclusions" => [
        { "anchor" => "Likes quiet dread.", "claim" => "Likes quiet dread.", "explanation" => "The sound worked until the loud ending.",
          "citations" => valid_quotes.map { |quote| citation(rating.id, quote) } }
      ])
    end
    revision = Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client: taste_profile_openai_stub(synthesizer), tracer_provider: nil)
    evidence = revision.taste_profile_revision_eval.output.fetch("evidence").sole
    assert_equal rating.notes, evidence.fetch("text")
    ranges = revision.annotations.sole.fetch("citations")
    assert_equal 2, ranges.first.fetch("start_offset")
    assert_equal valid_quotes, ranges.map { |range| evidence.fetch("text")[range.fetch("start_offset")...range.fetch("end_offset")] }
  end

  test "an incomplete OpenAI response leaves the previous profile current" do
    rating = submit([ "I liked the quiet dread." ])
    revision = refresh { |**| synthesis }
    revise(rating, [ "The loud shocks worked." ])
    responses = Object.new
    responses.define_singleton_method(:create) { |**| Struct.new(:status).new(:incomplete) }
    client = Struct.new(:responses).new(responses)

    assert_no_difference "Ratings::TasteProfileRevisionEval.count" do
      error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) do
        Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client:)
      end
      assert_equal :invalid_response, error.reason
    end
    assert_equal revision, current_revision
  end

  test "synthesis sends the full context for a large rating history" do
    evidence = Array.new(100) do |index|
      { "film_id" => index + 1, "rating_id" => index + 1, "film_title" => "Film #{index}",
        "source_paragraphs" => [ "Source text. " * 2_900 ], "text" => "I liked the atmosphere." }
    end
    assessment = build_assessment(evidence)
    client = taste_profile_openai_stub(lambda do |input:, **|
      assert_nil input.fetch("previous_profile")
      changes = input.fetch("note_changes")
      assert_equal evidence.pluck("source_paragraphs"), changes.pluck("source_paragraphs")
      assert_equal evidence.pluck("text"), changes.pluck("after")
      synthesis.merge("conclusions" => [
        { "anchor" => "Likes quiet dread.", "claim" => "Enjoys atmosphere.", "explanation" => "The viewer praised atmosphere.",
          "citations" => [ citation(1, "I liked the atmosphere.") ] }
      ])
    end)

    assessment.call(client:)
    assert_equal "Likes quiet dread.", assessment.result.fetch("profile")
  end

  test "an oversized synthesis input is rejected before contacting the provider" do
    limit = Ratings::TasteProfiling::GenerateTasteProfile::CONFIGURATION.fetch("maximum_request_bytes")
    assessment = build_assessment([ { "film_id" => 1, "rating_id" => 1, "film_title" => "Film",
      "source_paragraphs" => [ "x" * limit ], "text" => "I liked the atmosphere." } ])
    client = taste_profile_openai_stub(->(**) { flunk "Oversized input reached the provider" })

    error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) { assessment.call(client:) }
    assert_equal :input_limit, error.reason
  end

  test "recording rejects an invalid evaluation snapshot" do
    result = { "evidence" => [ { "text" => "Unlinked notes" } ], "profile" => "Profile",
      "synthesis" => synthesis.except("profile"), "trace_id" => nil }
    assessment = Struct.new(:result, :input).new(result, [])
    submit([ "Evidence" ])
    taste_profile = refresh { |**| synthesis }.taste_profile

    assert_no_difference "Ratings::TasteProfileRevisionEval.count" do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        Ratings::TasteProfileRevisionEval.record!(taste_profile:, assessment:)
      end
      assert error.record.errors.of_kind?(:output, :invalid)
    end
  end

  test "a recorded evaluation cannot be applied twice" do
    submit([ "Evidence" ])
    revision = refresh { |**| synthesis }
    evaluation = revision.taste_profile_revision_eval

    assert_no_difference "Ratings::TasteProfileRevision.count" do
      error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) { revision.taste_profile.publish_revision!(evaluation:) }
      assert_equal :already_applied, error.reason
    end
    assert_equal revision, current_revision
  end

  test "unchanged or initially empty evidence does not synthesize" do
    assert_nil refresh { flunk "Empty evidence must skip synthesis" }
    assert_nil taste_profile
    rating = submit([])
    assert_nil refresh { flunk "A rating without notes cannot create a profile" }
    assert_nil taste_profile
    revise(rating, [ "The ending was unsettling." ])
    revision = refresh { |**| synthesis }
    another_film = Registry::Film.create!(title: "No notes")
    another_rating_film = Ratings::RatingFilm.create!(user: @user, film: another_film)
    another_rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)

    assert_no_difference [ "Ratings::TasteProfile.count", "Ratings::TasteProfileRevision.count", "Ratings::TasteProfileRevisionEval.count" ] do
      assert_no_queries_match(/"taste_profile_revision_evals"/) do
        current = refresh { flunk "Unchanged evidence must skip synthesis" }
        assert_equal revision, current
        assert_equal "Likes quiet dread.", current.profile
      end
    end
  end

  test "revising only the rating skips synthesis even though notes IDs change" do
    original_rating = submit([ "Quiet dread", "The ending" ])
    revision = refresh { |**| synthesis }
    replacement = revise(original_rating, [ "Quiet dread", "The ending" ])
    assert_not_equal original_rating.id, replacement.id

    assert_equal revision, refresh { flunk "Identical saved texts must skip synthesis" }
    assert_equal revision, taste_profile.revisions.sole
  end

  test "an independent edit remaps a citation to the latest rating with identical notes" do
    original = submit([ "The long silences made the house feel unsafe." ])
    previous = refresh { |**| synthesis("Enjoys quiet dread.") }
    replacement = revise(original, [ original.notes ])
    film = Registry::Film.create!(title: "Another horror film")
    added = Ratings::RatingFilm.create!(user: @user, film:).submit_rating!(value: "brilliant", notes: "I enjoyed the eerie score.")

    revision = refresh do |notes:, **|
      support = notes.dig("previous_profile", "claims").sole.fetch("supporting_notes").sole
      assert_equal [ original.id, replacement.id, [ original.notes ] ],
        support.values_at("previous_rating_id", "current_rating_id", "retained_quotes")
      assert_equal [ added.id ], notes.fetch("note_changes").pluck("after_rating_id")
      synthesis("Enjoys quiet dread and eerie music.")
    end

    assert_includes revision.annotations.sole.fetch("citations").pluck("rating_id"), replacement.id
    refute_includes revision.annotations.sole.fetch("citations").pluck("rating_id"), original.id
    assert_equal [ original.id ], previous.annotations.sole.fetch("citations").pluck("rating_id")
  end

  test "changes that cancel before refresh leave the existing revision current" do
    original_rating = submit([ "Quiet dread" ])
    revision = refresh { |**| synthesis }
    changed = revise(original_rating, [ "Quiet dread", "The ending" ])
    revise(changed, [ "Quiet dread" ])

    assert_equal revision, refresh { flunk "Cancelled notes changes must skip synthesis" }
    assert_equal revision, taste_profile.revisions.sole
  end

  test "the same notes attached to a different film changes the synthesis input" do
    original_rating = submit([ "The ending worked." ])
    original = refresh { |**| synthesis }
    revise(original_rating, [])
    another_film = Registry::Film.create!(title: "Another portrayal")
    another_rating_film = Ratings::RatingFilm.create!(user: @user, film: another_film)
    another_rating_film.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, notes: "The ending worked.")

    revision = refresh do |notes:, **|
      changes = notes.fetch("note_changes").index_by { |change| change.fetch("film_id") }
      assert_equal [ "The ending worked.", nil ], changes.fetch(@film.id).values_at("before", "after")
      assert_equal [ another_film.title, nil, "The ending worked." ],
        changes.fetch(another_film.id).values_at("film_title", "before", "after")
      synthesis
    end

    assert_equal original.taste_profile_id, revision.taste_profile_id
    assert_equal revision, current_revision
  end

  test "incremental synthesis gets changed film context and maps each prior claim to surviving evidence" do
    changed_film = Registry::Film.new(tmdb_id: 400).import!(tmdb_data: { title: "Changed film", release_date: nil,
      tmdb_metadata: { "details" => {} } }, wikipedia_context: wikipedia_context(tmdb_id: 400, text: "Changed film context."))
    unchanged_film = Registry::Film.new(tmdb_id: 401).import!(tmdb_data: { title: "Unchanged film", release_date: nil,
      tmdb_metadata: { "details" => {} } }, wikipedia_context: wikipedia_context(tmdb_id: 401, wikidata_id: "Q2", text: "Unchanged film context."))
    changed = Ratings::RatingFilm.create!(user: @user, film: changed_film)
    unchanged = Ratings::RatingFilm.create!(user: @user, film: unchanged_film)
    original_rating = changed.submit_rating!(value: "brilliant", notes: "Slow pacing worked.\n\nThe sound built dread.")
    retained = unchanged.submit_rating!(value: "brilliant", notes: "The setting felt personal.")
    narrative = "Slow pacing works. Sound builds dread. Personal settings appeal."
    original = Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, tracer_provider: nil, client: taste_profile_openai_stub(lambda do |**|
      synthesis(narrative).merge("conclusions" => [
        { "anchor" => "Slow pacing works.", "claim" => "Likes slow pacing.", "explanation" => "Praised the pace.",
          "citations" => [ citation(original_rating.id, "Slow pacing worked.") ] },
        { "anchor" => "Sound builds dread.", "claim" => "Likes dread through sound.", "explanation" => "Praised the sound.",
          "citations" => [ citation(original_rating.id, "The sound built dread.") ] },
        { "anchor" => "Personal settings appeal.", "claim" => "Likes personal settings.", "explanation" => "Praised the setting.",
          "citations" => [ citation(retained.id, "The setting felt personal.") ] }
      ])
    end))

    revised = changed.revise_rating!(previous_rating_id: original_rating.id, value: "brilliant",
      notes: "The slow pace worked for me.\n\nThe sound built dread.\n\nThe gore distracted me.")
    retained_id, added_id = retained.id, revised.id
    synthesizer = lambda do |input:, **|
      assert_equal original.profile, input.dig("previous_profile", "narrative")
      claims = input.dig("previous_profile", "claims").index_by { |claim| claim.fetch("claim") }
      pacing = claims.fetch("Likes slow pacing.").fetch("supporting_notes").sole
      sound = claims.fetch("Likes dread through sound.").fetch("supporting_notes").sole
      setting = claims.fetch("Likes personal settings.").fetch("supporting_notes").sole
      assert_equal [ original_rating.id, added_id, [ "Slow pacing worked." ], [] ],
        pacing.values_at("previous_rating_id", "current_rating_id", "quotes", "retained_quotes")
      assert_equal [ added_id, [ "The sound built dread." ] ], sound.values_at("current_rating_id", "retained_quotes")
      assert_equal retained_id, setting.fetch("current_rating_id")
      change = input.fetch("note_changes").sole
      assert_equal [ original_rating.id, added_id, original_rating.notes, revised.notes ],
        change.values_at("before_rating_id", "after_rating_id", "before", "after")
      assert_equal changed_film.wikipedia_context.fetch("source_paragraphs"), change.fetch("source_paragraphs")
      refute_includes JSON.generate(input), "Unchanged film context."
      synthesis("Slow pacing still works.").merge("conclusions" => [
        { "anchor" => "Slow pacing still works.", "claim" => "Likes slow pacing.", "explanation" => "The revised text still praises the pace.",
          "citations" => [ citation(added_id, "The slow pace worked for me.") ] }
      ])
    end

    revision = Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client: taste_profile_openai_stub(synthesizer), tracer_provider: nil)

    assert_equal [ added_id ], revision.taste_profile_revision_eval.output.fetch("annotations").sole.fetch("citations").pluck("rating_id")
    basis = revision.taste_profile_revision_eval.output.dig("synthesis", "basis")
    assert_equal original.id, basis.fetch("previous_profile_revision_id")
    assert_equal [ { "before_rating_id" => original_rating.id, "after_rating_id" => added_id } ], basis.fetch("note_changes")
    assert_equal retained_id, basis.fetch("retained_rating_ids").fetch(retained_id.to_s)
  end

  test "a removed notes cannot be cited in an incremental revision" do
    original_rating = submit([ "The sound worked.", "The pacing worked." ])
    removed_id = original_rating.id
    original = refresh { |**| synthesis }
    revise(original_rating, [ "The pacing worked." ])
    synthesizer = lambda do |**|
      synthesis("Sound worked.").merge("conclusions" => [
        { "anchor" => "Sound worked.", "claim" => "Likes the sound.", "explanation" => "The old notes praised sound.",
          "citations" => [ citation(removed_id, "The sound worked.") ] }
      ])
    end

    error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) do
      Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client: taste_profile_openai_stub(synthesizer), tracer_provider: nil)
    end

    assert_equal :invalid_response, error.reason
    assert_equal original, current_revision
  end

  test "falls back to current evidence when a removal leaves no citable prior support" do
    rating = submit([ "The sound worked." ])
    other_film = Registry::Film.create!(title: "Other film")
    replacement = Ratings::RatingFilm.create!(user: @user, film: other_film)
      .submit_rating!(value: "brilliant", notes: "The pacing worked.")
    initial = lambda do |**|
      synthesis("Sound worked.").merge("conclusions" => [
        { "anchor" => "Sound worked.", "claim" => "Likes the sound.", "explanation" => "The notes praised the sound.",
          "citations" => [ citation(rating.id, "The sound worked.") ] }
      ])
    end
    Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client: taste_profile_openai_stub(initial), tracer_provider: nil)
    revise(rating, [])

    revision = refresh do |notes:, **|
      removed, unchanged = notes.fetch("note_changes")
      assert_equal [ rating.notes, nil ], removed.values_at("before", "after")
      assert_equal [ replacement.notes, replacement.notes, replacement.id ], unchanged.values_at("before", "after", "after_rating_id")
      support = notes.dig("previous_profile", "claims").sole.fetch("supporting_notes").sole
      assert_equal [ rating.id, nil, [ rating.notes ] ], support.values_at("previous_rating_id", "current_rating_id", "quotes")
      synthesis("Pacing worked.")
    end

    assert_equal "Pacing worked.", revision.profile
  end

  test "removing the last notes records a cleared revision without synthesis" do
    rating = submit([ "The ending was unsettling." ])
    original = refresh { |**| synthesis }
    revise(rating, [])

    cleared = refresh { flunk "Removed evidence must not trigger synthesis" }

    assert_equal cleared, current_revision
    assert_empty cleared.taste_profile_revision_eval.output.fetch("evidence")
    assert_empty cleared.profile
    assert_nil cleared.taste_profile_revision_eval.output.fetch("synthesis")
    assert_equal "Likes quiet dread.", original.reload.profile
    assert_equal cleared, refresh { flunk "Unchanged empty evidence must skip synthesis" }
  end

  test "identical profile text records newly examined evidence and skips a repeat call" do
    rating = submit([ "The quiet dread worked." ])
    original = refresh { |**| synthesis }
    replacement = revise(rating, [ "The quiet dread was effective." ])

    revision = refresh { |**| synthesis("  Likes quiet dread.  ") }

    assert_not_equal original.id, revision.id
    assert_equal original.taste_profile, revision.taste_profile
    assert_equal [ original, revision ], taste_profile.revisions.order(:id).to_a
    assert_equal original.profile, revision.profile
    assert_equal replacement.id, revision.taste_profile_revision_eval.output.fetch("evidence").sole.fetch("rating_id")
    assert_equal revision, refresh { flunk "The changed evidence has already been examined" }
  end

  test "provider and response failures preserve the current revision" do
    rating = submit([ "Old evidence" ])
    original = refresh { |**| synthesis }
    revise(rating, [ "New evidence" ])

    assert_no_difference [ "Ratings::TasteProfile.count", "Ratings::TasteProfileRevision.count", "Ratings::TasteProfileRevisionEval.count" ] do
      error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) do
        refresh { |**| raise Timeout::Error, "private provider failure" }
      end
      assert_equal :provider_failure, error.reason
      assert_nil error.cause
      refute_includes error.message, "private provider failure"

      error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) do
        refresh { |**| synthesis.merge("usage" => { "input" => -1, "output" => 4 }) }
      end
      assert_equal :invalid_response, error.reason
    end
    assert_equal original, current_revision
  end

  test "failure applying the first revision leaves no parent or evaluation" do
    submit([ "Evidence" ])
    failure = -> { raise ActiveRecord::StatementInvalid, "injected revision persistence failure" }
    Ratings::TasteProfileRevision.set_callback(:create, :after, failure)

    assert_no_difference [ "Ratings::TasteProfile.count", "Ratings::TasteProfileRevision.count", "Ratings::TasteProfileRevisionEval.count" ] do
      assert_raises(ActiveRecord::StatementInvalid) { refresh { |**| synthesis } }
    end
  ensure
    Ratings::TasteProfileRevision.skip_callback(:create, :after, failure, raise: false) if failure.present?
  end

  test "persistence failure rolls back the replacement revision" do
    rating = submit([ "Old evidence" ])
    original = refresh { |**| synthesis }
    revise(rating, [ "New evidence" ])
    failure = -> { raise ActiveRecord::StatementInvalid, "injected profile persistence failure" }
    Ratings::TasteProfileRevision.set_callback(:create, :after, failure)

    assert_no_difference [ "Ratings::TasteProfile.count", "Ratings::TasteProfileRevision.count", "Ratings::TasteProfileRevisionEval.count" ] do
      assert_raises(ActiveRecord::StatementInvalid) { refresh { |**| synthesis("New profile") } }
    end
    assert_equal original, current_revision
  ensure
    Ratings::TasteProfileRevision.skip_callback(:create, :after, failure, raise: false) if failure.present?
  end

  test "expired guest cleanup removes private profile revisions" do
    submit([ "Guest evidence" ])
    revision = refresh { |**| synthesis }

    travel Identity::UserGuest::EXPIRY_DURATION + 1.second do
      assert_equal 1, Identity::AccountAdministration::CleanupExpiredAccounts.call.fetch(:guests_deleted)
    end

    assert_not Ratings::TasteProfile.exists?(revision.taste_profile_id)
    assert_not Ratings::TasteProfileRevision.exists?(revision.id)
    assert_not Ratings::TasteProfileRevisionEval.exists?(revision.taste_profile_revision_eval_id)
  end

  test "a rating revised during synthesis invalidates the result" do
    rating = submit([ "Old evidence" ])

    assert_no_difference [ "Ratings::TasteProfile.count", "Ratings::TasteProfileRevision.count", "Ratings::TasteProfileRevisionEval.count" ] do
      error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) do
        refresh do |**|
          revise(rating, [ "New evidence" ])
          synthesis
        end
      end
      assert_equal :stale_inputs, error.reason
    end
  end

  test "an identical revision during synthesis preserves the assessed ID and resolves the latest ID for display" do
    rating = submit([ "Quiet dread worked." ])
    replacement = nil

    revision = refresh do |**|
      replacement = revise(rating, [ rating.notes ])
      synthesis
    end

    assert_equal [ rating.id ], revision.annotations.sole.fetch("citations").pluck("rating_id")
    assert_equal [ rating.id ], revision.taste_profile_revision_eval.output.fetch("evidence").pluck("rating_id")
    evidence = Ratings::TasteProfiling::ViewTasteProfile.call(user_id: @user.id).fetch(:annotations).sole.fetch(:evidence).sole
    assert_equal replacement.id, evidence.fetch("rating_id")
    assert_not evidence.fetch("earlier_version")
    assert_equal revision, refresh { flunk "Identical notes must not trigger another synthesis" }
  end

  test "a competing completion wins and the older result cannot replace it" do
    submit([ "Evidence" ])
    winner = nil

    error = assert_raises(Ratings::Errors::TasteProfileRefreshFailed) do
      refresh do |**|
        winner = refresh { |**| synthesis("Competing profile") }
        synthesis("Older result")
      end
    end

    assert_equal :stale_inputs, error.reason
    assert_equal winner.taste_profile, Ratings::TasteProfile.sole
    assert_equal winner, Ratings::TasteProfileRevision.sole
    assert_equal "Competing profile", winner.profile
    assert_equal winner.taste_profile_revision_eval, Ratings::TasteProfileRevisionEval.sole
  end

  test "an inactive viewer cannot synthesize or record a profile" do
    submit([ "Guest evidence" ])
    travel Identity::UserGuest::EXPIRY_DURATION + 1.second do
      assert_no_difference [ "Ratings::TasteProfile.count", "Ratings::TasteProfileRevision.count", "Ratings::TasteProfileRevisionEval.count" ] do
        assert_raises(Identity::Errors::Unavailable) { refresh { flunk "Inactive viewer must skip synthesis" } }
      end
    end
  end

  test "exported spans contain usage and revision linkage without private evidence or result text" do
    submit([ "private original notes" ])
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))

    revision = refresh(tracer_provider: provider) do |**|
      synthesis("private synthesized profile").merge("secret" => "private-provider-key")
    end

    spans = exporter.finished_spans.index_by(&:name)
    root = spans.fetch("refresh-taste-profile")
    generation = spans.fetch("synthesize-taste-profile")
    assert_equal revision.taste_profile_id, root.attributes.fetch("taste_profile_id")
    assert_equal revision.id, root.attributes.fetch("taste_profile_revision_id")
    assert_equal revision.taste_profile_revision_eval_id, root.attributes.fetch("taste_profile_revision_eval_id")
    assert_equal root.trace_id.unpack1("H*"), revision.taste_profile_revision_eval.output.fetch("trace_id")
    assert_equal root.span_id, generation.parent_span_id
    assert_equal({ "input" => 12, "output" => 4 }, JSON.parse(generation.attributes.fetch("langfuse.observation.usage_details")))
    attributes = spans.values.map(&:attributes).to_json
    refute_includes attributes, "private original notes"
    refute_includes attributes, "private synthesized profile"
    refute_includes attributes, "private-provider-key"
    refute_includes revision.taste_profile_revision_eval.inspect, "private original notes"
    refute_includes revision.taste_profile_revision_eval.inspect, "private synthesized profile"
    refute_includes revision.inspect, "private synthesized profile"
    refute_includes revision.inspect, "private original notes"
    %w[input output profile annotations notes].each do |attribute|
      assert_equal "[FILTERED]", ActiveRecord::Base.inspection_filter.filter_param(attribute, "private stored data")
    end
  ensure
    provider&.shutdown
  end

  private

  def build_assessment(evidence)
    tracer = OpenTelemetry::Trace::TracerProvider.new.tracer("test")
    Ratings::TasteProfiling::GenerateTasteProfile.new(evidence:, basis: nil, trace_id: nil, tracer:, trace_tags: [])
  end

  def taste_profile
    Ratings::TasteProfile.find_by(user: @user)
  end

  def current_revision
    taste_profile&.current_revision
  end

  def submit(notes)
    Ratings::RatingRecording::SubmitRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      value: Ratings::Rating::Values::PRETTY_GOOD, notes: notes.join("\n\n").presence)
  end

  def revise(rating, notes)
    Ratings::RatingRecording::ReviseRating.call(user_id: @user.id, rating_film_id: @rating_film.id,
      previous_rating_id: rating.id, value: Ratings::Rating::Values::BRILLIANT, notes: notes.join("\n\n").presence)
  end

  def refresh(tracer_provider: nil, &synthesizer)
    adapter = lambda do |input:, **options|
      response = synthesizer.call(notes: input, **options)
      citations = input.fetch("note_changes").filter_map do |change|
        id = change.fetch("after_rating_id")
        citation(id, change.fetch("after")) if id
      end
      if input.fetch("previous_profile").present?
        input.dig("previous_profile", "claims").each do |claim|
          claim.fetch("supporting_notes").each do |note|
            id = note.fetch("current_rating_id")
            citations.concat(note.fetch("retained_quotes").map { |quote| citation(id, quote) }) if id
          end
        end
      end
      profile = response.fetch("profile").strip
      response.merge("profile" => profile, "conclusions" => [
        { "anchor" => profile, "claim" => profile, "explanation" => "The viewer described this reaction.",
          "citations" => citations }
      ])
    end
    Ratings::TasteProfiling::RefreshTasteProfile.call(user_id: @user.id, client: taste_profile_openai_stub(adapter), tracer_provider:)
  end

  def citation(rating_id, quote)
    { "rating_id" => rating_id, "quote" => quote }
  end

  def synthesis(profile = "Likes quiet dread.")
    { "profile" => profile, "provider" => "stub", "model" => "stub-model", "usage" => { "input" => 12, "output" => 4 } }
  end
end
