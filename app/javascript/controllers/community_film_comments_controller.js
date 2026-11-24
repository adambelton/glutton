import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["controls", "expand", "collapse", "film", "branch", "newReply"]

  connect() {
    if (this.filmTargets.length === 0) return

    this.updateControls()
    this.controlsTarget.hidden = false
  }

  expandAll() {
    this.setOpen(true)
  }

  collapseAll() {
    this.setOpen(false)
  }

  newReplyTargetConnected(reply) {
    delete reply.dataset.communityFilmCommentsTarget
    const branch = reply.closest(".community-comment-replies")
    branch.hidden = false
    for (let disclosure = branch; disclosure; disclosure = disclosure.parentElement.closest("details")) {
      disclosure.open = true
    }
    this.updateControls()
    reply.focus()
  }

  setOpen(open) {
    for (const disclosure of this.disclosures) disclosure.open = open
    this.updateControls()
  }

  updateControls() {
    const disclosures = this.disclosures
    this.expandTarget.disabled = disclosures.every((disclosure) => disclosure.open)
    this.collapseTarget.disabled = disclosures.every((disclosure) => !disclosure.open)
  }

  get disclosures() {
    return [...this.filmTargets, ...this.branchTargets.filter((branch) => !branch.hidden)]
  }
}
