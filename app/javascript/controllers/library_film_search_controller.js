import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { error: String }
  static targets = ["spinner"]

  disconnect() {
    this.cancel()
  }

  schedule(event) {
    this.cancel()
    if (event.isComposing) return

    const query = this.query()
    if (!query) {
      this.results.replaceChildren()
      this.results.hidden = true
      return
    }

    this.timer = setTimeout(() => this.search(query), 350)
  }

  submit(event) {
    event.preventDefault()
    this.cancel()
    const query = this.query()
    if (query) this.search(query)
  }

  cancel() {
    clearTimeout(this.timer)
    this.request?.abort()
    this.setLoading(false)
  }

  setLoading(loading) {
    if (this.hasSpinnerTarget) this.spinnerTarget.hidden = !loading
    if (loading) this.results.setAttribute("aria-busy", "true")
    else this.results?.removeAttribute("aria-busy")
  }

  dismissOutside(event) {
    if (!this.element.contains(event.target)) this.dismiss()
  }

  dismiss() {
    if (!this.element.contains(this.results)) return

    this.cancel()
    if (this.results.contains(this.element.ownerDocument.activeElement)) this.input.focus()
    this.results.hidden = true
  }

  reopen() {
    if (this.element.contains(this.results) && this.query() && this.results.hasChildNodes()) {
      this.results.hidden = false
      this.fitDropdown()
    }
  }

  fitDropdown() {
    if (!this.element.contains(this.results) || this.results.hidden) return

    const available = window.innerHeight - this.results.getBoundingClientRect().top - 12
    this.results.style.setProperty("--library-search-available-height", `${Math.max(120, available)}px`)
  }

  paginate(event) {
    const link = event.target.closest(".library-pagination a")
    if (!link || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()
    this.cancel()
    const url = new URL(link.href)
    this.input.focus()
    this.search(url.searchParams.get("query"), url.searchParams.get("page"), url.searchParams.get("batch"))
  }

  query() {
    return this.input.value.trim()
  }

  get input() {
    return this.element.querySelector('input[name="query"]')
  }

  get results() {
    return this.element.ownerDocument.getElementById("library-film-search-results")
  }

  async search(query, page = null, batch = null) {
    const results = this.results
    const request = new AbortController()
    this.request = request
    const url = new URL(this.input.form.action)
    url.searchParams.set("query", query)
    if (page) url.searchParams.set("page", page)
    if (batch) url.searchParams.set("batch", batch)
    this.setLoading(true)

    try {
      const response = await fetch(url, { signal: request.signal })
      const html = await response.text()
      if (request.signal.aborted) return

      if (response.redirected) {
        window.Turbo.visit(response.url)
        return
      }

      const document = new DOMParser().parseFromString(html, "text/html")
      const fragment = document.getElementById(results.id)
      if (!fragment) throw new Error("Missing search results")

      results.replaceChildren(...fragment.childNodes)
      results.hidden = false
      this.fitDropdown()
    } catch {
      if (request.signal.aborted) return

      const alert = results.ownerDocument.createElement("p")
      alert.setAttribute("role", "alert")
      alert.textContent = this.errorValue
      results.replaceChildren(alert)
      results.hidden = false
    } finally {
      if (this.request === request) this.setLoading(false)
    }
  }
}
