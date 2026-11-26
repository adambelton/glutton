require "test_helper"

if ENV.key?("GLUTTON_TEST_CHROME_BINARY")
  require "selenium-webdriver"
  Selenium::WebDriver::Chrome.path = ENV.fetch("GLUTTON_TEST_CHROME_BINARY")
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  Capybara.enable_aria_label = true

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

  setup do
    GuestSessionsController::RATE_LIMIT_STORE.clear
    SessionsController::RATE_LIMIT_STORE.clear
  end
end
