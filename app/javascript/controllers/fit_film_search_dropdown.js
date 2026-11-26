export function fitFilmSearchDropdown(dropdown) {
  if (!dropdown?.getClientRects().length) return

  if (dropdown.hasAttribute("popover") && dropdown.matches(":popover-open")) {
    fitPopover(dropdown)
    return
  }

  const dialogBottom = dropdown.closest("dialog")?.getBoundingClientRect().bottom ?? window.innerHeight
  const available = Math.min(window.innerHeight, dialogBottom) - dropdown.getBoundingClientRect().top - 12
  dropdown.style.setProperty("--film-search-available-height", `${Math.max(120, available)}px`)
}

function fitPopover(dropdown) {
  const anchor = dropdown.parentElement.getBoundingClientRect()
  const viewport = window.visualViewport
  const viewportTop = viewport?.offsetTop ?? 0
  const viewportBottom = viewportTop + (viewport?.height ?? window.innerHeight)
  const gap = 4
  const edgePadding = 12
  const below = viewportBottom - anchor.bottom - gap - edgePadding
  const above = anchor.top - gap - viewportTop - edgePadding
  const openAbove = below < 160 && above > below

  dropdown.style.left = `${anchor.left}px`
  dropdown.style.width = `${anchor.width}px`
  dropdown.style.setProperty("--film-search-available-height", `${Math.max(0, openAbove ? above : below)}px`)
  const top = openAbove ? anchor.top - gap - dropdown.offsetHeight : anchor.bottom + gap
  dropdown.style.top = `${top}px`
}
