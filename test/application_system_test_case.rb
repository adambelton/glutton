require "test_helper"
require "capybara-playwright-driver"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  ElementRectangle = Data.define(:x, :y, :width, :height)
  PLAYWRIGHT_OPTIONS = {
    playwright_cli_executable_path: Rails.root.join("test/playwright/node_modules/.bin/playwright").to_s
  }.freeze
  CLASSIC_SCROLLBAR_OPTIONS = PLAYWRIGHT_OPTIONS.merge(
    name: :playwright_classic_scrollbars,
    channel: "chromium",
    ignoreDefaultArgs: [ "--hide-scrollbars" ],
    args: [ "--disable-features=OverlayScrollbar" ]
  ).freeze

  Capybara.enable_aria_label = true
  driven_by :playwright, screen_size: [ 1400, 1000 ], options: PLAYWRIGHT_OPTIONS.dup

  setup do
    GuestSessionsController::RATE_LIMIT_STORE.clear
    SessionsController::RATE_LIMIT_STORE.clear
    if ENV["GLUTTON_PLAYWRIGHT_TRACE"] == "1"
      page.driver.on_save_trace do |path|
        if failures.any?
          traces = Rails.root.join("tmp/playwright-traces")
          FileUtils.mkdir_p(traces)
          FileUtils.cp(path, traces.join(File.basename(path)))
        end
      end
    end
  end

  private

  def element_rectangle(element)
    ElementRectangle.new(*element.rect.fetch_values("x", "y", "width", "height"))
  end

  def chromium_command(command, **parameters)
    page.driver.with_playwright_page do |browser_page|
      if @cdp_page != browser_page
        @cdp_page = browser_page
        @cdp_session = browser_page.context.new_cdp_session(browser_page)
      end
      @cdp_session.send_message(command, params: parameters)
    end
  end

  def set_viewport(width, height, mobile: false)
    chromium_command("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 1, mobile:)
    @viewport_overridden = true
  end

  def reset_viewport
    if @viewport_overridden
      chromium_command("Emulation.clearDeviceMetricsOverride")
      @viewport_overridden = false
    end
  end

  def enable_touch
    chromium_command("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
    @touch_enabled = true
  end

  def reset_touch
    if @touch_enabled
      chromium_command("Emulation.setTouchEmulationEnabled", enabled: false)
      @touch_enabled = false
    end
  end
end
