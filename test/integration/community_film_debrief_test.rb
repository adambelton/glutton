require "test_helper"

class CommunityFilmDebriefTest < ActionDispatch::IntegrationTest
  PASSWORD = "a long test password"

  setup do
    controllers = [ Community::FilmDebriefsController, Community::BoardController, LibraryController ]
    @previous_forgery_protection = controllers.index_with(&:allow_forgery_protection)
    controllers.each { |controller| controller.allow_forgery_protection = true }
    @member = member("debrief_reader")
  end

  teardown do
    @previous_forgery_protection.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  test "a Watched-film placeholder opens one system-owned thread which survives account closure" do
    film = create_film("The Quiet House")
    watch(@member, film)
    sign_in(@member)
    path = community_film_debrief_path(film)

    assert_no_difference "Community::Post.count" do
      get community_path
      assert_select ".community-film-debrief-card", count: 0
      get community_path(q: "quiet")
      assert_select "article.community-film-debrief-card h2", text: film.title
    end
    token = form_token(path)
    assert_difference "Community::PostFilmDebrief.count", 1 do
      assert_no_difference "Community::Comment.count" do
        post path, params: { authenticity_token: token }
      end
    end
    assert_response :see_other
    assert_redirected_to path
    follow_redirect!
    assert_select "h1", text: film.title
    assert_select ".community-post-tag[tabindex='0'] [role=tooltip]", text: I18n.t("community.film_debriefs.badge_tooltip")
    assert_select "p", text: I18n.t("community.film_debriefs.introduction", title: film.title)

    debrief = Community::PostFilmDebrief.find_by!(film:)
    assert_nil debrief.author_id
    assert_nil debrief.deletable_author_id
    assert_no_changes -> { debrief.reload.updated_at } do
      assert_no_difference "Community::PostFilmDebrief.count" do
        post path, params: { authenticity_token: token }
      end
    end
    assert_redirected_to path

    client = Aws::S3::Client.new(region: "auto", stub_responses: true)
    log = Identity::AccountAdministration::DeletionLog.new(client:, bucket: "fixture", namespace: "recovery")
    Identity::AccountAdministration::ManageRegisteredAccount.new(user_id: @member.id).close_account(deletion_log: log)
    assert Community::PostFilmDebrief.exists?(debrief.id)
  end

  test "a stale placeholder, Watchlist entry, and ineligible member cannot open a debrief" do
    film = create_film("Night House")
    library_film = watch(@member, film)
    path = community_film_debrief_path(film)
    sign_in(@member)
    get community_path(q: "Night")
    token = form_token(path)
    library_film.move_to_watchlist!

    assert_no_difference "Community::PostFilmDebrief.count" do
      post path, params: { authenticity_token: token }
      assert_response :not_found
      get community_path(q: "Night")
      assert_select ".community-film-debrief-card", count: 0

      reader = member("debrief_no_conduct", accepted: false)
      watch(reader, film)
      sign_in(reader)
      get community_path(q: "Night")
      assert_select "article.community-film-debrief-card h2", text: film.title
      assert_select "form[action=?]", path, count: 0
      post path, params: { authenticity_token: page_token }
      assert_response :forbidden

      outsider = member("debrief_no_preview", superuser: false)
      watch(outsider, film)
      sign_in(outsider)
      get library_path
      post path, params: { authenticity_token: page_token }
      assert_response :forbidden
    end
  end

  test "published debriefs require Watched and preview access even at the direct URL" do
    film = create_film("The Night")
    library_film = watch(@member, film)
    debrief = Community::OpenFilmDebrief.call(member_id: @member.id, film_id: film.id)
    path = community_film_debrief_path(film)
    sign_in(@member)
    get path
    assert_response :success

    library_film.remove_from_watched!
    get path
    assert_response :not_found
    get community_path
    assert_select ".community-film-debrief-card", count: 0

    outsider = member("debrief_outsider", superuser: false)
    watch(outsider, film)
    sign_in(outsider)
    get path
    assert_response :forbidden
    assert Community::PostFilmDebrief.exists?(debrief.id)
  end

  test "the board interleaves published posts and pages search groups in their agreed order" do
    old = 3.days.ago
    recent = 1.day.ago
    newest_curation = create_curation("House Curation New", updated_at: 1.hour.ago)
    second_curation = create_curation("House Curation Old", updated_at: old)
    external_film = create_film("House Outside the Library")
    create_curation("Matching by endorsement", updated_at: recent, film: external_film)

    old_film = create_film("House Debrief Old")
    new_film = create_film("House Debrief New")
    [ old_film, new_film ].each { |film| watch(@member, film) }
    Community::PostFilmDebrief.create!(film: old_film, updated_at: old)
    Community::PostFilmDebrief.create!(film: new_film, updated_at: recent)
    Community::PostFilmDebrief.create!(film: external_film, updated_at: 1.minute.ago)
    placeholders = 9.times.map do |index|
      create_film("House Placeholder #{index + 1}").tap { |film| watch(@member, film) }
    end
    sign_in(@member)

    get community_path
    assert_equal [ newest_curation.title, new_film.title, "Matching by endorsement", old_film.title, second_curation.title ], board_titles

    get community_path(q: "House")
    assert_equal placeholders.map(&:title) + [ new_film.title ], board_titles
    assert_select "a[rel=next][href=?]", community_path(q: "House", page: 2)

    get community_path(q: "House", page: 2)
    assert_equal [ old_film.title, newest_curation.title, "Matching by endorsement", second_curation.title ], board_titles
    assert_select "a[rel=prev][href=?]", community_path(q: "House")
  end

  private

  def member(name, accepted: true, superuser: true)
    Identity::UserRegistered.create!(email_address: "#{name}@example.test", password: PASSWORD,
      password_confirmation: PASSWORD, email_confirmed_at: Time.current, superuser:,
      community_username: name, community_avatar_preset: "moth",
      community_code_of_conduct_version: (Community::CodeOfConduct.current.version if accepted),
      community_code_of_conduct_accepted_at: (Time.current if accepted))
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def create_film(title)
    Registry::Film.create!(title:, tmdb_metadata: { details: { genres: [ { name: "Horror" } ] } })
  end

  def watch(user, film)
    Library::LibraryFilm.new(user:, film:).add_to_watched!
  end

  def create_curation(title, updated_at:, film: nil)
    travel_to(updated_at) do
      watch(@member, film) if film.present?
      Community::PublishCuration.call(author_id: @member.id, title:, prompt: "A specific subgenre.",
        reference_film_ids: (film.present? ? [ film.id ] : []), reference_comments: {})
    end
  ensure
    Library::LibraryFilm.find_by!(user: @member, film:).remove_from_watched! if film.present?
  end

  def form_token(path)
    Nokogiri::HTML(response.body).at_css("form[action='#{path}'] input[name=authenticity_token]")["value"]
  end

  def page_token
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def board_titles
    Nokogiri::HTML(response.body).css(".community-post-grid > li h2").map(&:text)
  end
end
