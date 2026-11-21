import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "rating", "clear"]

  connect() {
    this.view = "watchlist"
    this.ratings = new Set()
    this.refresh()
  }

  changeView(event) {
    this.view = event.currentTarget.value
    this.refresh()
  }

  filter(event) {
    const rating = event.currentTarget.value
    if (this.ratings.has(rating)) this.ratings.delete(rating)
    else this.ratings.add(rating)
    this.refresh()
  }

  clear() {
    this.ratings.clear()
    this.refresh()
  }

  refresh() {
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.view !== this.view
      let hasMatches = false
      panel.querySelectorAll(".library-film").forEach(card => {
        const rating = card.querySelector("[data-sample-rating]")?.dataset.sampleRating
        const matchesRating = panel.dataset.view === "watchlist" || this.ratings.size === 0 || this.ratings.has(rating)
        card.hidden = !matchesRating
        hasMatches ||= matchesRating
      })
      panel.querySelector(".library-preview-empty").hidden = hasMatches
    })
    this.ratingTargets.forEach(button => {
      const selected = this.ratings.has(button.value)
      button.setAttribute("aria-pressed", String(selected))
      if (selected) button.dataset.selected = "true"
      else delete button.dataset.selected
    })
    this.clearTarget.disabled = this.ratings.size === 0
  }
}
