require "test_helper"

class ScaffoldTest < ActionDispatch::IntegrationTest
  test "home renders the Glutton page with Hotwire assets" do
    get root_path

    assert_response :success
    assert_select "h1", "Glutton"
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
    assert_equal "glutton_test", connection.select_value("SELECT current_database()")
    assert_equal 1, connection.select_value("SELECT 1")
  end
end
