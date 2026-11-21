import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabs", "tab", "panel"]

  connect() {
    const selectedTab = this.tabTargets.find(tab => tab.getAttribute("aria-selected") === "true")
    this.show(selectedTab || this.tabTargets[0])
    this.tabsTarget.hidden = false
  }

  select(event) {
    this.show(event.currentTarget)
  }

  navigate(event) {
    const tabs = this.tabTargets
    const index = tabs.indexOf(event.target)
    const destinations = {
      ArrowLeft: (index + tabs.length - 1) % tabs.length,
      ArrowRight: (index + 1) % tabs.length,
      Home: 0,
      End: tabs.length - 1
    }
    if (!Object.hasOwn(destinations, event.key)) return

    event.preventDefault()
    const tab = tabs[destinations[event.key]]
    this.show(tab)
    tab.focus()
  }

  show(tab) {
    for (const target of this.tabTargets) {
      const selected = target === tab
      target.setAttribute("aria-selected", String(selected))
      target.tabIndex = selected ? 0 : -1
    }
    for (const panel of this.panelTargets) {
      panel.inert = panel.id !== tab.getAttribute("aria-controls")
    }
  }
}
