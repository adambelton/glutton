module Ratings
  class RefreshExpressionProfiles
    def self.call(user_id: nil, synthesizer: ExpressionProfileSynthesizer.new)
      return refresh_viewer(user_id, synthesizer) if user_id.present?

      revisions, failures = {}, {}
      ExpressionProfileRefreshRequest.find_each do |request|
        viewer_id = request.user_id
        revision = RefreshExpressionProfile.call(user_id: viewer_id, synthesizer:)
        request.acknowledge!
        revisions[viewer_id] = revision&.id
      rescue IdentityUnavailable
        request.acknowledge!
      rescue ExpressionProfileRefreshFailed => error
        failures[viewer_id] = error.reason
      end

      { revisions:, failures: }
    end

    def self.refresh_viewer(user_id, synthesizer)
      request = ExpressionProfileRefreshRequest.find_by(user_id:)
      revision = RefreshExpressionProfile.call(user_id:, synthesizer:, refresh_legacy: true)
      request&.acknowledge!
      { revisions: { user_id => revision&.id }, failures: {} }
    rescue IdentityUnavailable
      request&.acknowledge!
      { revisions: {}, failures: {} }
    rescue ExpressionProfileRefreshFailed => error
      { revisions: {}, failures: { user_id => error.reason } }
    end
    private_class_method :refresh_viewer
  end
end
