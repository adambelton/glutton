import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["choice", "notes", "save", "journalTab", "notesIndicator"]
  static values = { baseline: Object, notesDescription: String }

  connect() {
    this.update()
  }

  update() {
    const choice = this.choiceTargets.find(input => input.checked)
    this.saveTarget.disabled = !choice || !this.isDirty(choice.value)
    this.updateNotesIndicator()
  }

  updateNotesIndicator() {
    const hasNotes = this.notesTarget.value.trim().length > 0
    this.notesIndicatorTarget.hidden = !hasNotes
    if (hasNotes) {
      this.journalTabTarget.setAttribute("aria-description", this.notesDescriptionValue)
    } else {
      this.journalTabTarget.removeAttribute("aria-description")
    }
  }

  isDirty(value) {
    if (!this.hasBaselineValue) return true

    const baseline = this.baselineValue
    return value !== baseline.value || this.notesTarget.value !== baseline.notes
  }
}
