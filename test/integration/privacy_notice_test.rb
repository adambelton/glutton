require "test_helper"

class PrivacyNoticeTest < ActionDispatch::IntegrationTest
  test "signed-out visitors can read the notice before guest entry or registration" do
    get root_path
    assert_select "a[href=?]", privacy_notice_path, text: I18n.t("identity.privacy_notice.title")

    get new_registration_path
    assert_select "p", text: I18n.t("identity.privacy_notice.registration_disclosure")
    assert_select "a[href=?]", privacy_notice_path, text: I18n.t("identity.privacy_notice.title")

    assert_select "a[href=?]", terms_of_service_path, text: I18n.t("identity.terms_of_service.title")

    get terms_of_service_path
    assert_response :success
    assert_select "h1", text: I18n.t("identity.terms_of_service.title")

    get privacy_notice_path
    assert_response :success
    assert_select "h1", text: I18n.t("identity.privacy_notice.title")
    assert_select "p", text: I18n.t("identity.privacy_notice.backups.description")
  end
end
