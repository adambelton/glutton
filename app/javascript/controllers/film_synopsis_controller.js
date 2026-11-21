import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "text"]
  static values = { expandLabel: String, collapseLabel: String }

  connect() {
    this.element.dataset.ready = "true"
    this.observer = new ResizeObserver(() => this.updateOverflow())
    this.observer.observe(this.element)
    this.updateOverflow()
  }

  disconnect() {
    this.observer.disconnect()
  }

  toggle() {
    this.setExpanded(!this.expanded)
  }

  collapse() {
    if (!this.expanded) return

    this.setExpanded(false)
    this.toggleTarget.focus()
  }

  get expanded() {
    return this.toggleTarget.getAttribute("aria-expanded") === "true"
  }

  setExpanded(expanded) {
    this.toggleTarget.setAttribute("aria-expanded", String(expanded))
    this.toggleTarget.setAttribute("aria-label", expanded ? this.collapseLabelValue : this.expandLabelValue)
    if (expanded) {
      this.textTarget.tabIndex = 0
    } else {
      this.textTarget.removeAttribute("tabindex")
      this.updateOverflow()
    }
  }

  updateOverflow() {
    if (this.expanded || this.element.clientWidth === 0) return

    this.toggleTarget.hidden = this.textTarget.scrollHeight <= this.textTarget.clientHeight
  }
}
