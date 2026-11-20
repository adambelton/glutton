import { Controller } from "@hotwired/stimulus"
import { fitTmdbFilmSearchDropdown } from "controllers/fit_tmdb_film_search_dropdown"

export default class extends Controller {
  static targets = ["form", "input", "clearButton", "results"]

  connect() {
    this.fitDropdown()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  schedule(event) {
    clearTimeout(this.timer)
    if (event?.isComposing) return
    this.resultsTarget.hidden = true
    const hasQuery = this.inputTarget.value.trim().length > 0
    this.clearButtonTarget.hidden = !hasQuery
    if (hasQuery) this.timer = setTimeout(() => this.formTarget.requestSubmit(), 350)
  }

  submit(event) {
    clearTimeout(this.timer)
    if (this.inputTarget.value.trim().length === 0) {
      event.preventDefault()
    } else {
      this.useCatalogueContext(event)
    }
  }

  useCatalogueContext(event) {
    const context = new URL(window.location.href).searchParams
    event.target.elements.namedItem("q").value = context.get("q") ?? ""
    event.target.elements.namedItem("page").value = context.get("page") ?? "1"
  }

  displayResults() {
    const query = this.resultsTarget.querySelector("[data-tmdb-query]")?.dataset.tmdbQuery
    this.resultsTarget.hidden = query === undefined || query.trim() !== this.inputTarget.value.trim()
    this.fitDropdown()
  }

  fitDropdown() {
    fitTmdbFilmSearchDropdown(this.resultsTarget.querySelector(".film-search-dropdown"))
  }

  clear(event) {
    event.preventDefault()
    this.inputTarget.value = ""
    this.schedule()
    this.inputTarget.focus()
  }
}
