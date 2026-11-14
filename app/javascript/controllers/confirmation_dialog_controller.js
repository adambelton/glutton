import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { autoOpen: Boolean }

  connect() {
    if (this.autoOpenValue) {
      this.open()
      this.autoOpenValue = false
    }
  }

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}
