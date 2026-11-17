module MarketingCatalogue
  FILMS = {
    348 => [ "Alien", 1979 ], 1091 => [ "The Thing", 1982 ],
    933260 => [ "The Substance", 2024 ], 1233413 => [ "Sinners", 2025 ],
    16307 => [ "The Wicker Man", 1973 ], 2291 => [ "Jacob's Ladder", 1990 ],
    30497 => [ "The Texas Chain Saw Massacre", 1974 ], 11906 => [ "Suspiria", 1977 ],
    948 => [ "Halloween", 1978 ], 814 => [ "An American Werewolf in London", 1981 ],
    1933 => [ "The Others", 2001 ], 9392 => [ "The Descent", 2005 ],
    242224 => [ "The Babadook", 2014 ], 2667 => [ "The Blair Witch Project", 1999 ],
    60935 => [ "The Thing", 2011 ], 23437 => [ "A Nightmare on Elm Street", 2010 ],
    439079 => [ "The Nun", 2018 ], 250546 => [ "Annabelle", 2014 ],
    243688 => [ "Poltergeist", 2015 ], 11618 => [ "The Haunting", 1999 ],
    2671 => [ "Ring", 1998 ], 310131 => [ "The Witch", 2016 ], 1083381 => [ "Backrooms", 2026 ]
  }.freeze
  TRAILERS = { 2671 => "yAmO3vanfDQ", 310131 => "97OQ7MQC5Ck", 1083381 => "0HjdiohVOik" }.freeze

  def create_preview_catalogue(except: [], poster_paths: {})
    FILMS.each do |tmdb_id, (title, year)|
      next if except.include?(tmdb_id)

      details = { poster_path: poster_paths.fetch(tmdb_id, "/poster.jpg") }
      key = TRAILERS[tmdb_id]
      details[:videos] = { results: [ { site: "YouTube", type: "Trailer", official: true, key: } ] } if key.present?
      Registry::Film.create!(tmdb_id:, title:, release_date: Date.new(year, 1, 1), tmdb_metadata: { details: })
    end
  end
end
