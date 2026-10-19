require "uri"

module Identity
  class MailOrigin
    def self.call
      begin
        uri = URI.parse(ENV.fetch("APP_ORIGIN", ""))
      rescue URI::InvalidURIError
        uri = nil
      end
      local_http = uri.present? && uri.scheme == "http" && %w[localhost 127.0.0.1 ::1].include?(uri.host) && Rails.env.development?
      unless uri.present? && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? &&
          [ "", "/" ].include?(uri.path) && (uri.scheme == "https" || local_http)
        raise ArgumentError, "APP_ORIGIN must be a root HTTPS origin (localhost HTTP is allowed in development)"
      end
      uri.to_s.delete_suffix("/")
    end
  end
end
