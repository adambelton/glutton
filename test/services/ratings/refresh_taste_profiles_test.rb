require "test_helper"

require Rails.root.join("test/support/taste_profile_openai_stub")

class Ratings::RefreshTasteProfilesTest < ActiveSupport::TestCase
  include TasteProfileOpenaiStub
  setup do
    @film = Registry::Film.create!(title: "Quiet Dread")
    @calls = []
  end

  test "notes changes coalesce and successful refreshes acknowledge pending work" do
    rating = submit([ "I liked the quiet dread" ])
    pending = request_for(rating)
    rating = revise(rating, [ "I liked the quiet dread" ])
    assert_equal pending.generation, request_for(rating).generation

    result = refresh
    assert_empty result.fetch(:failures)
    assert_equal [ "I liked the quiet dread" ], @calls
    assert_nil request_for(rating)

    intermediate = revise(rating, [ "Replacement notes" ])
    restored = revise(intermediate, [ "I liked the quiet dread" ])
    assert_equal result, refresh
    assert_nil request_for(restored)
    assert_equal [ "I liked the quiet dread" ], @calls

    removed = revise(restored, [])
    cleared = Ratings::TasteProfileRevision.find(refresh.fetch(:revisions).fetch(removed.rating_film.user_id))
    assert_empty cleared.profile
    assert_nil request_for(removed)
    assert_equal [ "I liked the quiet dread" ], @calls
  end

  test "baseline ratings and rolled back notes create no pending work" do
    rating = submit([])
    assert_nil request_for(rating)

    Ratings::Rating.transaction(requires_new: true) do
      replacement = revise(rating, [ "I liked the ending" ])
      assert request_for(replacement).present?
      raise ActiveRecord::Rollback
    end

    assert_nil request_for(rating)
    assert_empty refresh.fetch(:revisions)
    assert_empty @calls
  end

  test "failed viewers stay pending and other viewers still refresh" do
    failed = submit([ "Original notes" ])
    original_revision_id = refresh.fetch(:revisions).fetch(failed.rating_film.user_id)
    changed = revise(failed, [ "Changed notes" ])
    succeeded = submit([ "I liked the ending" ])

    result = refresh do |notes|
      raise Ratings::TasteProfileRefreshFailed.new(reason: :provider_failure) if notes.fetch("after") == "Changed notes"

      synthesis(notes)
    end

    assert_equal({ failed.rating_film.user_id => :provider_failure }, result.fetch(:failures))
    assert_equal [ succeeded.rating_film.user_id ], result.fetch(:revisions).keys
    assert_equal original_revision_id, Ratings::TasteProfile.find_by!(user_id: failed.rating_film.user_id).current_revision.id
    assert request_for(changed).present?
    assert_nil request_for(succeeded)
  end

  test "new pending work survives acknowledgement of an earlier generation" do
    rating = submit([ "Original notes" ])
    generation = request_for(rating).generation

    result = refresh do |notes|
      intermediate = revise(rating, [ "Different notes" ])
      revise(intermediate, [ "Original notes" ])
      synthesis(notes)
    end

    assert_empty result.fetch(:failures)
    assert_not_equal generation, request_for(rating).generation
    assert_equal result, refresh
    assert_nil request_for(rating)
    assert_equal [ "Original notes" ], @calls
  end

  private

  def submit(notes)
    user = Identity::UserGuest.create!
    rating_film = Ratings::RatingFilm.create!(user:, film: @film)
    Ratings::SubmitRating.call(user_id: user.id, rating_film_id: rating_film.id,
      value: Ratings::Rating::Values::PRETTY_GOOD, notes: notes.join("\n\n").presence)
  end

  def revise(rating, notes)
    Ratings::ReviseRating.call(user_id: rating.rating_film.user_id, rating_film_id: rating.rating_film_id,
      previous_rating_id: rating.id, value: Ratings::Rating::Values::BRILLIANT, notes: notes.join("\n\n").presence)
  end

  def request_for(rating)
    Ratings::TasteProfileRefreshRequest.find_by(user_id: rating.rating_film.user_id)
  end

  def refresh(&response)
    synthesizer = lambda do |input:, **|
      notes = input.fetch("note_changes").select { |change| change.fetch("after_rating_id") }
      notes = notes.sole
      @calls << notes.fetch("after")
      response ? response.call(notes) : synthesis(notes)
    end
    Ratings::RefreshTasteProfiles.call(client: taste_profile_openai_stub(synthesizer))
  end

  def synthesis(notes)
    { "profile" => notes.fetch("after"), "conclusions" => [ { "anchor" => notes.fetch("after"), "claim" => notes.fetch("after"), "explanation" => "The viewer described the reaction.",
      "citations" => [ { "rating_id" => notes.fetch("after_rating_id"), "quote" => notes.fetch("after") } ] } ],
      "provider" => "stub", "model" => "stub-model", "usage" => { "input" => 10, "output" => 5 } }
  end
end
