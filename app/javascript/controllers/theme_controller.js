import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    let theme = document.documentElement.dataset.theme || "light"
    try {
      theme = localStorage.getItem("glutton.theme") === "dark" ? "dark" : "light"
    } catch {
      // Keep the document's choice when browser storage is unavailable.
    }
    this.apply(theme)
    this.element.hidden = false
  }

  toggle() {
    const theme = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    this.apply(theme)
    try {
      localStorage.setItem("glutton.theme", theme)
    } catch {
      // Switching still works for this document without persistent storage.
    }
  }

  apply(theme) {
    document.documentElement.dataset.theme = theme
    this.element.setAttribute("aria-pressed", String(theme === "dark"))
  }
}
