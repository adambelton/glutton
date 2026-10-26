require "test_helper"

class Library::RetentionTest < ActiveSupport::TestCase
  def claim(guest)
    pending = Identity::PrepareRegistration.call(email_address: "library-claim@example.test", guest_user_id: guest.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: pending.id)
    Identity::CompleteRegistration.call(token:)
  end

  test "cleanup deletes only expired guest relationships and preserves shared films and other owners" do
    guest = UserGuest.create!(created_at: (UserGuest::EXPIRY_DURATION / 2).ago)
    active = UserGuest.create!
    registered = UserRegistered.create!(email_address: "library-keep@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    film = Film.create!(title: "Shared Library film")
    [ guest, active, registered ].each { |user| LibraryFilmWatched.create!(user:, film:) }
    session = Session.create!(user: guest)
    travel UserGuest::EXPIRY_DURATION / 2 + 1.second do
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 0 }, Identity::CleanupExpiredAccounts.call)
      assert_not User.exists?(guest.id)
      assert_not Session.exists?(session.id)
      assert_not LibraryFilm.exists?(user_id: guest.id)
      assert_equal 2, LibraryFilm.where(film:).count
      assert Film.exists?(film.id)
    end
  end

  test "in-place registration preserves relationship identity and watched confirmation" do
    guest = UserGuest.create!
    film = Film.create!(title: "Claim retained film")
    LibraryFilmWatched.create!(user: guest, film:)
    row = LibraryFilm.find_by!(user_id: guest.id)
    before = [ row.id, row.created_at, row.updated_at ]
    session = claim(guest)
    assert_equal guest.id, session.user_id
    row.reload
    assert_equal before, [ row.id, row.created_at, row.updated_at ]
  end

  test "a restrictive dependent still rolls back cleanup and restores Library and Identity rows" do
    guest = UserGuest.create!(created_at: (UserGuest::EXPIRY_DURATION / 2).ago)
    film = Film.create!(title: "Rollback retention film")
    LibraryFilmWatched.create!(user: guest, film:)
    session = Session.create!(user: guest)
    connection = User.connection
    connection.execute("CREATE TABLE library_cleanup_blocker (user_id bigint REFERENCES users(id))")
    connection.execute("INSERT INTO library_cleanup_blocker VALUES (#{guest.id})")
    travel UserGuest::EXPIRY_DURATION / 2 + 1.second do
      assert_raises(ActiveRecord::InvalidForeignKey) { Identity::CleanupExpiredAccounts.call }
    end
    assert User.exists?(guest.id)
    assert Session.exists?(session.id)
    assert LibraryFilm.exists?(user_id: guest.id)
    assert Film.exists?(film.id)
  end

  [ [ LibraryFilmToWatch, Library::RemoveFromWatchlist ],
    [ LibraryFilmNotInterested, Library::RemoveNotInterested ] ].each do |model, removal|
    test "claim and cleanup preserve the existing-entry contract for #{model}" do
      freeze_time
      guest = UserGuest.create!
      film = Film.create!(title: "Intent retention")
      original = model.create!(user: guest, film:)
      claim(guest)
      expired = UserGuest.create!
      expired_entry = model.create!(user: expired, film:)
      travel UserGuest::EXPIRY_DURATION do
        assert_raises(Library::IdentityUnavailable) { removal.call(user_id: expired.id, library_film_id: expired_entry.id) }
        assert_equal 1, Identity::CleanupExpiredAccounts.call[:guests_deleted]
        assert_not LibraryFilm.exists?(expired_entry.id)
        assert Film.exists?(film.id)
        assert_equal original.created_at, LibraryFilm.find(original.id).created_at
        assert_equal original.id, removal.call(user_id: guest.id, library_film_id: original.id).id
      end
    end
  end
end
