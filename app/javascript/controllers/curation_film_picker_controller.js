import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "results", "option", "empty", "selected", "selectedSection"]

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
  }

  add(event) {
    const option = event.currentTarget.closest("li")
    const row = option.querySelector("template").content.firstElementChild.cloneNode(true)
    this.selectedTarget.append(row)
    this.searchTarget.value = ""
    this.filter()
    row.querySelector("textarea").focus()
  }

  remove(event) {
    event.currentTarget.closest("li").remove()
    this.filter()
    this.searchTarget.focus()
  }
}
