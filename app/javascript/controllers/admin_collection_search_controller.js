import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "clearLink", "results"]

  disconnect() {
    clearTimeout(this.timer)
  }

  schedule(event) {
    clearTimeout(this.timer)
    if (event.isComposing) return

    const hasQuery = this.inputTarget.value.trim().length > 0
    this.clearLinkTarget.hidden = !hasQuery
    this.timer = setTimeout(() => {
      if (hasQuery) {
        this.formTarget.requestSubmit()
      } else {
        this.clearLinkTarget.click()
      }
    }, 350)
  }

  updateLocation(event) {
    if (event.target !== this.resultsTarget || this.formTarget.method !== "get") return

    // Keep the filter URL shareable without starting a second visit after the frame updates.
    window.history.replaceState(window.history.state, "", this.resultsTarget.src)
  }

  submit() {
    clearTimeout(this.timer)
  }

  clear() {
    clearTimeout(this.timer)
    this.inputTarget.value = ""
    this.clearLinkTarget.hidden = true
    this.inputTarget.focus()
  }

  escape(event) {
    if (this.inputTarget.value.length === 0) return

    event.preventDefault()
    this.clearLinkTarget.click()
  }
}
