require "test_helper"

class LibraryBrowserTest < ActionDispatch::IntegrationTest
  setup do
    @user = UserGuest.create!
    bind_user
  end

  def bind_user
    @authentication = Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: @authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def entry(model = LibraryFilmWatched, user: @user, title: "A film", **attributes)
    model.create!(user:, film: Film.create!(title:, **attributes))
  end

  test "three views isolate membership and owner and default to watchlist without writes" do
    watchlist = entry(LibraryFilmToWatch, title: "Watchlist film")
    watched = entry(title: "Watched film")
    uninterested = entry(LibraryFilmNotInterested, title: "Not interested film")
    entry(user: UserGuest.create!, title: "Private film")
    assert_no_difference [ "LibraryFilm.count", "RatingFilm.count", "Rating.count", "DomainEvent.count", "User.count", "Session.count" ] do
      get library_path(user_id: UserGuest.last.id)
      assert_response :success
      assert_select "h3", text: watchlist.film.title, count: 1
      assert_select "h3", count: 1
      assert_select 'option[selected][value="watchlist"]'
      { Library::Browse::Views::WATCHED => watched, Library::Browse::Views::NOT_INTERESTED => uninterested }.each do |view, row|
        get library_path(view:)
        assert_select "h3", text: row.film.title, count: 1
        assert_select "h3", count: 1
        assert_select "option[selected][value=?]", view
      end
      assert_select 'a[href*="rating/new"]', count: 0
    end
  end

  test "only same-owner actual ratings count and committed ratings are visible without delivery" do
    rows = 5.times.map { |i| entry(title: "Film #{i}") }
    rows.drop(1).zip([ [ false, false ], [ true, false ], [ false, true ], [ true, true ] ]).each do |row, (held, dismissed)|
      RatingFilm.create!(user: @user, film: row.film, held:, dismissed:)
    end
    foreign = RatingFilm.create!(user: UserGuest.create!, film: rows.first.film)
    foreign.submit_rating!(value: Rating::Values::BRILLIANT)
    get library_path(view: Library::Browse::Views::WATCHED)
    assert_select "p", text: "Awaiting rating", count: 5
    assert_select 'a[href*="rating/new"]', count: 5
    row = RatingFilm.find_by!(user: @user, film: rows.last.film)
    Ratings::SubmitRating.call(user_id: @user.id, rating_film_id: row.id, value: Rating::Values::BRILLIANT)
    absent = RatingFilm.create!(user: @user, film: Film.create!(title: "Not in Library"))
    absent.submit_rating!(value: Rating::Values::BRILLIANT)
    get library_path(view: Library::Browse::Views::WATCHED)
    assert_select "p", text: "Rated", count: 1
    assert_select "p", text: "Awaiting rating", count: 4
    assert_select "h3", count: 5
    assert_select "a[href=?]", new_rating_path(film_id: rows.last.film_id), count: 0
  end

  test "links admit missing candidates reuse held dismissed candidates and reject stale rated links" do
    [ nil, [ true, false ], [ false, true ], [ true, true ] ].each do |flags|
      row = entry
      candidate = RatingFilm.create!(user: @user, film: row.film, held: flags.first, dismissed: flags.last) if flags
      get library_path(view: Library::Browse::Views::WATCHED)
      link = Nokogiri::HTML(response.body).at_css("a[href='#{new_rating_path(film_id: row.film_id)}']")["href"]
      assert_difference "RatingFilm.count", flags ? 0 : 1 do
        get link
        assert_response :success
      end
      candidate ||= RatingFilm.find_by!(user: @user, film: row.film)
      assert_select 'input[name="rating_film_id"][value=?]', candidate.id.to_s
      post rating_path, params: { rating_film_id: candidate.id, value: Rating::Values::I_ENJOYED_THAT }
      assert_response :see_other
      get library_path(view: Library::Browse::Views::WATCHED)
      assert_select "a[href=?]", link, count: 0
      get link
      assert_response :conflict
    end
  end

  test "pagination is bounded stable and preserves view while dropdown resets page" do
    freeze_time do
      rows = 27.times.map { |i| entry(title: "Film #{i}") }
      get library_path(view: Library::Browse::Views::WATCHED)
      assert_select "h3", count: 25
      assert_equal rows.reverse.first(25).map { |row| row.film.title }, Nokogiri::HTML(response.body).css("h3").map(&:text)
      assert_select "a[href=?]", library_path(view: Library::Browse::Views::WATCHED, page: 2)
      get library_path(view: Library::Browse::Views::WATCHED, page: 2)
      assert_select "h3", count: 2
      assert_select "a[href=?]", library_path(view: Library::Browse::Views::WATCHED, page: 1)
      assert_select "a", text: "Next", count: 0
      assert_select "form[action=?][method=get]", library_path do
        assert_select '[name="page"]', count: 0
        assert_select 'label[for="view"]'
        assert_select 'select[data-action="change->library-view#change"]'
        assert_select 'input[type="submit"], button', count: 0
      end
      get library_path(view: Library::Browse::Views::WATCHED, page: 3)
      assert_select "h3", count: 0
      assert_select "p", "No watched films on this page."
    end
  end

  test "invalid URL parameters fail explicitly" do
    [ "", "watched", "0", "-1", "1.5", "1000000000", [ "1" ], { number: "1" } ].each do |page|
      get library_path, params: { page: }
      assert_response :bad_request
    end
    [ "LibraryFilmWatched", "", [ "watched" ], { name: "watched" } ].each do |view|
      get library_path, params: { view: }
      assert_response :bad_request
    end
  end

  test "titles are escaped dates optional and page is private" do
    entry(title: "<script>alert('film')</script>", release_date: Date.new(2001, 1, 1))
    entry(title: "No release date")
    get library_path(view: Library::Browse::Views::WATCHED)
    assert_select "h3", text: "<script>alert('film')</script>"
    assert_select "script", text: /alert\('film'\)/, count: 0
    assert_select "p", text: "Released in 2001", count: 1
    assert_select 'nav[aria-label="Library pages"]'
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
    assert_no_match(/translation missing/i, response.body)
  end

  test "registered access and signed out revoked expired deleted identity outcomes" do
    @user = UserRegistered.create!(email_address: "library@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    bind_user
    get library_path
    assert_response :success
    Session.revoke(id: @authentication.id)
    get library_path
    assert_response :unauthorized
    assert_select "a[href=?]", new_session_path
    assert_select "a[href=?]", new_registration_path
    cookies.delete(:session_id)
    assert_no_difference [ "User.count", "Session.count" ] do
      get library_path
      assert_response :unauthorized
    end
    @user = UserGuest.create!
    bind_user
    travel UserGuest::EXPIRY_DURATION + 1.second do
      get library_path
      assert_response :unauthorized
    end
    bind_user
    @user.becomes!(UserDeleted).save!
    get library_path
    assert_response :gone
  end
  test "edit links expose latest owner evidence on both surfaces without writes" do
    [ @user, UserRegistered.create!(email_address: "edit-library@example.test",
      password: "long test password", password_confirmation: "long test password",
      email_confirmed_at: Time.current) ].each do |user|
      @user = user
      bind_user
      watched = entry(title: '<script>film</script> "title"')
      unrated = entry
      candidate = RatingFilm.create!(user:, film: watched.film, held: true, dismissed: true)
      original = candidate.submit_rating!(value: Rating::Values::BRILLIANT, expression_texts: [ "Original" ])
      current = Ratings::ReviseRating.call(user_id: user.id, rating_film_id: candidate.id,
        previous_rating_id: original.id, value: Rating::Values::I_ENJOYED_THAT, expression_texts: [ "Current" ])
      edit_link = edit_rating_path(film_id: watched.film_id)
      assert_no_difference [ "LibraryFilm.count", "RatingFilm.count", "Rating.count", "RatingExpression.count", "DomainEvent.count" ] do
        [ library_path(view: Library::Browse::Views::WATCHED), library_film_path(watched) ].each do |path|
          get path
          assert_response :success
          assert_select "a[href=?]", edit_link, text: "Edit rating", count: 1 do
            assert_select "[aria-label=?]", "Edit your rating for #{watched.film.title}"
          end
          assert_select "script", text: "film", count: 0
          assert_equal "no-store", response.headers["Cache-Control"]
          assert_no_match(/translation missing/i, response.body)
          assert_select "a[href=?]", new_rating_path(film_id: watched.film_id), count: 0
        end
        get library_film_path(unrated)
        assert_select "a[href=?]", new_rating_path(film_id: unrated.film_id)
        assert_select 'a[href*="rating/edit"]', count: 0
      end
      get edit_link
      assert_response :success
      assert_select 'input[name="previous_rating_id"][value=?]', current.id.to_s
      assert_select "textarea", text: "Current"
      patch rating_path, params: { rating_film_id: candidate.id, previous_rating_id: current.id,
        value: Rating::Values::BRILLIANT, expression_texts: [ "Updated from Library" ] }
      assert_response :see_other
      get library_film_path(watched)
      get Nokogiri::HTML(response.body).at_css("a[href='#{edit_link}']")["href"]
      assert_response :success
      assert_select "textarea", text: "Updated from Library"
      assert_select 'input[name="previous_rating_id"][value=?]', candidate.ratings.order(:id).last.id.to_s
      assert_equal [ "Original" ], original.rating_expressions.pluck(:text)
    end
  end

  test "unwatched library pages do not offer editing even when ratings exist" do
    { Library::Browse::Views::WATCHLIST => LibraryFilmToWatch,
      Library::Browse::Views::NOT_INTERESTED => LibraryFilmNotInterested }.each do |view, model|
      row = entry(model)
      RatingFilm.create!(user: @user, film: row.film).submit_rating!(value: Rating::Values::BRILLIANT)
      [ library_path(view:), library_film_path(row) ].each do |path|
        get path
        assert_response :success
        assert_select 'a[href*="rating/edit"]', count: 0
      end
    end
  end
end
