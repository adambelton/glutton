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
      assert_select "a[href=?]", privacy_notice_path, text: I18n.t("identity.privacy_notice.title")
      assert_select "a[href=?]", terms_of_service_path, text: I18n.t("identity.terms_of_service.title")
    end

    get terms_of_service_path
    assert_response :success
    assert_select "h1", text: I18n.t("identity.terms_of_service.title")

    get privacy_notice_path
    assert_response :success
    assert_select "h1", text: I18n.t("identity.privacy_notice.title")
    assert_select "p", text: /\AVersion \d+\z/, count: 0
    assert_select "p", text: I18n.t("identity.privacy_notice_v#{version}.backups.description")
    assert_select "#ai-providers"
    assert_select "dt", text: I18n.t("identity.privacy_notice_v#{version}.providers.typesafe.name")
    assert_select "dt", text: I18n.t("identity.privacy_notice_v#{version}.providers.openai.name")
  end

  test "privacy always shows the current notice without a version label" do
    %w[1 unknown].each do |version|
      get privacy_notice_path(version:)
      assert_response :success
      assert_select "p", text: /\AVersion \d+\z/, count: 0
      assert_select "dd", text: /publishes no fixed retention period/
      assert_select "dd", text: /up to 30 days/
    end
  end

  test "terms always shows the current text without a version label" do
    %w[1 unknown].each do |version|
      get terms_of_service_path(version:)
      assert_response :success
      assert_select "p", text: /\AVersion \d+\z/, count: 0
      assert_select "p", text: /Guest access lasts 24 hours/
    end
  end
end
