require "test_helper"
require "active_support/testing/constant_stubbing"

class CommunityCodeOfConductTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::ConstantStubbing

  PASSWORD = "a long test password"

  setup do
    controllers = [ Community::OnboardingController, Community::CodeOfConductController, AccountSettingsController ]
    @forgery_protection = controllers.index_with(&:allow_forgery_protection)
    controllers.each { |controller| controller.allow_forgery_protection = true }
    @member = confirmed_member("conduct@example.test", superuser: true)
  end

  teardown do
    @forgery_protection.each { |controller, enabled| controller.allow_forgery_protection = enabled }
  end

  test "the current and versioned code are readable without an account" do
    [ community_code_of_conduct_path, community_code_of_conduct_path(version: "1") ].each do |path|
      get path
      assert_response :success
      assert_select "h1", I18n.t("community.conduct.title")
      assert_select "p", I18n.t("community.conduct.version", version: "1")
      assert_select "a[href='mailto:#{I18n.t("community.code_of_conduct_v1.copyright.email")}']"
    end
    get community_code_of_conduct_path(version: "unknown")
    assert_response :not_found
  end

  test "acceptance from Account belongs to the signed-in member and appears in Community" do
    other = confirmed_member("other-conduct@example.test")
    sign_in(@member)
    get account_community_path
    assert_response :success
    assert_select "input#community_username"
    assert_select "a[href=?]", community_code_of_conduct_path(version: "1"), text: I18n.t("community.conduct.read")

    travel_to Time.zone.local(2026, 11, 21, 12) do
      assert_difference -> { Community::CodeOfConductAcceptance.count }, 1 do
        post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1", user_id: other.id)
      end
      assert_redirected_to account_community_path
      acceptance = Community::CodeOfConductAcceptance.find_by!(user: @member)
      assert_equal "1", acceptance.code_version
      assert_equal Time.current, acceptance.accepted_at
      assert_not Community::CodeOfConductAcceptance.exists?(user: other)
      assert_nil @member.reload.community_username
    end

    get community_path
    assert_response :success
    assert_select "p", I18n.t("community.conduct.accepted_version", version: "1")
    assert_select "input[name=accepted]", count: 0
  end

  test "the Community form requires explicit consent and rejects a stale version" do
    sign_in(@member)
    get community_path
    assert_response :success
    assert_select "input[name=accepted][type=checkbox][required]:not([checked])"

    assert_no_difference -> { Community::CodeOfConductAcceptance.count } do
      post community_code_of_conduct_acceptance_path, params: conduct_fields
      assert_redirected_to community_path
      assert_equal I18n.t("community.conduct.acceptance_required"), flash[:alert]

      follow_redirect!
      post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1", code_version: "previous")
      assert_redirected_to community_path
      assert_equal I18n.t("community.conduct.version_changed"), flash[:alert]
    end

    follow_redirect!
    post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1")
    assert_redirected_to community_path
    follow_redirect!
    assert_select "p", I18n.t("community.conduct.accepted_version", version: "1")
  end

  test "a new current version prompts members who accepted an earlier version" do
    sign_in(@member)
    get community_path
    post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1")
    assert_redirected_to community_path
    original = Community::CodeOfConductAcceptance.find_by!(user: @member, code_version: "1")

    stub_const(Community::CodeOfConduct, :VERSIONS, %w[1 2]) do
      stub_const(Community::CodeOfConduct, :CURRENT_VERSION, "2") do
        get community_path
        assert_select "input[name=code_version][value='2']"
        assert_select "input[name=accepted]:not([checked])"
        post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1")
        assert_redirected_to community_path
        follow_redirect!
        assert_select "p", I18n.t("community.conduct.accepted_version", version: "2")
      end
    end

    assert_equal %w[1 2], Community::CodeOfConductAcceptance.where(user: @member).order(:code_version).pluck(:code_version)
    assert_equal "1", original.reload.code_version
  end

  test "guests and signed-out browsers cannot admit themselves through direct acceptance" do
    assert_no_difference -> { Community::CodeOfConductAcceptance.count } do
      get community_path
      assert_redirected_to new_session_path
      get community_code_of_conduct_path
      token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
      post community_code_of_conduct_acceptance_path, params: { authenticity_token: token, code_version: "1", accepted: "1" }
      assert_response :unauthorized

      sign_in(Identity::UserGuest.create!)
      get community_path
      assert_response :forbidden

      get community_code_of_conduct_path
      token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
      post community_code_of_conduct_acceptance_path, params: { authenticity_token: token, code_version: "1", accepted: "1" }
      assert_response :forbidden
    end
  end

  test "acceptance requires CSRF protection" do
    sign_in(@member)
    get community_path
    assert_response :success
    fields = conduct_fields.except(:authenticity_token).merge(accepted: "1")
    assert_no_difference -> { Community::CodeOfConductAcceptance.count } do
      post community_code_of_conduct_acceptance_path, params: fields
      assert_response :unprocessable_entity
    end
  end

  test "a registered non-superuser sees locked navigation and cannot read or write preview pages" do
    member = confirmed_member("preview-locked@example.test")
    sign_in(member)
    get account_settings_path
    assert_response :success
    assert_select "header .ui-nav a[href=?] + [aria-describedby='community-nav-tooltip'][aria-disabled=true]", library_path
    assert_select "header select option[value=?] + option[value=?][disabled]", library_path, community_path,
      text: I18n.t("ui.locked_navigation_option", label: I18n.t("community.title"), reason: I18n.t("community.coming_soon"))
    assert_select ".account-tabs [aria-describedby='account-community-tooltip'][aria-disabled=true]"
    assert_select ".account-tabs a[href=?]", account_community_path, count: 0

    get community_path
    assert_response :forbidden
    get account_community_path
    assert_response :forbidden

    get community_code_of_conduct_path
    assert_response :success
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference -> { Community::CodeOfConductAcceptance.count } do
      post community_code_of_conduct_acceptance_path, params: { authenticity_token: token, code_version: "1", accepted: "1" }
      assert_response :forbidden
    end
    patch account_community_username_path, params: { authenticity_token: token, community_username: "Some_Name" }
    assert_response :forbidden
    assert_nil member.reload.community_username
  end

  private

  def confirmed_member(email_address, superuser: false)
    Identity::UserRegistered.create!(email_address:, password: PASSWORD, password_confirmation: PASSWORD, email_confirmed_at: Time.current, superuser:)
  end

  def sign_in(user)
    authentication = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: authentication.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def conduct_fields
    form = Nokogiri::HTML(response.body).at_css("form[action='#{community_code_of_conduct_acceptance_path}']")
    %i[authenticity_token code_version source].to_h do |name|
      [ name, form.at_css("input[name='#{name}']")["value"] ]
    end
  end
end
