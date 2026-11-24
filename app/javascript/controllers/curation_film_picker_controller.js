import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "results", "option", "empty", "selected", "selectedSection", "withdrawal"]
  static values = { savedIds: Array }

  initialize() {
    this.removedRows = new Map()
  }

  connect() {
    this.filter()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    const selectedIds = new Set(Array.from(this.selectedTarget.children, (film) => film.dataset.filmId))
    let matching = false

    for (const option of this.optionTargets) {
      const matches = query !== "" &&
        option.dataset.filmTitle.toLocaleLowerCase().includes(query) &&
        !selectedIds.has(option.dataset.filmId)
      option.hidden = !matches
      matching ||= matches
    }

    this.resultsTarget.hidden = !matching
    this.emptyTarget.hidden = query === "" || matching
    this.selectedSectionTarget.hidden = selectedIds.size === 0
    if (this.hasWithdrawalTarget) {
      this.withdrawalTarget.hidden = this.savedIdsValue.every((id) => selectedIds.has(id))
    }
  }

  add(event) {
    const option = event.currentTarget.closest("li")
    const id = option.dataset.filmId
    const row = this.removedRows.get(id) ?? option.querySelector("template").content.firstElementChild.cloneNode(true)
    this.removedRows.delete(id)
    this.selectedTarget.append(row)
    this.searchTarget.value = ""
    this.filter()
    row.querySelector("textarea").focus()
  }

  remove(event) {
    const row = event.currentTarget.closest("li")
    this.removedRows.set(row.dataset.filmId, row)
    row.remove()
    this.filter()
    this.searchTarget.focus()
  }
}
