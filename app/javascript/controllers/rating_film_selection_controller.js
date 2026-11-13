import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "start", "actions"]
  static values = { minimum: Number }

  connect() {
    this.update()
    this.updateStickyBorder()
  }

  updateStickyBorder() {
    this.actionsTarget.toggleAttribute("data-stuck", this.actionsTarget.getBoundingClientRect().top <= 0)
  }

  update() {
    const checked = this.formTarget.querySelectorAll('input[name="film_ids[]"]:checked')
    this.startTarget.disabled = new Set(Array.from(checked, input => input.value)).size < this.minimumValue
  }
}
