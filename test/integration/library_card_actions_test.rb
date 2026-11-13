require "test_helper"

class LibraryCardActionsTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = LibraryController.allow_forgery_protection
    LibraryController.allow_forgery_protection = true
    @user = Identity::UserGuest.create!
    @film = Registry::Film.create!(title: "A <script>film</script>", release_date: Date.new(2001, 1, 1))
    @entry = Library::LibraryFilm.create!(user: @user, film: @film)
    bind_user
  end

  teardown do
    LibraryController.allow_forgery_protection = @forgery
  end

  def bind_user
    @authentication = Identity::Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: @authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def token
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def watch(**params)
    post move_to_watched_library_film_path(@entry), params: { authenticity_token: token }.merge(params)
  end

  test "Watchlist cards expose actions directly and escape film information" do
    get library_path
    assert_response :success
    assert_select ".library-films h3", text: "#{@film.title} (2001)"
    assert_select ".library-films a h3", count: 0
    assert_select "form[action=?] button[aria-label=?]", move_to_watched_library_film_path(@entry), "Mark #{@film.title} watched"
    assert_select "form[action=?] button[aria-label=?]", remove_from_watchlist_library_film_path(@entry), "Remove #{@film.title} from watchlist"
    assert_select "a[href=?][aria-label=?]", new_rating_path(film_id: @film.id), "Rate #{@film.title}", count: 0
    assert_select "script", text: "film", count: 0
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
    assert_no_match(/translation missing/i, response.body)
  end

  test "mark watched retains relationship and redirects to Watched before event delivery" do
    get library_path
    original_id, original_created_at = @entry.id, @entry.created_at
    other = Identity::UserGuest.create!
    assert_difference "DomainEvents::DomainEvent.count", 1 do
      assert_no_difference [ "Library::LibraryFilm.count", "Ratings::RatingFilm.count", "Ratings::Rating.count" ] do
        watch(user_id: other.id, film_id: Registry::Film.create!(title: "Ignore").id, watched: false)
      end
    end
    assert_redirected_to library_path(view: "watched")
    assert_response :see_other
    row = Library::LibraryFilm.find(original_id)
    assert_equal original_created_at, row.created_at
    assert_equal @user.id, row.user_id
    event = DomainEvents::DomainEvent.joins(:domain_event_stream).find_by!(domain_event_streams: { user_id: @user.id }, name: Library::Events::FILM_MARKED_WATCHED)
    assert_equal @film.id, event.payload.fetch("film_id")
    follow_redirect!
    assert_select '[role="status"]', I18n.t("library.detail.watched")
    assert_select "form[action=?]", move_to_watchlist_library_film_path(@entry)
    assert_select "form[action=?]", remove_from_watched_library_film_path(@entry)
    assert_select "a[href=?]", new_rating_path(film_id: @film.id)
    assert_no_difference "DomainEvents::DomainEvent.count" do
      watch
      assert_response :conflict
    end
    get new_rating_path(film_id: @film.id)
    assert_response :success
    assert_select "h2", "#{@film.title} (2001)"
  end

  test "rated films can move and leave Library with their ratings intact" do
    Library::CollectionManagement::MoveWatchlistToWatched.call(user_id: @user.id, library_film_id: @entry.id)
    candidate = Ratings::RatingFilm.create!(user: @user, film: @film)
    rating = candidate.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, notes: "Keep these notes")
    DomainEvents::Delivery::Dispatch.call
    get library_path(view: "watched")
    assert_select "a[href=?][data-tooltip=?]", edit_rating_path(film_id: @film.id), "Edit rating · Brilliant"
    csrf = token

    post move_to_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
    assert_redirected_to library_path
    assert_not @entry.reload.watched?
    DomainEvents::Delivery::Dispatch.call
    assert candidate.reload.suppressed?
    delete remove_from_watched_library_film_path(@entry), params: { authenticity_token: csrf }
    assert_response :conflict

    post move_to_watched_library_film_path(@entry), params: { authenticity_token: csrf }
    DomainEvents::Delivery::Dispatch.call
    assert_not candidate.reload.suppressed?
    delete remove_from_watched_library_film_path(@entry), params: { authenticity_token: csrf }
    assert_redirected_to library_path(view: "watched")
    assert_not Library::LibraryFilm.exists?(@entry.id)
    DomainEvents::Delivery::Dispatch.call
    assert candidate.reload.suppressed?
    assert_equal "Keep these notes", rating.reload.notes
  end

  test "registered owner removes entry and stale actions cannot recreate or target its replacement" do
    @user = Identity::UserRegistered.create!(email_address: "details@example.test", password: "long test password", password_confirmation: "long test password", email_confirmed_at: Time.current)
    @entry = Library::LibraryFilm.create!(user: @user, film: @film)
    bind_user
    get library_path
    csrf = token
    assert_difference "Library::LibraryFilm.count", -1 do
      assert_difference "DomainEvents::DomainEvent.count", 1 do
        delete remove_from_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      end
    end
    assert_response :see_other
    assert_redirected_to library_path
    follow_redirect!
    assert_select '[role="status"]', I18n.t("library.detail.removed")
    replacement = Library::LibraryFilm.create!(user: @user, film: @film)
    assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
      post move_to_watched_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :not_found
      delete remove_from_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :not_found
    end
    assert replacement.reload.can_move_to_watched?
  end

  test "invalid foreign and removed IDs are unavailable and unsupported actions conflict" do
    get library_path
    csrf = token
    foreign = Library::LibraryFilm.create!(user: Identity::UserGuest.create!, film: @film)
    [ "0", "-1", "invalid", "999999999", foreign.id ].each do |id|
      post move_to_watched_library_film_path(id), params: { authenticity_token: csrf }
      assert_response :not_found
    end
    Library::CollectionManagement::MoveWatchlistToWatched.call(user_id: @user.id, library_film_id: @entry.id)
    assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
      delete remove_from_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :conflict
    end
  end

  test "csrf and unavailable sessions protect writes without creating replacement identities" do
    get library_path
    csrf = token
    assert_no_difference [ "Library::LibraryFilm.count", "Ratings::RatingFilm.count", "DomainEvents::DomainEvent.count", "Identity::User.count" ] do
      post move_to_watched_library_film_path(@entry)
      assert_response :unprocessable_entity
      delete remove_from_watchlist_library_film_path(@entry)
      assert_response :unprocessable_entity
      travel Identity::UserGuest::EXPIRY_DURATION + 1.second do
        post move_to_watched_library_film_path(@entry), params: { authenticity_token: csrf }
        assert_response :unauthorized
        get library_path
        assert_redirected_to new_session_path
      end
      bind_user
      Identity::Session.revoke(id: @authentication.id)
      get library_path
      assert_redirected_to new_session_path
      bind_user
      # Existing cookie with a deleted owner is a storage fixture for the unimplemented deletion transition.
      @user.update_columns(type: "UserDeleted")
      get library_path
      assert_response :gone
    end
  end
end
