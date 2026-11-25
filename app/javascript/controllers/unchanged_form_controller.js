import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["save"]
  static values = { baseline: Object, ignored: Array }

  connect() {
    this.update()
  }

  update() {
    const ignored = ["authenticity_token", "_method", ...this.ignoredValue]
    const current = Array.from(new FormData(this.element)).filter(([name]) => !ignored.includes(name))
    const saved = Object.entries(this.baselineValue).flatMap(([name, values]) =>
      [values].flat().map((value) => [name, value]))
    this.saveTarget.disabled = this.element.matches(":invalid") || this.snapshot(current) === this.snapshot(saved)
  }

  snapshot(entries) {
    return entries
      .map(([name, value]) => [name, String(value ?? "").replace(/\r\n/g, "\n").trim()])
      .filter(([, value]) => value !== "")
      .map((entry) => JSON.stringify(entry))
      .sort()
      .join("\n")
  }
}
