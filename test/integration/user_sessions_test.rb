require "test_helper"

class GuestSessionProbeController < ApplicationController
  self.allow_forgery_protection = true
  protect_from_forgery with: :exception

  def show
    render json: { id: current_user&.id, token: form_authenticity_token, stored_id: session[:user_id] }
  end

  def create
    render json: { id: ensure_guest_user!.id }
  end
end

class UserSessionsTest < ActionDispatch::IntegrationTest
  setup do
    Rails.application.routes.draw do
      root "home#index"
      get "/identity-probe", to: "guest_session_probe#show"
      post "/identity-probe", to: "guest_session_probe#create"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  def lookup(client = self)
    client.get "/identity-probe"
    JSON.parse(client.response.body)
  end

  def create_guest(client = self, **params)
    token = lookup(client).fetch("token")
    client.post "/identity-probe", params: params.merge(authenticity_token: token)
    JSON.parse(client.response.body)
  end

  test "scaffold visits do not create users" do
    assert_no_difference "User.count" do
      get "/"
      assert_response :success
    end
  end

  test "clients and supplied ids cannot select another guest" do
    first = create_guest["id"]
    other = open_session
    second = create_guest(other, user_id: first)["id"]
    assert_not_equal first, second
    get "/identity-probe", params: { user_id: second }
    assert_equal first, JSON.parse(response.body)["id"]
    assert_equal second, lookup(other)["id"]
    assert_equal first, create_guest["id"]
    cookies.delete(Rails.application.config.session_options.fetch(:key))
    assert_nil lookup["id"]
  end

  test "tampered cookie cannot recover a guest" do
    create_guest
    key = Rails.application.config.session_options.fetch(:key)
    cookies[key] = "tampered"
    assert_nil lookup["id"]
  end

  test "deadline is enforced between requests and replacement does not renew old guest" do
    user = freeze_time { User.find(create_guest["id"]) }
    original_time = user.created_at
    travel_to user.created_at + 24.hours - 1.second do
      assert_equal user.id, lookup["id"]
    end
    travel_to user.created_at + 24.hours do
      assert_nil lookup["id"]
      assert_nil lookup["stored_id"]
    end
    travel_to user.created_at + 24.hours + 1.second do
      assert_nil lookup["id"]
      assert_not_equal user.id, create_guest["id"]
    end
    assert_equal original_time, user.reload.created_at
  end

  test "deleted account fails explicitly across browsers without guest replacement" do
    user = User.find(create_guest["id"])
    other = open_session
    key = Rails.application.config.session_options.fetch(:key)
    other.cookies[key] = cookies[key]
    tokens = [ lookup["token"], lookup(other)["token"] ]
    user.update_column(:type, "DeletedUser")

    assert_no_difference "User.count" do
      [ self, other ].zip(tokens).each do |client, token|
        2.times do
          client.get "/identity-probe"
          assert_equal 410, client.response.status
          assert_equal "This account has been deleted.", client.response.body
          client.post "/identity-probe", params: { authenticity_token: token }
          assert_equal 410, client.response.status
          assert_equal "This account has been deleted.", client.response.body
        end
      end
    end
  end

  test "cookie has browser session protections" do
    create_guest
    header = Array(response.headers["set-cookie"]).join("\n").downcase
    assert_includes header, "httponly"
    assert_includes header, "samesite=lax"
    assert_not_includes header, "expires="
    assert_not_includes header, "max-age="
  end

  test "production SSL middleware secures the session cookie" do
    client = ActionDispatch::Integration::Session.new(ActionDispatch::SSL.new(Rails.application))
    client.https!
    create_guest(client)
    assert_match(/; secure(?:;|$)/i, Array(client.response.headers["set-cookie"]).join("\n"))
  end

  test "guest creation retains CSRF protection" do
    assert_no_difference "User.count" do
      post "/identity-probe"
      assert_response :unprocessable_entity
    end
  end
end
