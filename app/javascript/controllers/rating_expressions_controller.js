import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["draft", "list", "template"]
  static values = { limit: Number, limitMessage: String, unaddedMessage: String, removeLabel: String }

  connect() {
    this.form = this.element.closest("form")
    this.submitHandler = event => {
      if (this.draftTarget.value.trim()) {
        event.preventDefault()
        this.invalid(this.unaddedMessageValue)
      }
    }
    this.form.addEventListener("submit", this.submitHandler)
    this.refresh()
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.submitHandler)
  }

  clearValidity() {
    this.draftTarget.setCustomValidity("")
  }

  keydown(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault()
      this.add()
    }
  }

  add() {
    if (this.appendDraft()) {
      if (this.draftTarget.disabled) this.listTarget.lastElementChild.querySelector("button").focus()
      else this.draftTarget.focus()
    }
  }

  appendDraft() {
    this.clearValidity()
    if (!this.draftTarget.value.trim()) return false
    if (this.listTarget.children.length >= this.limitValue) return this.invalid(this.limitMessageValue)
    if (!this.draftTarget.reportValidity()) return false

    const item = this.templateTarget.content.firstElementChild.cloneNode(true)
    item.querySelector("[data-expression-copy]").textContent = this.draftTarget.value
    item.querySelector("input").value = this.draftTarget.value
    this.listTarget.append(item)
    this.draftTarget.value = ""
    this.refresh()
    return true
  }

  remove(event) {
    event.currentTarget.closest("li").remove()
    this.clearValidity()
    this.refresh()
    this.draftTarget.focus()
  }

  refresh() {
    this.listTarget.querySelectorAll("button").forEach((button, index) => {
      button.setAttribute("aria-label", this.removeLabelValue.replace("%{number}", String(index + 1)))
    })
    const full = this.listTarget.children.length >= this.limitValue
    this.draftTarget.disabled = full && !this.draftTarget.value.trim()
  }

  invalid(message) {
    this.draftTarget.setCustomValidity(message)
    this.draftTarget.reportValidity()
    return false
  }
}
