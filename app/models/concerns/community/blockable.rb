module Community
  module Blockable
    # A nil ID means the record is unattributed. Models with a different
    # ownership accessor must implement this method explicitly.
    def member_id_for_blocking
      unless respond_to?(:community_user_id)
        raise NotImplementedError, "#{self.class} must expose community_user_id or implement member_id_for_blocking"
      end

      community_user_id
    end
  end
end
