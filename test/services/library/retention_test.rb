require "test_helper"

class Library::RetentionTest < ActiveSupport::TestCase
  def claim(guest)
    pending = Identity::PrepareRegistration.call(email_address: "library-claim@example.test", guest_user_id: guest.id,
      password: "a long password phrase", password_confirmation: "a long password phrase")
    token = Identity::RegistrationConfirmation.token_for(pending_registration_id: pending.id)
    Identity::CompleteRegistration.call(token:)
  end

  test "cleanup deletes only expired guest relationships and preserves shared films and other owners" do
    guest = UserGuest.create!(created_at: 23.hours.ago)
    active = UserGuest.create!
    registered = UserRegistered.create!(email_address: "library-keep@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    film = Film.create!(title: "Shared Library film")
    [ guest, active, registered ].each { |user| Library::RecordWatched.call(user:, film:) }
    session = Session.create!(user: guest)
    travel 2.hours do
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
    Library::RecordWatched.call(user: guest, film:)
    row = LibraryFilm.find_by!(user_id: guest.id)
    before = [ row.id, row.created_at, row.updated_at ]
    session = claim(guest)
    assert_equal guest.id, session.user_id
    row.reload
    assert_equal before, [ row.id, row.created_at, row.updated_at ]
  end

  test "a restrictive dependent still rolls back cleanup and restores Library and Identity rows" do
    guest = UserGuest.create!(created_at: 23.hours.ago)
    film = Film.create!(title: "Rollback retention film")
    Library::RecordWatched.call(user: guest, film:)
    session = Session.create!(user: guest)
    connection = User.connection
    connection.execute("CREATE TABLE library_cleanup_blocker (user_id bigint REFERENCES users(id))")
    connection.execute("INSERT INTO library_cleanup_blocker VALUES (#{guest.id})")
    travel 2.hours do
      assert_raises(ActiveRecord::InvalidForeignKey) { Identity::CleanupExpiredAccounts.call }
    end
    assert User.exists?(guest.id)
    assert Session.exists?(session.id)
    assert LibraryFilm.exists?(user_id: guest.id)
    assert Film.exists?(film.id)
  end
end
