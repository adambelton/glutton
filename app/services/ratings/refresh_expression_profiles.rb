module Ratings
  class RefreshExpressionProfiles
    def self.call(synthesizer: ExpressionProfileSynthesizer.new)
      revisions, failures = {}, {}
      ExpressionProfileRefreshRequest.find_each do |request|
        user_id = request.user_id
        revision = RefreshExpressionProfile.call(user_id:, synthesizer:)
        request.acknowledge!
        revisions[user_id] = revision&.id
      rescue IdentityUnavailable
        request.acknowledge!
      rescue ExpressionProfileRefreshFailed => error
        failures[user_id] = error.reason
      end

      { revisions:, failures: }
    end
  end
end
