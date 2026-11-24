require "test_helper"

module Library
  module CollectionManagement
    class MarkWatchedTest < ActiveSupport::TestCase
      setup do
        @user = Identity::UserGuest.create!
        @film = Registry::Film.create!(title: "A catalogue film")
      end

      test "adds an absent film as Watched and publishes the Library event" do
        assert_difference -> { watched_events.count }, 1 do
          MarkWatched.call(user_id: @user.id, film_id: @film.id)
        end

        assert LibraryFilm.watched.exists?(user: @user, film: @film)
        assert_equal({ "user_id" => @user.id, "film_id" => @film.id }, watched_events.sole.payload)
      end

      test "moves a Watchlist entry in place and publishes the Library event" do
        library_film = AddToWatchlist.call(user_id: @user.id, film_id: @film.id)
        assert_no_difference "Library::LibraryFilm.count" do
          assert_difference -> { watched_events.count }, 1 do
            MarkWatched.call(user_id: @user.id, film_id: @film.id)
          end
        end

        assert library_film.reload.watched?
      end

      test "rejects a stale Mark Watched action without changing the entry or republishing" do
        library_film = AddToWatched.call(user_id: @user.id, film_id: @film.id)
        watched_at = library_film.watched_at
        travel 1.minute

        assert_no_difference -> { watched_events.count } do
          assert_raises(Errors::AlreadyWatched) do
            MarkWatched.call(user_id: @user.id, film_id: @film.id)
          end
        end
        assert_equal watched_at, library_film.reload.watched_at
      end

      private

      def watched_events
        DomainEvents::DomainEvent.where(name: Events::FILM_MARKED_WATCHED)
      end
    end
  end
end
