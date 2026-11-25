export function fitFilmSearchDropdown(dropdown) {
  if (!dropdown?.getClientRects().length) return

  const dialogBottom = dropdown.closest("dialog")?.getBoundingClientRect().bottom ?? window.innerHeight
  const available = Math.min(window.innerHeight, dialogBottom) - dropdown.getBoundingClientRect().top - 12
  dropdown.style.setProperty("--film-search-available-height", `${Math.max(120, available)}px`)
}
