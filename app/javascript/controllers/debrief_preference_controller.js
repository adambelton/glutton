import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rating", "shortcut"]

  connect() {
    this.shortcutTargets.forEach((button) => { button.hidden = false })
  }

  selectRatings({ params: { selected } }) {
    this.ratingTargets.forEach((checkbox) => { checkbox.checked = selected })
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
