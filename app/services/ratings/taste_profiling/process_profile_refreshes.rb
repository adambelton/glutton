module Ratings
  module TasteProfiling
    class ProcessProfileRefreshes
      def self.call(user_id: nil, client: Rails.application.config.x.openai_client)
        return refresh_viewer(user_id, client) if user_id.present?

        revisions, failures = {}, {}
        TasteProfileRefreshRequest.find_each do |request|
          viewer_id = request.user_id
          revision = RefreshTasteProfile.call(user_id: viewer_id, client:)
          request.acknowledge!
          revisions[viewer_id] = revision&.id
        rescue Identity::Errors::Unavailable
          request.acknowledge!
        rescue Errors::TasteProfileRefreshFailed => error
          failures[viewer_id] = error.reason
        end

        { revisions:, failures: }
      end

      def self.refresh_viewer(user_id, client)
        request = TasteProfileRefreshRequest.find_by(user_id:)
        revision = RefreshTasteProfile.call(user_id:, client:)
        request&.acknowledge!
        { revisions: { user_id => revision&.id }, failures: {} }
      rescue Identity::Errors::Unavailable
        request&.acknowledge!
        { revisions: {}, failures: {} }
      rescue Errors::TasteProfileRefreshFailed => error
        { revisions: {}, failures: { user_id => error.reason } }
      end
      private_class_method :refresh_viewer
    end
  end
end
