import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.apply(document.documentElement.dataset.theme || "dark")
    this.element.hidden = false
  }

  toggle() {
    const theme = document.documentElement.dataset.theme === "light" ? "dark" : "light"
    this.apply(theme)
    try {
      localStorage.setItem("glutton.theme", theme)
    } catch {
      // Switching still works for this document without persistent storage.
    }
  }

  apply(theme) {
    if (theme === "light") {
      document.documentElement.dataset.theme = "light"
    } else {
      delete document.documentElement.dataset.theme
    }
    this.element.setAttribute("aria-pressed", String(theme === "dark"))
  }
}
