import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lockedLink", "option"]
  static values = { url: String }

  connect() {
    this.request = new AbortController()
    this.delay = 2000
    this.check()
  }

  disconnect() {
    this.request.abort()
    clearTimeout(this.timer)
  }

  async check() {
    const { signal } = this.request
    try {
      if (!document.hidden) {
        const response = await fetch(this.urlValue, { signal, cache: "no-store", headers: { Accept: "application/json" } })
        if (signal.aborted) return
        if (response.status === 204) {
          this.unlock()
          return
        }
        if (response.redirected || response.status === 401 || response.status === 403) return
      }
    } catch {
      if (signal.aborted) return
    }
    this.timer = setTimeout(() => this.check(), this.delay)
    this.delay = Math.min(this.delay * 2, 15000)
  }

  unlock() {
    const option = this.optionTarget
    const label = option.dataset.unlockedLabel
    const link = document.createElement("a")
    link.href = option.value
    link.textContent = label

    const wasFocused = document.activeElement === this.lockedLinkTarget
    this.lockedLinkTarget.replaceWith(link)
    if (wasFocused) link.focus()

    option.textContent = label
    option.disabled = false
  }
}
