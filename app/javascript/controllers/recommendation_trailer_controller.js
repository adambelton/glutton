import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.toggleTarget.hidden = false
  }

  toggle() {
    this.setExpanded(!this.element.classList.contains("recommendation-film-expanded"))
  }

  collapse() {
    if (this.element.classList.contains("recommendation-film-expanded")) {
      this.setExpanded(false)
      this.toggleTarget.focus()
    }
  }

  fitViewport() {
    if (this.element.classList.contains("recommendation-film-expanded") && this.toggleTarget.getClientRects().length === 0) {
      this.setExpanded(false)
    }
  }

  setExpanded(expanded) {
    if (expanded) {
      this.element.style.setProperty("--recommendation-card-height", `${this.element.getBoundingClientRect().height}px`)
    } else {
      this.element.style.removeProperty("--recommendation-card-height")
    }
    this.element.classList.toggle("recommendation-film-expanded", expanded)
    this.toggleTarget.setAttribute("aria-expanded", String(expanded))
    const { expandLabel, collapseLabel } = this.toggleTarget.dataset
    this.toggleTarget.setAttribute("aria-label", expanded ? collapseLabel : expandLabel)
  }
}
