require "test_helper"

class Recommendations::RecordFilmResponseTest < ActiveSupport::TestCase
  setup do
    @user = Identity::UserGuest.create!
  end

  def record(film:, response:, **options)
    Recommendations::RecordFilmResponse.call(user_id: @user.id, film_id: film.id, response:, **options)
  end

  test "acceptance publishes the viewer’s acceptance with the recommendation film ID" do
    response = "accepted"
    film = Registry::Film.create!(title: "Accepted recommendation")
    other = Recommendations::RecommendationFilm.create!(user: Identity::UserGuest.create!, film:)
    recommendation_film = record(film:, response:)
    assert_equal response, recommendation_film.reload.response
    assert_nil other.reload.response
    event = DomainEvents::DomainEvent.find_by!(name: "RecommendationAccepted")
    assert_equal "recommendations", event.domain_event_stream.publisher
    assert_equal "film:#{film.id}", event.domain_event_stream.stream_key
    assert_equal 1, event.schema_version
    assert_equal({ "user_id" => @user.id, "film_id" => film.id, "recommendation_film_id" => recommendation_film.id }, event.payload)
    assert_no_difference "DomainEvents::DomainEvent.count" do
      assert_raises(Recommendations::Errors::ResponseUnavailable) { record(film:, response:) }
    end
  end

  test "rejection stays local and failed publication leaves an unanswered recommendation" do
    film = Registry::Film.create!(title: "Rejected film")
    assert_no_difference "DomainEvents::DomainEvent.count" do
      assert_equal "rejected", record(film:, response: "rejected").response
    end

    other = Registry::Film.create!(title: "Publication failure")
    recommendation_film = Recommendations::RecommendationFilm.create!(user: @user, film: other)
    callback = -> { raise ActiveRecord::StatementInvalid, "injected publication failure" }
    DomainEvents::DomainEvent.set_callback(:create, :before, callback)
    assert_no_difference "DomainEvents::DomainEvent.count" do
      assert_raises(ActiveRecord::StatementInvalid) { record(film: other, response: "accepted") }
    end
    assert_nil recommendation_film.reload.response
  ensure
    DomainEvents::DomainEvent.skip_callback(:create, :before, callback, raise: false) if callback
  end
end
