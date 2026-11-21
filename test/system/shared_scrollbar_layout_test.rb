require "application_system_test_case"

class SharedScrollbarLayoutTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ], options: { name: :selenium_classic_scrollbars } do |options|
    options.add_argument("--disable-features=OverlayScrollbar")
  end

  test "the shared layout stays aligned when a classic scrollbar appears" do
    visit new_session_path
    assert_selector "#main-content"

    assert page.evaluate_script("document.scrollingElement.scrollHeight <= window.innerHeight")
    assert page.evaluate_script("document.body.getBoundingClientRect().width < window.innerWidth")
    before = horizontal_layout

    page.execute_script(<<~JS)
      const content = document.createElement("div")
      content.style.height = "200vh"
      document.body.append(content)
    JS

    assert page.evaluate_script("document.scrollingElement.scrollHeight > window.innerHeight")
    assert_equal before, horizontal_layout
    page.execute_script("window.scrollTo(0, document.scrollingElement.scrollHeight)")
    assert_operator page.evaluate_script("window.scrollY"), :>, 0
  end

  private

  def horizontal_layout
    page.evaluate_script(<<~JS)
      [".ui-header-inner", "#main-content"].map(selector => {
        const { x, width } = document.querySelector(selector).getBoundingClientRect()
        return [x, width]
      })
    JS
  end
end
