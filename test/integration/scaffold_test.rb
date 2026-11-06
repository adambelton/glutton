require "test_helper"

class ScaffoldTest < ActionDispatch::IntegrationTest
  test "root renders the anonymous preview with Hotwire assets" do
    get root_path

    assert_response :success
    assert_select "h1", I18n.t("identity.entry.title")
    assert_select 'html[lang="en"]'
    assert_select "main#main-content"
    assert_select "a.wordmark", "glutton."
    assert_select 'button[data-controller="theme"][aria-pressed="false"][aria-label=?]', I18n.t("ui.dark_mode")
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
    assert_no_match(/translation missing/i, response.body)
    assert_select "script[type=importmap]", count: 1
    assert_includes response.body, "@hotwired/turbo-rails"
    assert_includes response.body, "@hotwired/stimulus"
  end

  test "Rails health endpoint succeeds" do
    get rails_health_check_path

    assert_response :success
  end

  test "test database is PostgreSQL and isolated from development" do
    connection = ActiveRecord::Base.connection

    assert_equal "PostgreSQL", connection.adapter_name
    assert_match /\Aglutton_test(?:_\d+)?\z/, connection.select_value("SELECT current_database()")
    assert_equal 1, connection.select_value("SELECT 1")
  end
end
