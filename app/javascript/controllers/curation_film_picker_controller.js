import { Controller } from "@hotwired/stimulus"
import { fitFilmSearchDropdown } from "controllers/fit_film_search_dropdown"

const PAGE_SIZE = 5

export default class extends Controller {
  static targets = ["search", "clear", "results", "option", "empty", "previous", "page", "next", "selected", "selectedSection", "withdrawal"]
  static values = { savedIds: Array, pageLabel: String }

  initialize() {
    this.removedRows = new Map()
    this.page = 1
  }

  connect() {
    this.filter()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    const selectedIds = new Set(Array.from(this.selectedTarget.children, (film) => film.dataset.filmId))
    const options = this.optionTargets
    const matches = query === "" ? [] : options.filter((option) =>
      option.dataset.filmTitle.toLocaleLowerCase().includes(query) && !selectedIds.has(option.dataset.filmId))
    const totalPages = Math.max(1, Math.ceil(matches.length / PAGE_SIZE))
    this.page = Math.min(Math.max(1, this.page), totalPages)
    const start = (this.page - 1) * PAGE_SIZE
    const visibleOptions = new Set(matches.slice(start, start + PAGE_SIZE))
    for (const option of options) option.hidden = !visibleOptions.has(option)

    this.clearTarget.hidden = this.searchTarget.value === ""
    this.resultsTarget.hidden = query === ""
    this.emptyTarget.hidden = query === "" || matches.length > 0
    this.previousTarget.hidden = this.page === 1
    this.nextTarget.hidden = this.page === totalPages
    this.pageTarget.textContent = this.pageLabelValue.replace("{number}", this.page).replace("{total}", totalPages)
    fitFilmSearchDropdown(this.resultsTarget)
    this.selectedSectionTarget.hidden = selectedIds.size === 0
    if (this.hasWithdrawalTarget) {
      this.withdrawalTarget.hidden = this.savedIdsValue.every((id) => selectedIds.has(id))
    }
  }

  searchChanged() {
    this.showPage(1)
  }

  previousPage() {
    const hadFocus = this.previousTarget === document.activeElement
    this.showPage(this.page - 1)
    if (hadFocus && this.previousTarget.hidden) this.nextTarget.focus()
  }

  nextPage() {
    const hadFocus = this.nextTarget === document.activeElement
    this.showPage(this.page + 1)
    if (hadFocus && this.nextTarget.hidden) this.previousTarget.focus()
  }

  showPage(page) {
    this.page = page
    this.filter()
    this.resultsTarget.querySelector(".film-search-content").scrollTop = 0
  }

  dismiss(event) {
    if (this.resultsTarget.hidden) return

    event.preventDefault()
    this.searchTarget.focus()
    this.resultsTarget.hidden = true
  }

  dismissOutside(event) {
    if (event.relatedTarget && !event.currentTarget.contains(event.relatedTarget)) this.resultsTarget.hidden = true
  }

  clear() {
    this.searchTarget.value = ""
    this.searchChanged()
    this.searchTarget.focus()
  }

  add(event) {
    const option = event.currentTarget.closest("li")
    const id = option.dataset.filmId
    const row = this.removedRows.get(id) ?? option.querySelector("template").content.firstElementChild.cloneNode(true)
    this.removedRows.delete(id)
    this.selectedTarget.append(row)
    this.searchTarget.value = ""
    this.searchChanged()
    row.querySelector("textarea, a")?.focus()
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  remove(event) {
    const row = event.currentTarget.closest("li")
    this.removedRows.set(row.dataset.filmId, row)
    row.remove()
    this.filter()
    this.searchTarget.focus()
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
