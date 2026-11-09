require "test_helper"

class Ratings::RefreshExpressionProfilesTest < ActiveSupport::TestCase
  setup do
    @film = Registry::Film.create!(title: "Quiet Dread")
    @calls = []
  end

  test "expression changes coalesce and successful refreshes acknowledge pending work" do
    rating = submit([ "I liked the quiet dread" ])
    pending = request_for(rating)
    rating = revise(rating, [ "I liked the quiet dread" ])
    assert_equal pending.generation, request_for(rating).generation

    result = refresh
    assert_empty result.fetch(:failures)
    assert_equal [ "I liked the quiet dread" ], @calls
    assert_nil request_for(rating)

    intermediate = revise(rating, [ "A replacement expression" ])
    restored = revise(intermediate, [ "I liked the quiet dread" ])
    assert_equal result, refresh
    assert_nil request_for(restored)
    assert_equal [ "I liked the quiet dread" ], @calls

    removed = revise(restored, [])
    cleared = Ratings::ExpressionProfileRevision.find(refresh.fetch(:revisions).fetch(removed.rating_film.user_id))
    assert_empty cleared.profile
    assert_nil request_for(removed)
    assert_equal [ "I liked the quiet dread" ], @calls
  end

  test "baseline ratings and rolled back expressions create no pending work" do
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
    failed = submit([ "Original expression" ])
    original_revision_id = refresh.fetch(:revisions).fetch(failed.rating_film.user_id)
    changed = revise(failed, [ "Changed expression" ])
    succeeded = submit([ "I liked the ending" ])

    result = refresh do |expression|
      raise Ratings::ExpressionProfileRefreshFailed.new(reason: :provider_failure) if expression.fetch("text") == "Changed expression"

      synthesis(expression)
    end

    assert_equal({ failed.rating_film.user_id => :provider_failure }, result.fetch(:failures))
    assert_equal [ succeeded.rating_film.user_id ], result.fetch(:revisions).keys
    assert_equal original_revision_id, Ratings::ExpressionProfile.find_by!(user_id: failed.rating_film.user_id).current_revision.id
    assert request_for(changed).present?
    assert_nil request_for(succeeded)
  end

  test "new pending work survives acknowledgement of an earlier generation" do
    rating = submit([ "Original expression" ])
    generation = request_for(rating).generation

    result = refresh do |expression|
      intermediate = revise(rating, [ "Different expression" ])
      revise(intermediate, [ "Original expression" ])
      synthesis(expression)
    end

    assert_empty result.fetch(:failures)
    assert_not_equal generation, request_for(rating).generation
    assert_equal result, refresh
    assert_nil request_for(rating)
    assert_equal [ "Original expression" ], @calls
  end

  private

  def submit(expression_texts)
    user = Identity::UserGuest.create!
    rating_film = Ratings::RatingFilm.create!(user:, film: @film)
    Ratings::SubmitRating.call(user_id: user.id, rating_film_id: rating_film.id,
      value: Ratings::Rating::Values::PRETTY_GOOD, expression_texts:)
  end

  def revise(rating, expression_texts)
    Ratings::ReviseRating.call(user_id: rating.rating_film.user_id, rating_film_id: rating.rating_film_id,
      previous_rating_id: rating.id, value: Ratings::Rating::Values::BRILLIANT, expression_texts:)
  end

  def request_for(rating)
    Ratings::ExpressionProfileRefreshRequest.find_by(user_id: rating.rating_film.user_id)
  end

  def refresh(&response)
    synthesizer = lambda do |input:, **|
      expressions = input.is_a?(Hash) ? input.fetch("added") : input
      expression = expressions.sole.fetch("expressions").sole
      @calls << expression.fetch("text")
      response ? response.call(expression) : synthesis(expression)
    end
    Ratings::RefreshExpressionProfiles.call(synthesizer:)
  end

  def synthesis(expression)
    { "profile" => expression.fetch("text"), "conclusions" => [ { "anchor" => expression.fetch("text"), "claim" => expression.fetch("text"), "explanation" => "The viewer described the reaction.",
      "expression_ids" => [ expression.fetch("expression_id") ] } ],
      "provider" => "stub", "model" => "stub-model", "usage" => { "input" => 10, "output" => 5 } }
  end
end
