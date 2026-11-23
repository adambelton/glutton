import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["save"]
  static values = { field: String, saved: String }

  connect() {
    this.update()
  }

  update() {
    const value = new FormData(this.element).get(this.fieldValue)
    this.saveTarget.disabled = !value || value === this.savedValue
  }
}
