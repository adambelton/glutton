require "test_helper"

class AdminNavigationTest < ActionDispatch::IntegrationTest
  test "current superusers can open Admin and navigate its tools" do
    operator = create_user("operator", superuser: true)
    sign_in(operator)

    get admin_path
    assert_redirected_to admin_users_path
    follow_redirect!
    assert_equal "no-store", response.headers.fetch("Cache-Control")
    assert_select "body.admin-page > main.admin-content h1.sr-only", "Users"
    assert_select "form.admin-search input[placeholder=?][aria-label=?]", "Search by user ID or email address", "Search by user ID or email address"
    assert_select "form.admin-search label", count: 0
    assert_select "body.admin-page > aside.admin-sidebar .admin-navigation" do
      assert_select "a[aria-current=location][href=?]", admin_users_path, text: "Users"
      assert_select "a[href=?]", admin_films_path, text: "Films"
      assert_select "a[href=?]", admin_qualities_path, text: "Qualities"
      assert_select "a[href=?]", admin_quality_categories_path, text: "Quality categories"
      assert_select "a", count: 4
      assert_select "a[href=?]", account_taste_profile_path, count: 0
      assert_select "a", text: /\A(?:Admin|Registry|Identity)\z/, count: 0
    end
    assert_select "header.ui-header, .ui-card", count: 0
    assert_select ".admin-sidebar > a.admin-wordmark:first-child[href=?]", library_path
    assert_equal [ "/admin/users", "/admin/films", "/admin/qualities", "/admin/quality-categories" ],
      [ admin_users_path, admin_films_path, admin_qualities_path, admin_quality_categories_path ]

    [ admin_films_path, admin_qualities_path, admin_quality_categories_path ].each do |path|
      get path
      assert_response :success
      assert_select "main h1.sr-only", count: 1
      assert_select "main h2", count: 0
      assert_select ".admin-navigation a[href=?][aria-current=location]", path
    end

    get glutton_profile_admin_user_path(operator.id)
    assert_select ".admin-navigation a[href=?][aria-current=location]", admin_users_path
    assert_select "body.admin-page > main.admin-content"

    Identity::AccountAdministration::RevokeSuperuser.call(user_id: operator.id, actor_user_id: operator.id)
    get admin_path
    assert_response :forbidden
    get library_path
    assert_admin_navigation_hidden
  end

  test "signed-out visitors and non-superusers cannot open Admin" do
    get admin_path
    assert_redirected_to new_session_path

    [ Identity::UserGuest.create!, create_user("viewer") ].each do |viewer|
      sign_in(viewer)
      get admin_path
      assert_response :forbidden
      get library_path
      assert_admin_navigation_hidden
    end
  end

  private

  def assert_admin_navigation_hidden
    assert_select "header nav a[href=?]", admin_path, count: 0
    assert_select "header select option[value=?]", admin_path, count: 0
  end

  def create_user(name, superuser: false)
    password = "a long test password"
    Identity::UserRegistered.create!(email_address: "#{name}@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser:)
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: authentication.user_id } }
    cookies[:session_id] = jar[:session_id]
  end
end
