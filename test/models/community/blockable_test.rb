require "test_helper"

class CommunityBlockableTest < ActiveSupport::TestCase
  class MissingMember
    include Community::Blockable
  end

  test "a missing accessor fails explicitly while unattributed content returns nil" do
    error = assert_raises(NotImplementedError) { MissingMember.new.member_id_for_blocking }
    assert_includes error.message, "must expose community_user_id or implement member_id_for_blocking"
    assert_nil Community::PostCommunityCuration.new.member_id_for_blocking
  end
end
