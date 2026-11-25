import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["controls", "expand", "collapse", "film", "branch", "newReply", "loader"]

  initialize() {
    this.pendingLoads = new WeakMap()
  }

  connect() {
    this.updateControls()
  }

  disconnect() {
    this.expansion = null
  }

  filmTargetConnected() {
    this.updateControls()
  }

  filmTargetDisconnected() {
    this.updateControls()
  }

  branchTargetConnected() {
    this.updateControls()
  }

  branchTargetDisconnected() {
    this.updateControls()
  }

  loaderTargetDisconnected() {
    this.updateControls()
  }

  toggle(event) {
    const disclosure = event.currentTarget
    const initialPage = disclosure.querySelector(":scope > .community-comment-loader[data-initial-page='true']")
    if (disclosure.open && initialPage && !this.expansion) this.load(initialPage)
    this.updateControls()
  }

  loadMore(event) {
    this.load(event.currentTarget.closest(".community-comment-loader"), true)
  }

  load(loader, focus = false) {
    const pending = this.pendingLoads.get(loader)
    if (pending) return pending

    const request = this.fetchPage(loader, focus).finally(() => this.pendingLoads.delete(loader))
    this.pendingLoads.set(loader, request)
    return request
  }

  async fetchPage(loader, focus) {
    const button = loader.querySelector("button")
    const error = loader.querySelector("[role='alert']")
    button.disabled = true
    error.hidden = true
    try {
      const response = await fetch(loader.dataset.discussionUrl)
      if (!response.ok || response.redirected) throw new Error("Discussion request failed")

      const template = document.createElement("template")
      template.innerHTML = await response.text()
      if (!loader.isConnected) return false

      const existingIds = new Set(Array.from(loader.parentElement.children, (element) => element.id))
      for (const thread of Array.from(template.content.children)) {
        if (thread.classList.contains("community-comment-thread") && existingIds.has(thread.id)) thread.remove()
      }
      const nextFocus = template.content.querySelector(".community-comment, .community-comment-loader button")
      loader.replaceWith(template.content)
      if (focus && nextFocus) {
        if (nextFocus.classList.contains("community-comment")) nextFocus.tabIndex = -1
        nextFocus.focus()
      }
      return true
    } catch {
      error.hidden = false
      return false
    } finally {
      button.disabled = false
    }
  }

  async expandAll() {
    const expansion = Symbol()
    const failed = new Set()
    this.expansion = expansion
    try {
      while (this.expansion === expansion) {
        this.setOpen(true)
        const loader = this.initialPages.find((page) => !failed.has(page))
        if (!loader) break
        if (!await this.load(loader)) failed.add(loader)
      }
    } finally {
      if (this.expansion === expansion) this.expansion = null
      this.updateControls()
    }
  }

  collapseAll() {
    this.expansion = null
    this.setOpen(false)
  }

  newReplyTargetConnected(reply) {
    delete reply.dataset.communityFilmCommentsTarget
    const branch = reply.closest(".community-comment-replies")
    if (branch) branch.hidden = false
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
    if (!this.hasControlsTarget) return

    const disclosures = this.disclosures
    this.controlsTarget.hidden = disclosures.length === 0
    this.expandTarget.disabled = Boolean(this.expansion) ||
      (this.initialPages.length === 0 && disclosures.every((disclosure) => disclosure.open))
    this.collapseTarget.disabled = disclosures.every((disclosure) => !disclosure.open)
  }

  get disclosures() {
    return [...this.filmTargets, ...this.branchTargets.filter((branch) => !branch.hidden)]
  }

  get initialPages() {
    return this.loaderTargets.filter((loader) => loader.dataset.initialPage === "true")
  }
}
