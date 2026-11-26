import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "film"]

  preview(event) {
    if (event.defaultPrevented || this.element.open || !this.touchActivation(event)) return

    const button = event.target.closest("button[type='submit']")
    const form = button?.form
    if (!form?.hasAttribute("data-library-confirmation-title") || button.disabled) return

    event.preventDefault()
    this.submitter = button
    this.titleTarget.textContent = form.dataset.libraryConfirmationTitle
    this.filmTarget.textContent = form.dataset.libraryConfirmationFilm
    this.element.showModal()
  }

  touchActivation(event) {
    if (event.detail === 0) return false
    if (event.pointerType) return event.pointerType === "touch"
    if (event.sourceCapabilities) return event.sourceCapabilities.firesTouchEvents

    // Some browsers expose tap-generated clicks as MouseEvents.
    return window.matchMedia("(hover: none) and (pointer: coarse)").matches
  }

  keepSearchOpen(event) {
    event.stopPropagation()
  }

  close() {
    this.element.close()
  }

  reset() {
    if (!this.element.open) this.submitter = null
  }

  confirm() {
    const button = this.submitter
    this.close()
    if (button?.isConnected && !button.disabled) button.form?.requestSubmit(button)
  }
}
