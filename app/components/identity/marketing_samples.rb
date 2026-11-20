module Identity
  module MarketingSamples
    RATINGS = [
      { key: "alien", tmdb_id: 348, rating: ::Ratings::Rating::Values::BRILLIANT },
      { key: "the_thing", tmdb_id: 1091, rating: ::Ratings::Rating::Values::BRILLIANT },
      { key: "the_substance", tmdb_id: 933260, rating: ::Ratings::Rating::Values::PRETTY_GOOD }
    ].freeze

    RECOMMENDATION_MATCHES = { 2671 => 91, 310131 => 87, 1083381 => 82 }.freeze
    RECOMMENDATION_FILM_IDS = RECOMMENDATION_MATCHES.keys.freeze

    WATCHED = [
      { tmdb_id: 348, rating: ::Ratings::Rating::Values::BRILLIANT, notes: true },
      { tmdb_id: 1091, rating: ::Ratings::Rating::Values::BRILLIANT, notes: true },
      { tmdb_id: 933260, rating: ::Ratings::Rating::Values::PRETTY_GOOD, notes: true },
      { tmdb_id: 1233413, rating: nil, notes: false },
      { tmdb_id: 16307, rating: ::Ratings::Rating::Values::BRILLIANT, notes: true },
      { tmdb_id: 2291, rating: ::Ratings::Rating::Values::PRETTY_GOOD, notes: false },
      { tmdb_id: 30497, rating: ::Ratings::Rating::Values::BRILLIANT, notes: true },
      { tmdb_id: 11906, rating: nil, notes: false },
      { tmdb_id: 948, rating: ::Ratings::Rating::Values::BRILLIANT, notes: true },
      { tmdb_id: 814, rating: ::Ratings::Rating::Values::PRETTY_GOOD, notes: true },
      { tmdb_id: 1933, rating: ::Ratings::Rating::Values::PRETTY_GOOD, notes: false },
      { tmdb_id: 9392, rating: ::Ratings::Rating::Values::PRETTY_GOOD, notes: true },
      { tmdb_id: 242224, rating: ::Ratings::Rating::Values::PRETTY_GOOD, notes: false },
      { tmdb_id: 2667, rating: ::Ratings::Rating::Values::NOT_FOR_ME, notes: true },
      { tmdb_id: 60935, rating: ::Ratings::Rating::Values::NOT_FOR_ME, notes: true },
      { tmdb_id: 23437, rating: ::Ratings::Rating::Values::NOT_FOR_ME, notes: false },
      { tmdb_id: 439079, rating: ::Ratings::Rating::Values::NOT_FOR_ME, notes: false },
      { tmdb_id: 250546, rating: ::Ratings::Rating::Values::GARBAGE, notes: true },
      { tmdb_id: 243688, rating: ::Ratings::Rating::Values::GARBAGE, notes: false },
      { tmdb_id: 11618, rating: ::Ratings::Rating::Values::GARBAGE, notes: true }
    ].freeze

    PROFILE_QUALITY_RANKINGS = {
      top: [
        { key: "slow_building_tension", score: 32 },
        { key: "paranoia_and_distrust", score: 30 },
        { key: "practical_creature_effects", score: 28 },
        { key: "believable_environments", score: 25 },
        { key: "human_vulnerability", score: 23 },
        { key: "atmospheric_sound", score: 21 },
        { key: "visual_storytelling", score: 19 },
        { key: "distinctive_creature_design", score: 17 },
        { key: "isolated_settings", score: 15 },
        { key: "ambiguous_mysteries", score: 12 }
      ],
      bottom: [
        { key: "cheap_jump_scares", score: -29 },
        { key: "formulaic_modern_remakes", score: -26 },
        { key: "repetitive_loud_stings", score: -23 },
        { key: "false_alarm_scares", score: -21 },
        { key: "predictable_scare_rhythms", score: -19 },
        { key: "disposable_characters", score: -16 },
        { key: "spectacle_over_atmosphere", score: -14 },
        { key: "excessive_exposition", score: -12 },
        { key: "empty_nostalgia", score: -10 },
        { key: "overexplained_endings", score: -8 }
      ]
    }.freeze

    FILM_IDS = (RATINGS.map { |sample| sample.fetch(:tmdb_id) } + RECOMMENDATION_FILM_IDS + WATCHED.map { |sample| sample.fetch(:tmdb_id) }).uniq.freeze
  end
end
