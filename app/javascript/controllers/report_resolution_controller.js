import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["outcome", "action"]
  static values = { accepted: String }

  connect() {
    this.update()
  }

  update() {
    const accepted = this.outcomeTarget.value === this.acceptedValue
    this.actionTarget.disabled = !accepted
    if (!accepted) this.actionTarget.value = ""
  }
}
