Appsignal.configure do |config|
  config.activate_if_environment(:staging)
  config.name = "Glutton"
  config.push_api_key = ENV["APPSIGNAL_PUSH_API_KEY"]
  config.revision = ENV["RENDER_GIT_COMMIT"] if ENV.key?("RENDER_GIT_COMMIT")

  config.send_params = false
  config.send_session_data = false
  config.request_headers = []
  config.response_headers = []
  config.send_environment_metadata = false
  config.files_world_accessible = false
  config.log_level = "warn"
  config.ignore_namespaces = [ "idle_domain_events" ]
end
