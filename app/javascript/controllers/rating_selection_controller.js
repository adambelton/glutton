import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["choice", "notes", "save"]
  static values = { baseline: Object }

  connect() {
    this.update()
  }

  update() {
    const choice = this.choiceTargets.find(input => input.checked)
    this.saveTarget.disabled = !choice || !this.isDirty(choice.value)
  }

  isDirty(value) {
    if (!this.hasBaselineValue) return true

    const baseline = this.baselineValue
    return value !== baseline.value || this.notesTarget.value !== baseline.notes
  }
}
