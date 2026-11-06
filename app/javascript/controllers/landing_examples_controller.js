import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "controls", "position", "rotation", "rotationIcon", "dot"]
  static values = { positionTemplate: String }

  connect() {
    this.index = 0
    this.motionPreference = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.paused = this.motionPreference.matches
    this.motionChanged = event => {
      if (event.matches) this.paused = true
      this.start()
    }
    this.motionPreference.addEventListener("change", this.motionChanged)
    this.controlsTarget.hidden = this.panelTargets.length < 2
    this.show()
    this.start()
  }

  disconnect() {
    this.stop()
    this.motionPreference.removeEventListener("change", this.motionChanged)
  }

  select(event) {
    this.index = Number(event.currentTarget.dataset.index)
    this.show()
    this.start()
  }

  next() {
    this.index = (this.index + 1) % this.panelTargets.length
    this.show()
    this.start()
  }

  toggle() {
    this.paused = !this.paused
    this.start()
  }

  resume(event) {
    if (!this.element.contains(event.relatedTarget)) this.start(true)
  }

  start(leavingFocus = false) {
    this.stop()
    this.rotationTarget.setAttribute("aria-label", this.rotationTarget.dataset[this.paused ? "resumeLabel" : "pauseLabel"])
    this.rotationIconTarget.textContent = this.paused ? "▷" : "Ⅱ"
    this.positionTarget.setAttribute("aria-live", this.paused ? "polite" : "off")
    if (this.paused || document.hidden || this.panelTargets.length < 2 || this.element.matches(":hover")) return
    if (leavingFocus !== true && this.element.matches(":focus-within")) return

    this.timer = window.setTimeout(() => this.next(), 10000)
  }

  stop() {
    window.clearTimeout(this.timer)
  }

  show() {
    this.panelTargets.forEach((panel, index) => { panel.hidden = index !== this.index })
    this.dotTargets.forEach((dot, index) => {
      if (index === this.index) dot.setAttribute("aria-current", "true")
      else dot.removeAttribute("aria-current")
    })
    this.positionTarget.textContent = this.positionTemplateValue.replace("%{position}", String(this.index + 1))
  }
}
