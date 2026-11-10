# Targeted rating browser destination

Library links to the Ratings-owned destination below for first rating and replacement. The shared Film ID identifies the film; the current session identifies the owner.

## Link contract

Use `new_rating_path(film_id: film_id)`, which generates `GET /rating/new?film_id=<id>`. Omit `film_id` (`new_rating_path`) to present the next eligible candidate from the automatic queue. Both modes use RatingsController#new. The optional argument uses the Rails snake_case name `film_id` and is the shared internal Film ID, not a LibraryFilm or RatingFilm ID. The current signed session supplies the user; callers must not pass an owner ID.

Opening the explicit destination finds or creates the session owner’s RatingFilm before displaying the rating form. This GET admission is explicitly owner-approved: leaving the form unfinished retains an eligible candidate for a later queue session. Repeated entry reuses the same row without changing timestamps, held or dismissed. Existing Ratings holds or dismissal do not prevent explicit rating. The film does not need a Ratings candidate before the request; Ratings admits it on entry, so the link works before Library event delivery. Ratings neither queries Library nor requires a watched record.

Outcomes:

- `200`: form for the selected film, with a return-to-queue link.
- `401`: signed-out/expired/revoked session, with sign-in/registration links. No guest is created.
- `410`: existing deleted-account response.
- `404`: missing/malformed Film ID, with the localized unavailable response.
- `409`: the user already rated the film, with an explicit message and queue link. Use the separate editing destination below for replacement.

## Form submission

Both forms post to `rating_path` (`POST /rating`) through RatingsController#create, with a Rails CSRF token, required hidden `rating_film_id`, `value` and optional `notes`. Existing Rating::Values and notes length limit apply. Blank notes are stored as absent. Nonblank notes retain whitespace and paragraph breaks with normalized line endings. Notes are filtered from logs. The candidate ID is scoped to the session owner. User IDs, Film IDs and state attributes cannot redirect ownership or mutate candidate state.

GET entry uses Ratings::CandidateSelection::PrepareCandidate under the fresh active-owner lock to find or create the candidate. Submission uses Ratings::RatingRecording::SubmitRating and requires an existing owned RatingFilm. It never admits or recreates candidates. Rating with notes and event commit atomically; failed validation/publication leaves the previously admitted candidate available. Existing held/dismissed flags and creation time remain unchanged. The unchanged RatingSubmitted v1 fact is published atomically; Library responds asynchronously.

Success returns `303` to `new_rating_path` with the saved notice. Validation returns `422` with the selected film, choice and valid-shaped text preserved. The targeted form submits a presentation flag so validation retains the return-to-queue link and omits Dismiss. Ownership still comes from the session and candidate ID. Duplicate submission returns `409`; identity and film failures use the outcomes above. All responses retain no-store handling, and Rails enforces CSRF on submission. No untrusted return URL is accepted.

Automatic selection still respects pending eligibility. Dismissal is handled by RatingsController#dismiss: POST `/rating/dismiss` (`dismiss_rating_path`) with a CSRF token and `rating_film_id`. The service resolves the candidate for the session owner; foreign/missing candidates return 404 and repeated dismissal returns 409. There is no separate candidate controller or queue rating submission endpoint. This first-rating destination does not implement Library links, candidate replenishment or anonymous first-use discovery.

Controller/service boundary: RatingsController validates parameter shape/format and translates failures into HTTP responses. PrepareCandidate, SubmitRating and Dismiss own entity existence/ownership/freshness checks; model actions own permissions. PrepareCandidate rejects an already-rated entry. On invalid submission, FindCandidate loads the existing owned candidate under a fresh active-owner lock for rendering; it does not admit a candidate. Missing/deleted/foreign candidates remain unavailable rather than being recreated.


## Editing an existing rating

Use `edit_rating_path(film_id: film_id)` (`GET /rating/edit?film_id=<shared Film ID>`). RatingsController#edit reads the session owner's existing candidate and latest rating, even when held or dismissed, without admitting candidates or changing state. Missing/malformed/foreign candidates return 404; an owned unrated candidate returns 409. Identity failures retain 401/410 handling. Library can link here in its own future task; this task adds an edit link after first submission in Ratings.

The shared form submits `PATCH /rating` with `rating_film_id`, `previous_rating_id`, `value`, `notes` and CSRF token. IDs are parsed as positive integers at the HTTP boundary. The previous ID identifies the rating displayed to the viewer. `Ratings::RatingRecording::ReviseRating` locks/reloads the active owner and owned candidate and delegates full replacement to the model. Success preserves historical evidence, saves the new notes, publishes no event, and redirects with 303 to the same film's edit page. Clearing the field saves a revision without notes.

Validation failures return 422 with safe submitted values and the original expected previous ID preserved. A malformed/missing/stale previous ID or replay returns 409 with a link to reload the current rating. Reload is explicit; neither error redisplay nor resubmission silently adopts a newer revision. Missing/foreign/deleted candidates remain 404. The caller cannot select a different owner or arbitrary redirect destination. Responses remain no-store and all application copy is localized.

The same revision flow edits the notes.
