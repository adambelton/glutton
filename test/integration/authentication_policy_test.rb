require "test_helper"

class AuthenticationPolicyProbeController < ApplicationController
  allow_unauthenticated_access only: :public_page

  def public_page
    head :ok
  end

  def private_page
    head :ok
  end
end

class AuthenticationDefaultProbeController < ApplicationController
  def show
    head :ok
  end
end

class AuthenticationPolicyTest < ActionDispatch::IntegrationTest
  setup do
    Rails.application.routes.draw do
      resource :session, only: :new
      get "/policy/public", to: "authentication_policy_probe#public_page"
      get "/policy/private", to: "authentication_policy_probe#private_page"
      get "/default-protected", to: "authentication_default_probe#show"
      post "/default-protected", to: "authentication_default_probe#show"
    end
  end

  teardown { Rails.application.reload_routes! }

  test "new controllers and undeclared actions require identity without route flags" do
    assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
      [ "/policy/private", "/default-protected" ].each do |path|
        get path, params: { identity_required: false }
        assert_redirected_to new_session_path
      end
      post "/default-protected"
      assert_response :unauthorized
    end
  end

  test "public exemption is action-specific and used by safe continuation" do
    get "/policy/public"
    assert_response :success
    assert_nil Identity::ReturnDestination.capture("/policy/public")
    destination = Identity::ReturnDestination.capture("/policy/private")
    assert_equal "/policy/private", Identity::ReturnDestination.resolve(destination)
    get "/policy/private"
    assert_redirected_to new_session_path
  end
end
