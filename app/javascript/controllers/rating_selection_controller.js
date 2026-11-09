import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["choice", "save"]

  connect() {
    this.update()
  }

  update() {
    this.saveTarget.disabled = !this.choiceTargets.some(choice => choice.checked)
  }
}
