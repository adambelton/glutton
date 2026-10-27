require "test_helper"
require_relative "../support/film_analysis_helpers"

class FilmAnalysisTest < ActiveSupport::TestCase
  include FilmAnalysisHelpers

  setup do
    @film = Film.create!(title: "Analysis example")
    @dimension = FilmQuality::Dimensions::EMOTIONAL_CHARACTER
  end

  test "incomplete human drafts and candidate edits do not publish knowledge" do
    draft = @film.edit_analysis!
    @film.edit_analysis!(content: analysis_content, quality_candidates: [ { name: "Unfinished" } ])
    quality_candidates = draft.reload.quality_candidates
    quality_candidates.first["name"] = "Revised"
    quality_candidates << analysis_candidate
    @film.edit_analysis!(quality_candidates:)
    assert_equal [ "Revised", "Sustained dread" ], draft.reload.quality_candidates.pluck("name")
    @film.edit_analysis!(quality_candidates: draft.quality_candidates.drop(1))
    assert_equal "Sustained dread", draft.reload.quality_candidates.sole.fetch("name")
    assert_empty @film.film_analyses.current
    assert_empty FilmQuality.all
    assert_empty AnalysisQuality.all
  end

  test "editing a stale draft refreshes fields that were not explicitly changed" do
    draft = prepare_analysis
    stale = FilmAnalysis.find(draft.id)
    revised_content = analysis_content.merge("context" => "Revised cut notes")
    @film.edit_analysis!(content: revised_content)
    stale.film.edit_analysis!(quality_candidates: [ analysis_candidate(name: "Revised quality") ])
    assert_equal revised_content, stale.reload.content
    assert_equal "Revised quality", stale.quality_candidates.sole.fetch("name")
  end

  test "editing published knowledge inherits omitted fields and reuses pending changes" do
    prepare_analysis
    published = @film.publish_analysis!
    original_candidates = published.quality_candidates.deep_dup
    revised_content = published.content.merge("context" => "Revised cut")

    draft = @film.edit_analysis!(content: revised_content)
    assert_not_equal published.id, draft.id
    assert_equal original_candidates, draft.quality_candidates
    assert_nil draft.published_at
    assert_empty draft.analysis_qualities
    assert_equal published, @film.film_analyses.current.sole
    assert_equal analysis_content, published.reload.content

    assert_no_difference("FilmAnalysis.count") do
      assert_equal draft, @film.edit_analysis!(quality_candidates: [])
    end
    assert_equal revised_content, draft.reload.content
    assert_empty draft.quality_candidates
    @film.edit_analysis!(content: {})
    assert_empty draft.reload.content
    assert_equal original_candidates, published.reload.quality_candidates
  end

  test "candidate-only revision preserves published content and publication creates new associations" do
    prepare_analysis
    published = @film.publish_analysis!
    draft = @film.edit_analysis!(quality_candidates: [ analysis_candidate(name: "New quality") ])
    assert_equal published.content, draft.content
    replacement = @film.publish_analysis!
    assert_equal draft, replacement
    assert_equal "New quality", replacement.film_qualities.sole.name
    assert_equal "Sustained dread", published.film_qualities.sole.name
    assert_equal replacement, published.reload.superseded_by
    assert_equal replacement.published_at, published.superseded_at
  end

  test "deleted films and nonexistent film references cannot acquire drafts" do
    @film.destroy!
    assert_raises(ActiveRecord::RecordNotFound) { @film.edit_analysis! }
    assert_raises(ActiveRecord::RecordNotFound) { @film.publish_analysis! }
    assert_raises(ActiveRecord::RecordInvalid) { FilmAnalysis.create!(film_id: -1) }
  end

  test "publication resolves selected identities and normalized proposals within dimensions" do
    existing = FilmQuality.create!(dimension: @dimension, name: "Sustained dread")
    other_dimension = FilmQuality::Dimensions::TONE
    selected = FilmQuality.create!(dimension: @dimension, name: "Lingering sadness")
    draft = prepare_analysis(quality_candidates: [ analysis_candidate(name: "  SUSTAINED DREAD "),
      analysis_candidate(name: "Sustained dread", dimension: other_dimension),
      { film_quality_id: selected.id, evidence_references: [ "N1", "M1" ] } ])
    assert_difference("FilmQuality.count", 1) { publish_analysis(draft) }
    assert_equal draft, @film.film_analyses.current.sole
    assert_includes draft.film_qualities, existing
    assert_includes draft.film_qualities, selected
    assert_equal [ "N1", "M1" ], draft.analysis_qualities.find_by!(film_quality: selected).evidence_references
    assert_equal 3, draft.analysis_qualities.count
  end

  test "duplicate resolved candidates roll back new vocabulary and preserve the current analysis" do
    previous = publish_analysis(prepare_analysis)
    draft = prepare_analysis(quality_candidates: [ analysis_candidate(name: "New quality"), analysis_candidate(name: " NEW QUALITY ") ])
    assert_no_difference([ "FilmQuality.count", "AnalysisQuality.count" ]) do
      error = assert_raises(ActiveRecord::RecordInvalid) { publish_analysis(draft) }
      assert error.record.errors.of_kind?(:quality_candidates, :duplicate_quality)
    end
    assert_equal previous, @film.film_analyses.current.sole
    assert_nil previous.reload.superseded_at
    assert_nil draft.reload.published_at
  end

  test "late association failure rolls back the entire publication" do
    previous = publish_analysis(prepare_analysis)
    draft = prepare_analysis(quality_candidates: [ analysis_candidate(name: "New quality"), analysis_candidate(name: "Another quality") ])
    callback = -> { raise "simulated storage failure" if film_quality.name == "Another quality" }
    AnalysisQuality.set_callback(:create, :after, callback)
    assert_no_difference([ "FilmQuality.count", "AnalysisQuality.count" ]) do
      assert_raises(RuntimeError) { publish_analysis(draft) }
    end
    assert_equal previous, @film.film_analyses.current.sole
    assert_nil draft.reload.published_at
  ensure
    AnalysisQuality.skip_callback(:create, :after, callback) if callback
  end

  test "failure after supersession restores the previous active version" do
    previous = publish_analysis(prepare_analysis)
    draft = prepare_analysis(quality_candidates: [ analysis_candidate(name: "New proposal") ])
    draft_id = draft.id
    callback = -> { raise "simulated final write failure" if id == draft_id && saved_change_to_published_at? }
    FilmAnalysis.set_callback(:update, :after, callback)
    assert_no_difference([ "FilmQuality.count", "AnalysisQuality.count" ]) do
      assert_raises(RuntimeError) { publish_analysis(draft) }
    end
    assert_equal previous, @film.film_analyses.current.sole
    assert_nil previous.reload.superseded_at
    assert_nil previous.superseded_by_id
    assert_nil draft.reload.published_at
  ensure
    FilmAnalysis.skip_callback(:update, :after, callback) if callback
  end

  test "publication rejects incomplete documents and dangling evidence" do
    draft = prepare_analysis
    [ {}, analysis_content.except("gaps"), analysis_content.merge("sources" => []),
      analysis_content.merge("moments" => [ { "id" => "M1", "text" => "Claim", "source_ids" => [ "missing" ] } ]),
      analysis_content.merge("moments" => [ { "id" => "N1", "text" => "Claim", "source_ids" => [ "S1" ] } ]) ].each do |content|
      @film.edit_analysis!(content:)
      assert_raises(ActiveRecord::RecordInvalid) { publish_analysis(draft) }
      assert_nil draft.reload.published_at
    end
    @film.edit_analysis!(content: analysis_content, quality_candidates: [ analysis_candidate.merge(evidence_references: [ "missing" ]) ])
    assert_raises(ActiveRecord::RecordInvalid) { publish_analysis(draft) }
    assert_empty AnalysisQuality.all
    assert_empty FilmQuality.all
  end

  test "publication needs supported candidates with unambiguous identities" do
    selected = FilmQuality.create!(dimension: @dimension, name: "Existing")
    draft = prepare_analysis
    [ [], [ { name: "Missing dimension", evidence_references: [ "M1" ] } ],
      [ analysis_candidate.merge(evidence_references: []) ],
      [ analysis_candidate.merge(dimension: "unknown") ],
      [ { film_quality_id: -1, evidence_references: [ "M1" ] } ],
      [ analysis_candidate.merge(film_quality_id: selected.id) ],
      [ { film_quality_id: selected.id, dimension: FilmQuality::Dimensions::TONE, evidence_references: [ "M1" ] } ] ].each do |quality_candidates|
      @film.edit_analysis!(quality_candidates:)
      assert_raises(ActiveRecord::RecordInvalid) { publish_analysis(draft) }
    end
    assert_empty @film.film_analyses.current
  end

  test "replacement preserves content associations and publication inclusive supersession exclusive boundaries" do
    start = Time.utc(2026, 10, 27, 13)
    first = prepare_analysis
    original_content = first.content.deep_dup
    travel_to(start) { publish_analysis(first) }
    old_association = first.analysis_qualities.sole
    replacement = prepare_analysis
    @film.edit_analysis!(content: analysis_content.merge("context" => "Corrected cut notes"))
    assert_equal first, @film.film_analyses.current.sole
    travel_to(start + 1.hour) { publish_analysis(replacement) }
    assert_empty @film.film_analyses.at(start - 1.second)
    assert_equal first, @film.film_analyses.at(start).sole
    assert_equal first, @film.film_analyses.at(start + 1.hour - Rational(1, 1_000_000)).sole
    assert_equal replacement, @film.film_analyses.at(start + 1.hour).sole
    assert_equal replacement, @film.film_analyses.at(start + 2.hours).sole
    assert_equal replacement, first.reload.superseded_by
    assert_equal replacement.reload.published_at, first.superseded_at
    assert_equal original_content, first.content
    assert_equal old_association, first.analysis_qualities.sole
    assert_equal old_association.film_quality_id, replacement.analysis_qualities.sole.film_quality_id
    assert_not_equal old_association.id, replacement.analysis_qualities.sole.id
  end

  test "published analyses candidates and associations cannot be mutated or deleted" do
    draft = prepare_analysis
    stale = FilmAnalysis.find(draft.id)
    original_quality_candidates = draft.quality_candidates.deep_dup
    publish_analysis(draft)
    assert_raises(FilmKnowledge::AnalysisNotEditable) { draft.edit_draft!(content: {}) }
    assert_raises(FilmKnowledge::AnalysisNotEditable) { stale.update!(content: {}) }
    assert_raises(FilmKnowledge::AnalysisNotEditable) { stale.update!(quality_candidates: []) }
    assert_raises(FilmKnowledge::AnalysisNotEditable) { draft.edit_draft!(quality_candidates: []) }
    assert_raises(FilmKnowledge::AnalysisNotEditable) { draft.analysis_qualities.create!(film_quality: draft.film_qualities.sole, evidence_references: [ "M1" ]) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { draft.analysis_qualities.sole.update!(evidence_references: [ "N1" ]) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { draft.analysis_qualities.sole.destroy! }
    assert_raises(FilmKnowledge::AnalysisNotEditable) { draft.destroy! }
    assert_raises(FilmKnowledge::NoUnpublishedAnalysis) { @film.publish_analysis! }
    assert_equal original_quality_candidates, draft.reload.quality_candidates
    assert_equal analysis_content, draft.content
  end

  test "lifecycle and film identity cannot be assigned by ordinary updates" do
    draft = prepare_analysis
    assert_raises(ActiveRecord::RecordInvalid) { draft.update!(published_at: Time.current) }
    draft.reload
    assert_raises(ActiveRecord::RecordInvalid) { draft.update!(film: Film.create!(title: "Different")) }
  end

  test "a film has one editable draft until publication" do
    draft = prepare_analysis
    assert_no_difference("FilmAnalysis.count") do
      assert_equal draft, @film.edit_analysis!(content: analysis_content.merge("context" => "Revised"))
    end
    assert_equal "Revised", draft.reload.content.fetch("context")
    publish_analysis(draft)
    replacement = prepare_analysis
    assert_equal replacement, @film.film_analyses.draft.sole
    assert_equal draft, @film.film_analyses.current.sole
    replacement.destroy!
    assert_empty @film.film_analyses.draft
  end

  test "non-increasing publication time fails without changing current knowledge" do
    travel_to(Time.utc(2026, 10, 27, 13)) do
      previous = publish_analysis(prepare_analysis)
      replacement = prepare_analysis(quality_candidates: [ analysis_candidate(name: "New proposal") ])
      assert_no_difference([ "FilmQuality.count", "AnalysisQuality.count" ]) do
        error = assert_raises(ActiveRecord::RecordInvalid) { publish_analysis(replacement) }
        assert error.record.errors.of_kind?(:published_at, :after_current)
      end
      assert_equal previous, @film.film_analyses.current.sole
      assert_nil replacement.reload.published_at
    end
  end

  test "shared vocabulary cannot be renamed and is retained across films" do
    first = publish_analysis(prepare_analysis)
    quality = first.film_qualities.sole
    second = publish_analysis(prepare_analysis(film: Film.create!(title: "Another film")))
    assert_equal quality, second.film_qualities.sole
    assert_raises(ActiveRecord::ReadOnlyRecord) { quality.update!(name: "New meaning") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { quality.update!(dimension: FilmQuality::Dimensions::TONE) }
  end

  test "failed candidate replacement restores the original set" do
    draft = prepare_analysis
    old_quality_candidates = draft.quality_candidates.deep_dup
    assert_raises(ActiveRecord::RecordInvalid) do
      @film.edit_analysis!(content: nil, quality_candidates: [ analysis_candidate(name: "New") ])
    end
    assert_equal old_quality_candidates, draft.reload.quality_candidates
  end

  test "database constraints enforce a single active analysis and normalized vocabulary identity" do
    draft = prepare_analysis
    assert_raises(ActiveRecord::RecordNotUnique) do
      FilmAnalysis.transaction(requires_new: true) { FilmAnalysis.insert_all!([ { film_id: @film.id } ]) }
    end
    first = publish_analysis(draft)
    assert_raises(ActiveRecord::RecordNotUnique) do
      FilmAnalysis.transaction(requires_new: true) do
        FilmAnalysis.insert_all!([ { film_id: @film.id, published_at: Time.current } ])
      end
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      FilmQuality.transaction(requires_new: true) do
        FilmQuality.insert_all!([ { dimension: @dimension, name: "SUSTAINED DREAD" } ])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      FilmAnalysis.transaction(requires_new: true) { first.update_columns(superseded_at: first.published_at - 1.second, superseded_by_id: first.id) }
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      AnalysisQuality.transaction(requires_new: true) do
        AnalysisQuality.insert_all!([ { film_analysis_id: first.id, film_quality_id: first.film_qualities.sole.id, evidence_references: [ "M1" ] } ])
      end
    end
  end

  test "dimensions are code managed and validated in both model and database" do
    FilmQuality::Dimensions::ALL.each do |dimension|
      quality = FilmQuality.create!(name: "A quality", dimension:)
      assert_equal dimension, quality.reload.dimension
      assert I18n.t("film_knowledge.dimensions.#{dimension}").present?
    end
    invalid = FilmQuality.new(name: "A quality", dimension: "unknown")
    assert_not invalid.valid?
    assert invalid.errors.of_kind?(:dimension, :inclusion)
    assert_match "Dimension", invalid.errors.full_messages.join
    assert_raises(ActiveRecord::StatementInvalid) do
      FilmQuality.transaction(requires_new: true) { FilmQuality.insert_all!([ { name: "Invalid", dimension: "unknown" } ]) }
    end
  end

  test "draft candidates must be an array of objects" do
    draft = prepare_analysis
    [ nil, {}, "text", [ "text" ] ].each do |quality_candidates|
      assert_raises(ActiveRecord::RecordInvalid) { @film.edit_analysis!(quality_candidates:) }
      assert_equal [ analysis_candidate.stringify_keys ], draft.reload.quality_candidates
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      FilmAnalysis.transaction(requires_new: true) { draft.update_columns(quality_candidates: {}) }
    end
  end

  test "publishing fails when no unpublished changes exist" do
    assert_raises(FilmKnowledge::NoUnpublishedAnalysis) { @film.publish_analysis! }
    draft = prepare_analysis
    draft.destroy!
    assert_raises(FilmKnowledge::NoUnpublishedAnalysis) { @film.publish_analysis! }
  end

  test "lifecycle actions retain their own permissions" do
    draft = prepare_analysis
    assert_raises(ActiveRecord::RecordInvalid) { draft.publish!(at: Time.current) }
    other = Film.create!(title: "Another film").edit_analysis!
    assert_raises(ActiveRecord::RecordInvalid) { draft.supersede!(replacement: other, at: Time.current) }
    active = publish_analysis(draft)
    assert_raises(ActiveRecord::RecordInvalid) { active.supersede!(replacement: other, at: Time.current) }
    assert_nil active.reload.superseded_at
  end

  test "custom failure and validation messages resolve English translations" do
    assert_match "Prepare a new draft", FilmKnowledge::AnalysisNotEditable.new.message
    draft = prepare_analysis
    draft.content = {}
    draft.valid?(:publication)
    assert_match "sourced narrative", draft.errors.full_messages.join
    draft.errors.add(:quality_candidates, :duplicate_quality)
    draft.errors.add(:published_at, :after_current)
    draft.errors.add(:base, :immutable_identity)
    draft.errors.add(:base, :managed_lifecycle)
    assert draft.errors.full_messages.none? { |message| message.include?("Translation missing") }
  end
end
