# Targeted rating browser destination

Ratings provides the destination for a future Library “Rate this film” link. Library UI wiring belongs to task 020. No catalogue-browsing screen is added.

## Link contract

Use `new_rating_path(film_id: film_id)`, which generates `GET /ratings/new?film_id=<id>`. Omit `film_id` (`new_rating_path`) to present the next eligible candidate from the automatic queue. Both modes use Ratings::RatingsController#new. The optional argument uses the Rails snake_case name `film_id` and is the shared internal Film ID, not a LibraryFilm or RatingFilm ID. The current signed session supplies the user; callers must not pass an owner ID.

Opening the explicit destination finds or creates the session owner’s RatingFilm before displaying the rating/expression form. This GET admission is explicitly owner-approved: leaving the form unfinished retains an eligible candidate for a later queue session. Repeated entry reuses the same row without changing timestamps, held or dismissed. Existing Ratings holds or dismissal do not prevent explicit rating. The film does not need a Ratings candidate before the request; Ratings admits it on entry, so the link works before Library event delivery. Ratings neither queries Library nor requires a watched record.

Outcomes:

- `200`: form for the selected film, with a return-to-queue link.
- `401`: signed-out/expired/revoked session, with sign-in/registration links. No guest is created.
- `410`: existing deleted-account response.
- `404`: missing/malformed Film ID, with the localized unavailable response.
- `409`: the user already rated the film, with an explicit message and queue link. Replacement is not supported yet.

## Form submission

Both forms post to `ratings_path` (`POST /ratings`) through Ratings::RatingsController#create, with a Rails CSRF token, required hidden `rating_film_id`, `value` and optional `expression_texts[]`. Existing Rating::Values and expression limits apply. Blank browser fields are omitted; nonblank strings are preserved exactly. Expression parameters are filtered from logs. The candidate ID is scoped to the session owner. User IDs, Film IDs and state attributes cannot redirect ownership or mutate candidate state.

GET entry uses Ratings::PrepareCandidate under the fresh active-owner lock to find or create the candidate. Submission uses Ratings::SubmitRating and requires an existing owned RatingFilm. It never admits or recreates candidates. Rating, expressions and event commit atomically; failed validation/publication leaves the previously admitted candidate available. Existing held/dismissed flags and creation time remain unchanged. The unchanged RatingSubmitted v1 fact is published atomically; Library responds asynchronously.

Success returns `303` to `new_rating_path` with the saved notice. Validation returns `422` with the selected film, choice and valid-shaped text preserved. Duplicate submission returns `409`; identity and film failures use the outcomes above. All responses retain no-store handling, and Rails enforces CSRF on submission. No untrusted return URL is accepted.

Automatic selection still respects pending eligibility. Dismissal is handled by Ratings::RatingsController#dismiss: POST `/ratings/dismiss` (`dismiss_ratings_path`) with a CSRF token and `rating_film_id`. The service resolves the candidate for the session owner; foreign/missing candidates return 404 and repeated dismissal returns 409. There is no separate candidate controller or queue rating submission endpoint. This destination does not implement Library links, rating replacement, candidate replenishment or anonymous first-use discovery.

Controller/service boundary: RatingsController validates parameter shape/format and translates failures into HTTP responses. PrepareCandidate, SubmitRating and Dismiss own entity existence/ownership/freshness checks; model actions own permissions. PrepareCandidate rejects an already-rated entry. On invalid submission, FindCandidate loads the existing owned candidate under a fresh active-owner lock for rendering; it does not admit a candidate. Missing/deleted/foreign candidates remain unavailable rather than being recreated.
