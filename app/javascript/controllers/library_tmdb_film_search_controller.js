import { Controller } from "@hotwired/stimulus"
import { fitTmdbFilmSearchDropdown } from "controllers/fit_tmdb_film_search_dropdown"

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
      this.clearResults()
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
    if (this.element.contains(this.results)) fitTmdbFilmSearchDropdown(this.results)
  }

  paginate(event) {
    const link = event.target.closest(".library-pagination a")
    if (!link || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()
    this.cancel()
    const url = new URL(link.href)
    this.input.focus()
    this.search(url.searchParams.get("query"), url.searchParams)
  }

  async selectFilm(event) {
    const selectionForm = event.target
    if (!selectionForm.matches("[data-library-tmdb-selection]")) return

    event.preventDefault()
    const selectionUrl = selectionForm.action
    const requestOptions = {
      method: selectionForm.method,
      body: new FormData(selectionForm),
      headers: { Accept: "text/html" }
    }

    this.cancel()
    this.input.value = ""
    this.clearResults()
    this.input.focus({ preventScroll: true })

    try {
      const response = await fetch(selectionUrl, requestOptions)
      const responseHtml = await response.text()
      if (!this.element.isConnected) return

      if (response.status === 401) {
        window.Turbo.visit(window.location.href)
        return
      }

      this.applySelectionFeedback(responseHtml)
    } catch {
      if (this.element.isConnected) this.displaySelectionError(this.errorValue)
    }
  }

  applySelectionFeedback(responseHtml) {
    // The shared form endpoint returns HTML, with Rails flash messages after a redirect.
    const responseDocument = new DOMParser().parseFromString(responseHtml, "text/html")
    const feedback = [...responseDocument.querySelectorAll(".ui-notifications > .ui-toast, .ui-notifications > .ui-alert")]

    if (feedback.length === 0) {
      const searchError = responseDocument.querySelector("#library-film-search-results [role=alert]")
      this.displaySelectionError(searchError?.textContent ?? this.errorValue)
      return
    }

    const notificationArea = this.element.ownerDocument.querySelector(".ui-notifications")
    notificationArea?.append(...feedback)
    const saved = feedback.some((message) => message.classList.contains("ui-toast"))
    if (saved) this.reloadCollection()
  }

  clearResults() {
    this.results.replaceChildren()
    this.results.hidden = true
  }

  displaySelectionError(message) {
    const document = this.element.ownerDocument
    const alert = document.createElement("p")
    alert.setAttribute("role", "alert")
    alert.className = "ui-alert"
    alert.textContent = message
    document.querySelector(".ui-notifications")?.append(alert)
  }

  reloadCollection() {
    const frame = this.element.ownerDocument.getElementById("library-collection-results")
    if (frame.src) frame.reload()
    else frame.src = window.location.href
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

  async search(query, parameters = "") {
    const results = this.results
    const request = new AbortController()
    this.request = request
    const url = new URL(this.input.form.action)
    url.search = parameters
    url.searchParams.set("query", query)
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
