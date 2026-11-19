export function fitFilmSearchDropdown(dropdown) {
  if (!dropdown?.getClientRects().length) return

  const available = window.innerHeight - dropdown.getBoundingClientRect().top - 12
  dropdown.style.setProperty("--film-search-available-height", `${Math.max(120, available)}px`)
}
