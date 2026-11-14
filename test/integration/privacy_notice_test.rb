require "test_helper"

class PrivacyNoticeTest < ActionDispatch::IntegrationTest
  test "signed-out visitors can read the notice before guest entry or registration" do
    get root_path
    assert_select "a[href=?]", privacy_notice_path, text: I18n.t("identity.privacy_notice.title")

    get new_registration_path
    assert_select "label.registration-terms[for=registration_terms_accepted] input[required]:not([checked])"
    assert_select ".registration-policies" do
      assert_select "a[href=?]", privacy_notice_path, text: I18n.t("identity.privacy_notice.title")
      assert_select "a[href=?]", terms_of_service_path, text: I18n.t("identity.terms_of_service.title")
    end

    get terms_of_service_path
    assert_response :success
    assert_select "h1", text: I18n.t("identity.terms_of_service.title")

    get privacy_notice_path
    assert_response :success
    assert_select "h1", text: I18n.t("identity.privacy_notice.title")
    assert_select "p", text: I18n.t("identity.privacy_notice.backups.description")
    assert_select "#ai-providers"
    assert_select "dt", text: I18n.t("identity.privacy_notice.providers.typesafe.name")
    assert_select "dt", text: I18n.t("identity.privacy_notice.providers.openai.name")
  end
end
