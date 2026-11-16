# Horror launch manifest

Audit date · 2026-11-15

The [launch manifest](horror_launch_manifest.json) contains 5,020 unique TMDB movie IDs in selection order. Each film is a released title classified as Horror by TMDB and has at least one recorded current access route in the UK, Ireland, US, Canada, Australia or New Zealand. Licensed digital access and sourceable physical media count across eras. Current general theatrical bookings also qualify. Watch-provider data comes from JustWatch via TMDB. Links record the provider or booking evidence for the market. [TMDB discovery](https://developer.themoviedb.org/reference/discover-movie) · [TMDB watch providers](https://developer.themoviedb.org/reference/movie-watch-providers)

## Selection

- Started with 3,200 widely rated films. TMDB vote count is a proxy for familiarity. Popularity breaks vote-count ties.
- Kept researched and development films that met the access and source checks, including 366 verified winners and 495 titles already in the local development database. 667 manifest films link back by title and TMDB ID to the [research master list](horror_catalogue_master_list.md).
- Filled the rest from TMDB discovery, sampling eras and languages in rounds. The selection has 432 films with 25 or fewer TMDB votes, 1,527 with a known non-English original language, and 83 recorded origin countries across co-productions.
- Used 40 minutes as the bulk feature-length floor. The 57-minute *Host* (2020) qualifies. Resolved the research list’s ambiguous titles to specific editions. Separate remakes can qualify on their own TMDB record. 102 prior access holds remain outside the manifest. A current UK Blu-ray listing cleared the hold on *The Seventh Curse*.

### Reddit and Letterboxd omission review

The original selection covered 91 of 100 films in Dreadit’s anniversary poll and 221 of 250 in Letterboxd’s official horror list. The nine Dreadit omissions lacked TMDB’s Horror classification. The review added 19 eligible titles from Letterboxd and Reddit, with their recommendation sources in the research master list. The original 5,000 IDs retain their order. [Dreadit poll](https://www.reddit.com/r/horror/comments/ufqeyz/) · [Letterboxd Top 250](https://letterboxd.com/official/list/top-250-horror-films/)

*Godzilla Minus Zero* qualifies through current general US theatrical bookings. *Bramayugam* was added after a UK subscriber confirmed playback on SonyLIV. [US showtimes](https://www.atomtickets.com/movies/godzilla-minus-zero/379219) · [SonyLIV Malayalam listing](https://www.sonyliv.com/movies/bramayugam-malayalam-1500005591)

## Access and theatrical release

Markets overlap. One current route is enough for selection. A festival or premiere entry supplies no current access. Recheck the source when preparing an import batch, since availability can change.

| Market | Films with an access route |
| --- | --- |
| US | 4,838 |
| GB | 4,074 |
| CA | 4,299 |
| AU | 3,476 |
| IE | 3,499 |
| NZ | 2,939 |

The manifest carries the earliest past TMDB theatrical release of type 2 or 3 after filtering explicit festival notes. For 364 titles the field is empty. Those titles have qualifying access through another route. Historical non-TMDB exceptions in the research list retain their separate citations. [TMDB release dates](https://developer.themoviedb.org/reference/movie-release-dates)

| Release decade | Films |
| --- | --- |
| 1910s | 3 |
| 1920s | 26 |
| 1930s | 50 |
| 1940s | 61 |
| 1950s | 138 |
| 1960s | 328 |
| 1970s | 415 |
| 1980s | 506 |
| 1990s | 357 |
| 2000s | 806 |
| 2010s | 1,367 |
| 2020s | 963 |

## Registry import preflight

5,020 films have a TMDB Wikidata ID that resolves to a matching English Wikipedia article. The manifest records 234 researched, development or widely rated candidates with an unresolved English Wikipedia source identity outside the selected films. This preflight checked article identity. The Registry importer still checks the article revision and source paragraphs before persistence. [Registry import workflow](../development.md)

Read `films[].tmdb_id` as the ordered ID list. Use the Registry import workflow in bounded batches, with the existing deployment and assessment settings. Check the target Registry for existing IDs before loading a batch. The `present_in_development` flag describes the local snapshot.
