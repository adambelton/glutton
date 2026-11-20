import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.tooltip = document.createElement("span")
    this.tooltip.className = "film-search-tooltip"
    this.tooltip.setAttribute("aria-hidden", "true")
    this.tooltip.hidden = true
    this.element.after(this.tooltip)
  }

  disconnect() {
    this.tooltip.remove()
  }

  show(event) {
    const button = event.target.closest("button[data-tooltip]")
    if (!button) return

    this.button = button
    this.tooltip.textContent = button.dataset.tooltip
    this.tooltip.hidden = false
    const anchor = button.getBoundingClientRect()
    const { width, height } = this.tooltip.getBoundingClientRect()
    this.tooltip.style.left = `${Math.max(8, anchor.right - width)}px`
    this.tooltip.style.top = `${anchor.top >= height + 6 ? anchor.top - height - 6 : anchor.bottom + 6}px`
  }

  leave(event) {
    if (!this.button?.contains(event.relatedTarget)) this.hide()
  }

  hide() {
    this.tooltip.hidden = true
    this.button = null
  }
}
