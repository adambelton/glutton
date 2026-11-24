import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body"]

  connect() {
    this.bodyTarget.focus()
  }

  cancel(event) {
    const frame = this.element.closest("turbo-frame")
    const mode = this.element.dataset.commentComposerTrigger
    const source = frame.closest(".community-comment") || frame.previousElementSibling
    const trigger = source?.querySelector(`[data-comment-composer-trigger="${mode}"]`)
    if (!trigger) return

    event.preventDefault()
    frame.replaceChildren()
    trigger.focus()
  }
}
