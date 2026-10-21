require "test_helper"

class Ratings::SubmissionTest < ActiveSupport::TestCase
  setup do
    freeze_time
    @user = UserGuest.create!
    @film = Film.create!(title: "Rating submission")
    @rating_film = RatingFilm.create!(user: @user, film: @film)
  end

  def submit(**options)
    Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: @rating_film.id, value: Rating::Values::ENJOYED, **options)
  end

  test "all four choices save owned ratings and exact v1 facts without Library changes" do
    Rating::Values::ALL.each_with_index do |value, index|
      candidate = RatingFilm.create!(user: @user, film: Film.create!(title: "Choice #{index}"))
      rating = nil
      assert_no_difference "LibraryFilm.count" do
        assert_difference [ "Rating.count", "DomainEvent.count" ], 1 do
          rating = submit(rating_film_id: candidate.id, value:)
        end
      end
      assert_equal value, rating.reload.value
      assert_equal candidate.id, rating.rating_film_id
      event = DomainEvent.find_by!(name: Ratings::Events::RATING_SUBMITTED, payload: {
        user_id: @user.id, film_id: candidate.film_id, rating_id: rating.id, value:
      })
      stream = event.domain_event_stream
      assert_equal @user.id, stream.user_id
      assert_equal Ratings::EVENTS_PUBLISHING_DOMAIN, stream.publisher
      assert_equal "film:#{candidate.film_id}", stream.stream_key
      assert_equal 1, event.schema_version
      assert_equal 1, event.sequence
      assert_equal event.id, event.correlation_id
      assert_nil event.causation_id
      assert_equal Time.current, event.occurred_at
    end
  end

  test "invalid choices fail without rating event or stream including coercible inputs" do
    coercible = Object.new
    def coercible.to_s = Rating::Values::ENJOYED
    [ nil, "", "unknown", "ENJOYED", " enjoyed ", Rating::Values::ENJOYED.to_sym, 1, false, [], {}, coercible ].each do |value|
      assert_no_difference [ "Rating.count", "DomainEvent.count", "DomainEventStream.count" ] do
        error = assert_raises(ActiveRecord::RecordInvalid) { submit(value:) }
        assert error.record.errors.of_kind?(:value, :inclusion)
      end
    end
  end

  test "duplicates reject identical and different values without another event" do
    rating = submit
    [ Rating::Values::ENJOYED, Rating::Values::BRILLIANT ].each do |value|
      assert_no_difference [ "Rating.count", "DomainEvent.count" ] do
        assert_raises(Ratings::AlreadyRated) { submit(value:) }
      end
    end
    assert_equal Rating::Values::ENJOYED, rating.reload.value
  end

  test "explicit submission accepts dismissal without changing candidate timestamps or flag" do
    @rating_film.dismiss!
    created_at, updated_at = @rating_film.created_at, @rating_film.updated_at
    travel 1.hour
    submit
    assert @rating_film.reload.dismissed?
    assert_equal created_at, @rating_film.created_at
    assert_equal updated_at, @rating_film.updated_at
    assert_empty Ratings::NextCandidates.call(user_id: @user.id)
  end

  test "missing foreign and inactive identities fail without writes" do
    other = UserGuest.create!
    assert_no_difference [ "Rating.count", "DomainEvent.count" ] do
      assert_raises(Ratings::FilmUnavailable) { submit(user_id: other.id) }
      assert_raises(Ratings::FilmUnavailable) { submit(rating_film_id: -1) }
      deleted = UserDeleted.create!
      travel UserGuest::EXPIRY_DURATION
      [ @user.id, deleted.id, -1 ].each do |user_id|
        assert_raises(Ratings::IdentityUnavailable) { submit(user_id:) }
      end
    end
  end

  test "caller rollback removes both rating and event" do
    assert_no_difference [ "Rating.count", "DomainEvent.count", "DomainEventStream.count" ] do
      Rating.transaction(requires_new: true) do
        submit
        raise ActiveRecord::Rollback
      end
    end
    assert @rating_film.can_submit_rating?
  end

  test "publication failure rolls back source and leaves outer transaction usable" do
    connection = DomainEvent.connection
    connection.execute("ALTER TABLE domain_events ADD CONSTRAINT ratings_test_block_publication CHECK (name <> 'RatingSubmitted')")
    Rating.transaction do
      assert_no_difference [ "Rating.count", "DomainEvent.count", "DomainEventStream.count" ] do
        assert_raises(ActiveRecord::StatementInvalid) { submit }
      end
      assert @rating_film.can_submit_rating?
      assert_equal [ @rating_film.id ], Ratings::NextCandidates.call(user_id: @user.id).map(&:id)
    end
  ensure
    connection&.execute("ALTER TABLE domain_events DROP CONSTRAINT IF EXISTS ratings_test_block_publication")
  end

  test "selection and dismissal do not publish rating events" do
    assert_no_difference [ "Rating.count", "DomainEvent.count" ] do
      Ratings::NextCandidates.call(user_id: @user.id)
      Ratings::Dismiss.call(user_id: @user.id, rating_film_id: @rating_film.id)
    end
  end
end
