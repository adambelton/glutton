require "test_helper"

class LibraryDismissalActionsTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = LibraryController.allow_forgery_protection
    LibraryController.allow_forgery_protection = true
    @user = UserGuest.create!
    @film = Film.create!(title: "Intent <film>")
    @entry = LibraryFilmToWatch.create!(user: @user, film: @film)
    bind_user
  end

  teardown do
    LibraryController.allow_forgery_protection = @forgery
  end

  def bind_user
    @authentication = Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: @authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def token
    get library_film_path(@entry)
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def dismiss
    post mark_not_interested_library_film_path(@entry), params: { authenticity_token: token }
  end

  test "guest and registered users can dismiss and reconsider without changing relationship identity" do
    [ @user, UserRegistered.create!(email_address: "intent@example.test", password: "long test password", password_confirmation: "long test password", email_confirmed_at: Time.current) ].each do |user|
      @user = user
      @entry = LibraryFilmToWatch.find_or_create_by!(user: @user, film: @film)
      created_at = @entry.created_at
      bind_user
      get library_film_path(@entry)
      assert_select "form[action=?]", mark_not_interested_library_film_path(@entry)
      assert_select "form[action=?]", remove_from_watchlist_library_film_path(@entry)
      assert_select "form[action=?]", add_to_watchlist_library_film_path(@entry), count: 0
      assert_difference "DomainEvent.count", 1 do
        assert_no_difference([ "LibraryFilm.count", "RatingFilm.count", "Rating.count" ]) { dismiss }
      end
      assert_response :see_other
      assert_redirected_to library_film_path(@entry)
      follow_redirect!
      assert_select '[role="status"]', I18n.t("library.detail.dismissed")
      assert_select "form[action=?]", mark_not_interested_library_film_path(@entry), count: 0
      assert_select "form[action=?]", mark_watched_library_film_path(@entry), count: 0
      assert_select "form[action=?]", add_to_watchlist_library_film_path(@entry)
      assert_select "form[action=?]", remove_from_not_interested_library_film_path(@entry)
      assert_equal created_at, LibraryFilm.find(@entry.id).created_at
      assert_difference "DomainEvent.count", 1 do
        post add_to_watchlist_library_film_path(@entry), params: { authenticity_token: token, user_id: -1, film_id: -1, type: "LibraryFilmWatched" }
      end
      assert_redirected_to library_film_path(@entry)
      follow_redirect!
      assert_select '[role="status"]', I18n.t("library.detail.watchlisted")
      assert_select "form[action=?]", mark_watched_library_film_path(@entry)
      assert_equal created_at, LibraryFilm.find(@entry.id).created_at
      assert_equal [ Library::Events::FILM_MARKED_NOT_INTERESTED, Library::Events::FILM_ADDED_TO_WATCHLIST ].sort,
        DomainEvent.joins(:domain_event_stream).where(domain_event_streams: { user_id: @user.id }).pluck(:name).sort
    end
  end

  test "remove from not interested preserves Ratings evidence and old IDs cannot affect replacement rows" do
    dismiss
    rating_film = RatingFilm.create!(user: @user, film: @film, held: true, dismissed: true)
    csrf = token
    assert_difference "LibraryFilm.count", -1 do
      assert_difference "DomainEvent.count", 1 do
        delete remove_from_not_interested_library_film_path(@entry), params: { authenticity_token: csrf }
      end
    end
    assert_redirected_to library_path(view: Library::Browse::Views::NOT_INTERESTED)
    follow_redirect!
    assert_select '[role="status"]', I18n.t("library.detail.removed_from_not_interested")
    assert rating_film.reload.held?
    assert rating_film.dismissed?
    replacement = LibraryFilmNotInterested.create!(user: @user, film: @film)
    assert_no_difference [ "LibraryFilm.count", "DomainEvent.count" ] do
      get library_film_path(@entry)
      assert_response :not_found
      post add_to_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :not_found
      post mark_not_interested_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :not_found
      delete remove_from_not_interested_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :not_found
    end
    assert replacement.reload.can_remove_from_not_interested?
  end

  test "unsupported actions fail explicitly including repeats and watched entries" do
    csrf = token
    assert_no_difference "DomainEvent.count" do
      post add_to_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :conflict
      delete remove_from_not_interested_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :conflict
    end
    dismiss
    assert_no_difference "DomainEvent.count" do
      dismiss
      assert_response :conflict
    end
    post add_to_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
    Library::RecordWatched.call(user_id: @user.id, library_film_id: @entry.id)
    get library_film_path(@entry)
    assert_select "form", count: 0
    assert_select "p", "Awaiting rating"
    assert_no_difference "DomainEvent.count" do
      post mark_not_interested_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :conflict
      post add_to_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :conflict
      delete remove_from_not_interested_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :conflict
    end
  end

  test "new actions reject foreign and malformed IDs and require CSRF and active identity" do
    csrf = token
    foreign = LibraryFilmNotInterested.create!(user: UserGuest.create!, film: @film)
    actions = [ [ :post, :mark_not_interested_library_film_path ], [ :post, :add_to_watchlist_library_film_path ], [ :delete, :remove_from_not_interested_library_film_path ] ]
    assert_no_difference [ "LibraryFilm.count", "DomainEvent.count", "User.count" ] do
      actions.each do |verb, helper|
        [ foreign.id, "invalid", "0", "999999999" ].each do |id|
          public_send(verb, public_send(helper, id), params: { authenticity_token: csrf })
          assert_response :not_found
        end
        public_send(verb, public_send(helper, @entry))
        assert_response :unprocessable_entity
      end
      @user.update!(created_at: 25.hours.ago)
      actions.each do |verb, helper|
        public_send(verb, public_send(helper, @entry), params: { authenticity_token: csrf })
        assert_response :unauthorized
      end
      @user.update!(created_at: Time.current)
      bind_user
      Session.revoke(id: @authentication.id)
      post add_to_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :unauthorized
      bind_user
      @user.becomes!(UserDeleted).save!
      delete remove_from_not_interested_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :gone
    end
  end
end
