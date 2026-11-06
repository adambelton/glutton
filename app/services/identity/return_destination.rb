module Identity
  class ReturnDestination
    EXPIRY = 1.hour

    def self.capture(path)
      return unless navigable?(path)

      { "path" => path, "expires_at" => EXPIRY.from_now.to_i }
    end

    def self.resolve(destination)
      return unless destination.is_a?(Hash) && destination["expires_at"].is_a?(Integer) &&
        destination["expires_at"] > Time.current.to_i && navigable?(destination["path"])

      destination.fetch("path")
    end

    def self.navigable?(path)
      return false unless path.is_a?(String) && path.bytesize <= 2048 && path.start_with?("/") &&
        !path.start_with?("//") && !path.match?(/[\\\x00-\x20]/) && !path.match?(/%(?:0[0-9a-f]|1[0-9a-f]|5c)/i)

      uri = URI.parse(path)
      return false if uri.host || uri.scheme || uri.fragment

      route = Rails.application.routes.recognize_path(uri.path, method: :get)
      controller_class = "#{route.fetch(:controller).camelize}Controller".safe_constantize
      # Framework/engine routes may resolve outside our application auth policy.
      controller_class.present? && controller_class < ApplicationController &&
        controller_class.authentication_required_for?(route.fetch(:action))
    rescue URI::InvalidURIError, ActionController::RoutingError
      false
    end
    private_class_method :navigable?
  end
end
