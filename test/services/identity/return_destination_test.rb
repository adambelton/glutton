require "test_helper"

class Identity::ReturnDestinationTest < ActiveSupport::TestCase
  test "only recognized local navigable product routes survive capture and expiry" do
    valid = Identity::ReturnDestination.capture("/library?view=watched&page=2")
    assert_equal "/library?view=watched&page=2", Identity::ReturnDestination.resolve(valid)
    travel 1.hour do
      assert_nil Identity::ReturnDestination.resolve(valid)
    end
    [ nil, [], {}, "https://evil.test/library", "//evil.test/library", "/\\evil.test", "/session/new", "/registration/new", "/", "/missing", "/library%0d%0aLocation:evil", "/library#fragment" ].each do |path|
      assert_nil Identity::ReturnDestination.capture(path), path.inspect
      assert_nil Identity::ReturnDestination.resolve({ "path" => path, "expires_at" => 1.hour.from_now.to_i })
    end
  end
end
