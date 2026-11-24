import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["controls", "expand", "collapse", "film"]

  connect() {
    if (this.filmTargets.length === 0) return

    this.updateControls()
    this.controlsTarget.hidden = false
  }

  expandAll() {
    this.setOpen(true)
  }

  collapseAll() {
    this.setOpen(false)
  }

  setOpen(open) {
    for (const film of this.filmTargets) film.open = open
    this.updateControls()
  }

  updateControls() {
    this.expandTarget.disabled = this.filmTargets.every((film) => film.open)
    this.collapseTarget.disabled = this.filmTargets.every((film) => !film.open)
  }
}
