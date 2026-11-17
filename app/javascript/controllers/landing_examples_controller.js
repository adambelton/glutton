import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "controls", "position", "dot"]
  static values = { positionTemplate: String }

  connect() {
    this.index = 0
    this.controlsTarget.hidden = this.panelTargets.length < 2
    this.show()
  }

  select(event) {
    this.index = Number(event.currentTarget.dataset.index)
    this.show()
  }

  show() {
    this.panelTargets.forEach((panel, index) => { panel.hidden = index !== this.index })
    this.dotTargets.forEach((dot, index) => {
      if (index === this.index) dot.setAttribute("aria-current", "true")
      else dot.removeAttribute("aria-current")
    })
    this.positionTarget.textContent = this.positionTemplateValue.replace("%{position}", String(this.index + 1))
  }
}
