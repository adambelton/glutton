require "test_helper"

class Library::DetailActionsTest < ActiveSupport::TestCase
  setup do
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "Detail film")
    @entry = Library::LibraryFilmToWatch.create!(user: @user, film: @film)
  end

  test "detail lookup rejects missing and inactive owners and foreign entries" do
    assert_raises(Identity::Errors::Unavailable) { Library::CollectionManagement::FindFilm.call(user_id: -1, library_film_id: @entry.id) }
    assert_raises(Library::Errors::FilmUnavailable) do
      Library::CollectionManagement::FindFilm.call(user_id: Identity::UserGuest.create!.id, library_film_id: @entry.id)
    end
    travel Identity::UserGuest::EXPIRY_DURATION + 1.second do
      assert_raises(Identity::Errors::Unavailable) { Library::CollectionManagement::FindFilm.call(user_id: @user.id, library_film_id: @entry.id) }
    end
  end
end
