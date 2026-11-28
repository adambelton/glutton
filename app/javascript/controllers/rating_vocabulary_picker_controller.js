import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["choices", "prompt", "rating", "trigger", "editor", "dialog", "value", "sample", "save",
    "error", "options", "option", "summary", "currentOption", "symbol"]
  static values = { labels: Object, saved: String }

  connect() {
    if (this.hasTriggerTarget) this.triggerTarget.hidden = false
  }

  open() {
    this.setEditing(true)
    this.summaryTarget.focus()
  }

  close(event) {
    if (event?.key === "Escape") {
      event.preventDefault()
      if (this.optionsTarget.open) {
        this.optionsTarget.open = false
        this.summaryTarget.focus()
        return
      }
    }

    if (this.hasDialogTarget) {
      this.dialogTarget.close()
    } else if (!this.editorTarget.hidden) {
      this.setEditing(false)
      if (event?.type !== "turbo:before-cache") this.triggerTarget.focus()
      this.reset()
    }
  }

  setEditing(editing) {
    this.editorTarget.hidden = !editing
    this.promptTarget.hidden = editing
    this.triggerTarget.setAttribute("aria-expanded", String(editing))
    if (editing) this.choicesTarget.setAttribute("aria-disabled", "true")
    else this.choicesTarget.removeAttribute("aria-disabled")
    this.ratingTargets.forEach((rating) => { rating.inert = editing })
  }

  choose({ params: { key } }) {
    this.preview(key)
    this.optionsTarget.open = false
    this.summaryTarget.focus()
  }

  preview(key) {
    const option = this.choice(key)
    this.currentOptionTarget.replaceChildren(...this.copyChildren(option))
    this.valueTarget.value = key
    this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.sampleTargets.forEach((sample) => { sample.textContent = this.labelsValue[key][sample.dataset.value] })
    if (this.hasSaveTarget) this.saveTarget.disabled = key === this.savedValue
  }

  submitStart({ detail: { formSubmission } }) {
    this.submitted = formSubmission.body.get("vocabulary")
  }

  submitEnd({ detail: { success } }) {
    if (!success) return

    this.savedValue = this.submitted
    if (this.hasDialogTarget) {
      this.valueTarget.form.dataset.formSubmissionBaselineValue = JSON.stringify({ vocabulary: this.savedValue })
    }
    this.symbolTarget.replaceChildren(...this.copyChildren(this.choice(this.savedValue).firstElementChild))
    Turbo.cache.clear()
    this.close()
  }

  reset() {
    this.preview(this.savedValue)
    this.optionsTarget.open = false
    this.errorTarget.textContent = ""
  }

  choice(key) {
    return this.optionTargets.find((option) => option.dataset.ratingVocabularyPickerKeyParam === key)
  }

  copyChildren(element) {
    return Array.from(element.childNodes, (child) => child.cloneNode(true))
  }
}
