require "test_helper"

class WebAppManifestTest < ActionDispatch::IntegrationTest
  test "the public app links to a standalone manifest with installable icons" do
    get root_path
    assert_response :success
    assert_select "link[rel=manifest][href=?]", web_app_manifest_path
    assert_select "link[rel=apple-touch-icon][href='/glutton-app-icon-192.png']"

    get web_app_manifest_path
    assert_response :success
    assert_equal "application/manifest+json", response.media_type
    manifest = JSON.parse(response.body)
    assert_equal I18n.t("app.name"), manifest.fetch("name")
    assert_equal root_path, manifest.fetch("start_url")
    assert_equal "/", manifest.fetch("id")
    assert_equal "/", manifest.fetch("scope")
    assert_equal "standalone", manifest.fetch("display")
    assert_equal %w[192x192 512x512], manifest.fetch("icons").map { |icon| icon.fetch("sizes") }
    manifest.fetch("icons").each do |icon|
      get icon.fetch("src")
      assert_response :success
      assert_equal "image/png", response.media_type
      assert_equal icon.fetch("sizes").split("x").map(&:to_i), response.body.b.byteslice(16, 8).unpack("N2")
    end
  end
end
