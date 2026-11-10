require "test_helper"

class Library::RetentionTest < ActiveSupport::TestCase
  def claim(guest)
    pending = Identity::Registration::PrepareRegistration.call(email_address: "library-claim@example.test", guest_user_id: guest.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::Registration::RegistrationConfirmation.token_for(pending_registration_id: pending.id)
    Identity::Registration::CompleteRegistration.call(token:)
  end

  test "cleanup deletes only expired guest relationships and preserves shared films and other owners" do
    guest = Identity::UserGuest.create!(created_at: (Identity::UserGuest::EXPIRY_DURATION / 2).ago)
    active = Identity::UserGuest.create!
    registered = Identity::UserRegistered.create!(email_address: "library-keep@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    film = Registry::Film.create!(title: "Shared Library film")
    [ guest, active, registered ].each { |user| Library::LibraryFilmWatched.create!(user:, film:) }
    session = Identity::Session.create!(user: guest)
    travel Identity::UserGuest::EXPIRY_DURATION / 2 + 1.second do
      assert_equal({ guests_deleted: 1, pending_registrations_deleted: 0 }, Identity::AccountAdministration::CleanupExpiredAccounts.call)
      assert_not Identity::User.exists?(guest.id)
      assert_not Identity::Session.exists?(session.id)
      assert_not Library::LibraryFilm.exists?(user_id: guest.id)
      assert_equal 2, Library::LibraryFilm.where(film:).count
      assert Registry::Film.exists?(film.id)
    end
  end

  test "in-place registration preserves relationship identity and watched confirmation" do
    guest = Identity::UserGuest.create!
    film = Registry::Film.create!(title: "Claim retained film")
    Library::LibraryFilmWatched.create!(user: guest, film:)
    row = Library::LibraryFilm.find_by!(user_id: guest.id)
    before = [ row.id, row.created_at, row.updated_at ]
    session = claim(guest)
    assert_equal guest.id, session.user_id
    row.reload
    assert_equal before, [ row.id, row.created_at, row.updated_at ]
  end

  test "a restrictive dependent still rolls back cleanup and restores Library and Identity rows" do
    guest = Identity::UserGuest.create!(created_at: (Identity::UserGuest::EXPIRY_DURATION / 2).ago)
    film = Registry::Film.create!(title: "Rollback retention film")
    Library::LibraryFilmWatched.create!(user: guest, film:)
    session = Identity::Session.create!(user: guest)
    connection = Identity::User.connection
    connection.execute("CREATE TABLE library_cleanup_blocker (user_id bigint REFERENCES users(id))")
    connection.execute("INSERT INTO library_cleanup_blocker VALUES (#{guest.id})")
    travel Identity::UserGuest::EXPIRY_DURATION / 2 + 1.second do
      assert_raises(ActiveRecord::InvalidForeignKey) { Identity::AccountAdministration::CleanupExpiredAccounts.call }
    end
    assert Identity::User.exists?(guest.id)
    assert Identity::Session.exists?(session.id)
    assert Library::LibraryFilm.exists?(user_id: guest.id)
    assert Registry::Film.exists?(film.id)
  end

  [ [ Library::LibraryFilmToWatch, Library::CollectionManagement::RemoveFromWatchlist ],
    [ Library::LibraryFilmNotInterested, Library::CollectionManagement::RemoveNotInterested ] ].each do |model, removal|
    test "claim and cleanup preserve the existing-entry contract for #{model}" do
      freeze_time
      guest = Identity::UserGuest.create!
      film = Registry::Film.create!(title: "Intent retention")
      original = model.create!(user: guest, film:)
      claim(guest)
      expired = Identity::UserGuest.create!
      expired_entry = model.create!(user: expired, film:)
      travel Identity::UserGuest::EXPIRY_DURATION do
        assert_raises(Identity::Errors::Unavailable) { removal.call(user_id: expired.id, library_film_id: expired_entry.id) }
        assert_equal 1, Identity::AccountAdministration::CleanupExpiredAccounts.call[:guests_deleted]
        assert_not Library::LibraryFilm.exists?(expired_entry.id)
        assert Registry::Film.exists?(film.id)
        assert_equal original.created_at, Library::LibraryFilm.find(original.id).created_at
        assert_equal original.id, removal.call(user_id: guest.id, library_film_id: original.id).id
      end
    end
  end
end
