module Ratings
  class RefreshTasteProfiles
    def self.call(user_id: nil, client: Rails.application.config.x.openai_client)
      return refresh_viewer(user_id, client) if user_id.present?

      revisions, failures = {}, {}
      TasteProfileRefreshRequest.find_each do |request|
        viewer_id = request.user_id
        revision = RefreshTasteProfile.call(user_id: viewer_id, client:)
        request.acknowledge!
        revisions[viewer_id] = revision&.id
      rescue IdentityUnavailable
        request.acknowledge!
      rescue TasteProfileRefreshFailed => error
        failures[viewer_id] = error.reason
      end

      { revisions:, failures: }
    end

    def self.refresh_viewer(user_id, client)
      request = TasteProfileRefreshRequest.find_by(user_id:)
      revision = RefreshTasteProfile.call(user_id:, client:)
      request&.acknowledge!
      { revisions: { user_id => revision&.id }, failures: {} }
    rescue IdentityUnavailable
      request&.acknowledge!
      { revisions: {}, failures: {} }
    rescue TasteProfileRefreshFailed => error
      { revisions: {}, failures: { user_id => error.reason } }
    end
    private_class_method :refresh_viewer
  end
end
