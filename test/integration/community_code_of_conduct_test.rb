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

  test "the current code is readable without an account and ignores a version parameter" do
    [ community_code_of_conduct_path, community_code_of_conduct_path(version: "unknown") ].each do |path|
      get path
      assert_response :success
      assert_select "h1", I18n.t("community.conduct.title")
      assert_select ".community-conduct-text p", text: /\AVersion \d+\z/, count: 0
      assert_select "a[href='mailto:#{I18n.t("community.code_of_conduct_v1.copyright.email")}']"
      assert_select "header .ui-auth-links a[href=?]", new_session_path
      assert_select "header .ui-auth-links a[href=?]", new_registration_path
    end
  end

  test "Account shows the full code before acceptance and unlocks profile settings afterward" do
    other = confirmed_member("other-conduct@example.test")
    sign_in(@member)
    get account_community_path
    assert_response :success
    assert_full_conduct_before_form("1")
    assert_select "input#community_username, .account-avatar-current", count: 0

    travel_to Time.zone.local(2026, 11, 21, 12) do
      post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1", user_id: other.id)
      assert_redirected_to account_community_path
      assert_equal "1", @member.reload.community_code_of_conduct_version
      assert_equal Time.current, @member.community_code_of_conduct_accepted_at
      assert_nil other.reload.community_code_of_conduct_accepted_at
    end

    follow_redirect!
    assert_select "input#community_username"
    assert_select ".account-avatar-current"
    assert_select ".community-conduct-text, input[name=accepted]", count: 0
    assert_select "section > p", I18n.t("community.conduct.accepted")
    assert_select "a[href=?]", community_code_of_conduct_path, text: I18n.t("community.conduct.read")

    get community_path
    assert_response :success
    assert_select "section > p", I18n.t("community.conduct.accepted")
    assert_select "input[name=accepted]", count: 0
  end

  test "direct profile writes require current acceptance" do
    sign_in(@member)
    get account_community_path(edit: "avatar")
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_select "input[name=community_avatar_preset]", count: 0

    patch account_community_avatar_path, params: { authenticity_token: token, community_avatar_preset: "tentacle" }
    assert_redirected_to account_community_path
    assert_equal I18n.t("community.conduct.profile_acceptance_required"), flash[:alert]

    get account_community_path(edit: "username")
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_select "input#community_username", count: 0

    patch account_community_username_path, params: { authenticity_token: token, community_username: "New_Name" }
    assert_redirected_to account_community_path
    assert_equal I18n.t("community.conduct.profile_acceptance_required"), flash[:alert]
    assert_nil @member.reload.community_avatar_preset
    assert_nil @member.community_username
  end

  test "the Community form requires explicit consent and rejects a stale version" do
    sign_in(@member)
    get community_path
    assert_response :success
    assert_full_conduct_before_form("1")

    post community_code_of_conduct_acceptance_path, params: conduct_fields
    assert_redirected_to community_path
    assert_equal I18n.t("community.conduct.acceptance_required"), flash[:alert]
    assert_nil @member.reload.community_code_of_conduct_accepted_at

    follow_redirect!
    post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1", code_version: "previous")
    assert_redirected_to community_path
    assert_equal I18n.t("community.conduct.version_changed"), flash[:alert]
    assert_nil @member.reload.community_code_of_conduct_accepted_at

    follow_redirect!
    post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1")
    assert_redirected_to community_path
    follow_redirect!
    assert_select "section > p", I18n.t("community.conduct.accepted")
  end

  test "accepting a new version replaces the old receipt and keeps the profile" do
    sign_in(@member)
    get community_path
    post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1")
    assert_redirected_to community_path
    original = @member.reload.community_code_of_conduct_accepted_at
    @member.change_community_username!(community_username: "Scream_Queen")
    @member.choose_community_avatar!(preset: "tentacle")

    updated_text = I18n.t("community.code_of_conduct_v1").merge(intro: "The current Code of Conduct applies throughout Community.")
    I18n.backend.store_translations(:en, community: { code_of_conduct_v2: updated_text })
    stub_const(Community::CodeOfConduct, :VERSIONS, %w[1 2]) do
      stub_const(Community::CodeOfConduct, :CURRENT_VERSION, "2") do
        get account_community_path
        assert_full_conduct_before_form("2")
        assert_select ".account-avatar-current, input#community_username", count: 0
        travel 1.hour do
          post community_code_of_conduct_acceptance_path, params: conduct_fields.merge(accepted: "1")
          assert_redirected_to account_community_path
          follow_redirect!
          assert_select "section > p", I18n.t("community.conduct.accepted")
          assert_select ".account-avatar-current img[alt=?]", I18n.t("identity.settings.community_avatar.presets.tentacle")
          assert_select ".account-settings-field p", "Scream_Queen"
          assert_select "a[href=?]", community_code_of_conduct_path, text: I18n.t("community.conduct.read")
          get community_code_of_conduct_path(version: "1")
          assert_select ".community-conduct-text p", text: updated_text.fetch(:intro)
          assert_select ".community-conduct-text p", text: /\AVersion \d+\z/, count: 0
          assert_select "header .ui-nav a[href=?]", account_settings_path
          assert_select "header .ui-auth-links", count: 0
        end
      end
    end

    assert_equal "2", @member.reload.community_code_of_conduct_version
    assert_operator @member.community_code_of_conduct_accepted_at, :>, original
  ensure
    I18n.reload!
  end

  test "guests and signed-out browsers cannot admit themselves through direct acceptance" do
    get community_path
    assert_redirected_to new_session_path
    get community_code_of_conduct_path
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    post community_code_of_conduct_acceptance_path, params: { authenticity_token: token, code_version: "1", accepted: "1" }
    assert_response :unauthorized

    guest = Identity::UserGuest.create!
    sign_in(guest)
    get community_path
    assert_response :forbidden

    get community_code_of_conduct_path
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    post community_code_of_conduct_acceptance_path, params: { authenticity_token: token, code_version: "1", accepted: "1" }
    assert_response :forbidden
    assert_nil guest.reload.community_code_of_conduct_accepted_at
  end

  test "acceptance requires CSRF protection" do
    sign_in(@member)
    get community_path
    assert_response :success
    fields = conduct_fields.except(:authenticity_token).merge(accepted: "1")
    post community_code_of_conduct_acceptance_path, params: fields
    assert_response :unprocessable_entity
    assert_nil @member.reload.community_code_of_conduct_accepted_at
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
    post community_code_of_conduct_acceptance_path, params: { authenticity_token: token, code_version: "1", accepted: "1" }
    assert_response :forbidden
    assert_nil member.reload.community_code_of_conduct_accepted_at
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

  def assert_full_conduct_before_form(version)
    scope = "community.code_of_conduct_v#{version}"
    assert_select ".community-conduct-text p", I18n.t("#{scope}.intro")
    %i[respect spoilers avatars moderation copyright].each do |topic|
      assert_select ".community-conduct-text section p", I18n.t("#{scope}.#{topic}.description")
    end
    assert_select ".community-conduct-text + form" do
      assert_select "input[name=code_version][value=?]", version
      assert_select "input[name=accepted][type=checkbox][required]:not([checked])"
    end
  end

  def conduct_fields
    form = Nokogiri::HTML(response.body).at_css("form[action='#{community_code_of_conduct_acceptance_path}']")
    %i[authenticity_token code_version source].to_h do |name|
      [ name, form.at_css("input[name='#{name}']")["value"] ]
    end
  end
end
