# Glutton

Glutton helps viewers discover horror films by learning from what they enjoy. Viewers rate films, optionally add notes, and get recommendations after five distinct films have current ratings with applied quality scores.

## How it works

1. **Ratings** presents one film at a time. Viewers can save a rating and optional film notes, dismiss the prompt, or add the film to their Watchlist. Existing eligible candidates are served oldest first. When Ratings needs a new candidate, TMDB vote count helps it choose films viewers may recognise.
2. **Recommendations** ranks eligible films using the signed contributions of their qualities across the viewer’s current applied rating scores. The selected film stays visible while it remains eligible and unanswered. Accepting it adds it to the Watchlist through Library. Viewers can also reject it or mark it watched. The card shows a trailer when Registry has one.
3. **Library** has Watchlist and Watched poster grids. Viewers can combine rating filters on Watched and open a film to add or revise its rating. Marking a film watched can make it available for rating.

Anonymous visitors can try a read-only preview or explicitly start a guest session. Guests can keep their activity by confirming a registered account.

## Terms used in the project

| Term | Meaning |
| --- | --- |
| **Film** | Registry’s shared record for a specific film, with TMDB metadata and Wikipedia context where available. |
| **Quality** | A characteristic such as slow-burn storytelling or practical effects. Registry records which films exhibit each quality. |
| **Rating** | A viewer’s overall reaction to a film. The four choices are Brilliant, Pretty Good, Not For Me and Garbage. |
| **Film notes / expression** | Film notes are the viewer’s own words about what they liked or disliked. The scoring and profile code uses *expression* for that evidence. |
| **Taste profile** | An interpretation of what the viewer explicitly expressed in their film notes. Ratings can use the profile to interpret other ratings. |
| **Applied quality scores** | The current per-quality contributions for a rating. They can come from direct evidence in notes, profile-informed interpretation, or the baseline rating. A newer profile can trigger reassessment of older ratings. |
| **Dismissal, rejection and suppression** | Dismissal closes a Ratings prompt. Rejection answers a recommendation. Suppression affects eligibility after activity elsewhere, such as adding a film to the Watchlist. |

## System boundaries

Glutton is a Ruby on Rails application with PostgreSQL, server-rendered Phlex views, Tailwind and Hotwire. English application copy lives in Rails locale files.

- **Identity** owns guests, accounts, registration and sessions.
- **Registry** owns canonical films, source metadata and film qualities. Catalogue inspection is available to superusers.
- **Ratings** owns its candidate queue, rating revisions, assessments and taste profiles.
- **Recommendations** owns ranking, selected films and their responses.
- **Library** owns each viewer’s Watchlist and Watched entries.

Domains can read authoritative data across these boundaries. The owning domain handles writes. Durable events coordinate follow-up work, such as turning an accepted recommendation into a Watchlist entry. GoodJob runs event delivery and Ratings processing in the background. See the [event contracts](docs/domain_events.md) and [architecture brief](docs/architecture_brief.md).

## Project guides

- [Product brief](docs/product_brief.md) for the intended viewer experience.
- [Implementation plan](docs/implementation_plan.md) for current progress and release work.
- [Ratings scoring design](docs/ratings_scoring_design.md) for evidence, scoring and reassessment.
- [Development guide](docs/development.md) for setup, configuration and operator commands.

To run locally with PostgreSQL available, use `bin/setup --skip-server` and then `bin/dev`. Run `bin/ci` for the repository checks. See [AGENTS.md](AGENTS.md) before making changes.
