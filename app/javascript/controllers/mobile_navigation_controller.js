import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigate() {
    const path = this.element.value
    if (!path) return

    this.element.selectedIndex = Array.from(this.element.options).findIndex(option => option.defaultSelected)
    window.Turbo.visit(path)
  }
}
