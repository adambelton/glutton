require "test_helper"

class PrivacyNoticeTest < ActionDispatch::IntegrationTest
  test "signed-out visitors can read the notice before guest entry or registration" do
    get root_path
    assert_select "a[href=?]", privacy_notice_path, text: I18n.t("identity.privacy_notice.title")

    get new_registration_path
    assert_select "label.registration-terms[for=registration_terms_accepted] input[required]:not([checked])"
    version = "1"
    assert_select 'input[name="registration[privacy_notice_version]"][value=?]', version
    assert_select ".registration-policies" do
      assert_select "a[href=?]", privacy_notice_path(version:), text: I18n.t("identity.privacy_notice.title")
      assert_select "a[href=?]", terms_of_service_path(version: "1"), text: I18n.t("identity.terms_of_service.title")
    end

    get terms_of_service_path
    assert_response :success
    assert_select "h1", text: I18n.t("identity.terms_of_service.title")

    get privacy_notice_path
    assert_response :success
    assert_select "h1", text: I18n.t("identity.privacy_notice.title")
    assert_select "p", text: "Version #{version}"
    assert_select "p", text: I18n.t("identity.privacy_notice_v#{version}.backups.description")
    assert_select "#ai-providers"
    assert_select "dt", text: I18n.t("identity.privacy_notice_v#{version}.providers.typesafe.name")
    assert_select "dt", text: I18n.t("identity.privacy_notice_v#{version}.providers.openai.name")
  end

  test "the canonical launch notice is available at its versioned URL" do
    get privacy_notice_path(version: "1")
    assert_response :success
    assert_select "p", text: "Version 1"
    assert_select "dd", text: /publishes no fixed retention period/
    assert_select "dd", text: /up to 30 days/

    get privacy_notice_path(version: "2")
    assert_response :not_found
  end

  test "the launch Terms remain available at their versioned URL" do
    get terms_of_service_path(version: "1")
    assert_response :success
    assert_select "p", text: "Version 1"
    assert_select "p", text: /Guest access lasts 24 hours/

    get terms_of_service_path(version: "2")
    assert_response :not_found
  end
end
