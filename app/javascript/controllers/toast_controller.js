import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.resume()
  }

  disconnect() {
    this.pause()
  }

  pause() {
    window.clearTimeout(this.timer)
  }

  resume(event) {
    this.pause()
    const focused = event?.type === "focusout" ? this.element.contains(event.relatedTarget) : this.element.contains(document.activeElement)
    if (document.hidden || this.element.matches(":hover") || focused) return
    this.timer = window.setTimeout(() => this.dismiss(), 5000)
  }

  visibilityChanged() {
    if (document.hidden) this.pause()
    else this.resume()
  }

  dismiss() {
    this.pause()
    this.element.remove()
  }
}
