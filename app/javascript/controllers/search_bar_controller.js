import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  select(event) {
    const mode = event.currentTarget.value
    this.buttonTargets.forEach(button => button.setAttribute("aria-pressed", String(button.value === mode)))
    this.panelTargets.forEach(panel => { panel.hidden = panel.dataset.mode !== mode })
    this.panelTargets.find(panel => !panel.hidden)?.querySelector('input[type="search"]')?.focus()
  }
}
