import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body"]

  connect() {
    this.bodyTarget.focus()
  }

  cancel(event) {
    const frame = this.element.closest("turbo-frame")
    const replyLink = frame.closest(".community-comment")?.querySelector(`[data-turbo-frame="${frame.id}"]`)
    if (!replyLink) return

    event.preventDefault()
    frame.replaceChildren()
    replyLink.focus()
  }
}
