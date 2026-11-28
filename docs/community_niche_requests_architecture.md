# Community Discovery architecture

Status: Proposed for review  
Updated: 27 November 2026

## Launch scope

The Community plan covers two concrete post types. Build member-created Community Curation first, then system-created Film Debrief. Film search connects a film's discussion to the curations that include it.

The board derives each post’s tag from its type. **Create a Community Curation** is the primary action on the right of the board heading. Published posts show the Community Curation or Film Debrief tag automatically.

The Community post editor opens at `/community/posts/new` and both post types publish through `POST /community/posts` with an explicit post type. A Film Debrief placeholder supplies the film ID during creation. Once published, both types use `/community/posts/:post_id`. Comment actions and reports use the parent post ID and comment ID. Film Debrief access still checks whether the viewer marked the associated film Watched.

In a Community Curation post, a member writes a prompt for a specific horror quality, theme or experience and starts the community list with optional reference films marked Watched in their own Library. The requester is the first endorser for each reference. Members use **Endorse films** to add or endorse several films at a time, with an optional comment per film. Nominated Films is the living discovery artefact, ordered by endorsement count. Each endorsement signals fit with the prompt. Personal enjoyment, ratings and the requester’s Glutton Match are distinct signals.

The launch includes private Library shortcuts, reporting and moderation. Public launch requires [member blocking](#member-blocking) and [moderator suspension of Community access](#community-suspension). Requester selection of films to watch, post-watch outcomes, requester-side Watchlist sharing or filtering, suggestion exclusions based on reference films or the requester’s Watched list, and general member notifications are deferred. Film Debrief follows the initial Community Curation work. Community contributions are separate from private ratings, notes, and Glutton Profiles. The [Community product brief](glutton-community-discovery.md) covers the vocabulary and later product ideas.

## Community onboarding

The Community board, posts, and Account → Community are available to confirmed registered members. The Code of Conduct is public. Moderation is required before public release.

- Publish the **Community Code of Conduct** at release. Make it easy to find in Community and readable before acceptance. It should explain expected conduct, how to respect each discussion’s spoiler rules, how to report problems, and how moderation works.
- Confirmed members can browse and use private Library shortcuts before completing onboarding. Before creating a request, nominating, endorsing, or posting a reply, a member explicitly accepts the code and chooses a public username and avatar. Members pick a Glutton avatar at launch. Custom uploads follow separately. Apply the same gate to Community posting through direct requests and Turbo submissions. Email, credentials, and private activity stay private.
- Community owns `CommunityUser`, the public username and avatar, and the rules for changing them. Members edit their profile in Account → Community and sign in with their Identity email. Usernames use 3–24 ASCII letters, digits or underscores. Keep the member's capitalization, enforce case-insensitive uniqueness in the database, and reserve `admin`, `administrator`, `moderator`, `glutton`, and `support` regardless of case. Posts and published comment content refer to the stable Community profile so a rename updates existing attribution.
- Community owns the code and acceptance policy. Account → Community shows the full current text followed by the acceptance checkbox. The public Code of Conduct shows the current text without a version label and uses the normal header for the viewer’s sign-in state. Identity records the latest accepted version and timestamp on the account, preserving the timestamp for repeated acceptance of the same version. Community then provisions the profile in the same transaction so username and avatar settings are immediately available. A confirmed member must accept the current version before posting.

## Requests

Authors can edit the title and description or confirm permanent deletion until the curation meets a protection threshold. Text edits preserve endorsements, comments and board activity. Protected curations retain their original text and allow an editable additional description and confirmed disassociation. Closing the author's account removes unprotected curations and clears attribution on protected ones.

- A Community Curation post has a short title and a required written discovery prompt. The requester can select any number of optional canonical reference films marked Watched in their own Library. Community verifies each reference again at publication. Each reference creates the requester’s first endorsement for that film when the post is created. The prompt specifies which qualities matter and the references give concrete examples that other members can endorse. The requester can edit the title and description while the request is open and unprotected. Once protected, the title and original description become read-only. The attributed requester can add or edit a single additional description for context or feedback after watching. After publishing, the requester can manage their reference endorsements through the same editor as any other member.
- At launch the Community board shows open requests by most recent activity. Creating a request, nominating a film, endorsing it, or posting a comment or reply updates that order. Edits, removals and withdrawals leave the activity timestamp unchanged. Use a stable tie-break when paginating.
- A requester can withdraw their request. It remains available in a separate archive for eligible members, including its visible threads. Withdrawing stops request edits, new nominations and endorsements, comment edits and new replies. Authors can still remove their own comment text and attribution. Reporting, Community moderation and account deletion still apply. A moderator-hidden request is absent from member lists, archives and direct views.

## Manage endorsements

**Endorse films** opens the editor for a member's first endorsements. **Edit endorsements** opens the same editor with their active films and optional opening comments filled in. Eligible members can select any number of Watched horror films and update their own endorsements in one save. A Watched film can be nominated while Wikipedia context or film qualities are unavailable.

Every member can nominate or endorse only films marked Watched in their own Library. This rule applies to the author's references at publication and to members endorsing films. The Community command rechecks new selections at submission. Previously endorsed films remain manageable after a Library change. Invalid, stale or ineligible changes fail visibly and leave the saved endorsements and comments intact. The composer keeps the remaining eligible selections and their comments for retry. Any future import or Mark Watched entry point retains its own Library and Registry lifecycle.

An endorsement links the request post, canonical film and endorsing member. The first endorsement introduces a film to the list. Further endorsements add to its count, including endorsements of the requester’s references. Nominated Films groups all active endorsements by film and orders the films by count. Each member has at most one active endorsement per film on that request across all submissions. Group the endorsement comments under their film, with replies branching from each comment. Comments and replies leave the count unchanged. A film with zero active endorsements stays on the curation page while it has visible comments.

### Nominated Films artefact

`Community::PostCommunityCuration` owns the post lifecycle. Film Endorsements owns the participation rules and supplies the eligible active endorsements on visible films. After checking access, the Community read workflow passes those contributions to the injected film-count aggregation. The ordered film list presents the result as Nominated Films on the curation page. Include films with surviving discussions even if their endorsement count is zero. A separate artefact, such as a marketing-page list, includes only films with at least one active endorsement. The workflow adds any authorised personal match information for the page.

The full-width post numbers the films in endorsement order. Each row has a poster, an endorsement badge and the shared film title with a muted release year. Each row shows its comment count and starts with comments collapsed. The comment controls sit to the left of the ordering note. Each film and reply branch has its own disclosure and loads comments in batches. Expand comment threads opens the first batch in each reachable branch. Load more comments fetches later batches. Collapse all closes every open disclosure.

## Library actions on nominated films

Any member who can see a nominated film, including the requester and members who have yet to complete onboarding, can use **Add to Watchlist** or **Mark Watched** for their own Library when that action is available. Library owns the transitions and their eligibility, including for films already in the collection. Keep the member in the request flow. These actions affect only the member’s private Library and its existing reactions. They leave nominations, endorsements and request activity as they were.

Show both icons beneath each poster. Use the primary colour for the viewer’s current Library state and tooltips for the available actions and disabled states.

## Endorsement threads

- An endorsement allows one authored root comment at a time. The endorser can add an opening comment in the endorsement editor and edit the published comment inline on the curation. A saved text change shows an edited marker. Use Delete under the published comment to remove just the comment. Deleting the comment’s text frees the slot for a fresh comment under the same conditions. Keep any existing replies attached to the original root. New or edited comments and replies are limited to 4,000 characters across Community. Existing longer comments remain readable and deletable. Use a composer prompt along these lines: “Why do you endorse this film? How does it match what the requester is looking for? Please avoid spoilers.”
- Anyone allowed to read a request can read its visible threads. Anyone allowed to contribute can reply in any open thread on an open request, including the requester. These actions require neither an endorsement nor a Watched entry for the film. Check request and thread state on direct URLs and Turbo updates.
- Replies can be nested. Members can edit their own comments in open threads on open requests. Authors can delete their own comments in both open and archived discussions. Delete the comment row if it has no replies. If it has replies, clear the author and body and render a neutral removal marker. The same rule applies when the removed comment is the root.
- Removing a film from the endorsement editor withdraws that endorsement and deletes its opening comment. A root with replies becomes an unreplyable removal marker. Members can still reply to the surviving comments on an open curation. Re-endorsing creates a fresh endorsement. Its optional opening comment starts a new thread, and previous replies remain under the original marker.
- Keep threads spoiler-free with an instruction at the composer and a **Contains spoilers** report reason. Moderators review reports and can hide the offending content.

## Community board and post types

The board supports Community Curation and Film Debrief. Eligible members create curations. Glutton creates a long-lived Film Debrief post for each film on demand. A future Classic designation would keep a curation permanently open to participation. Scope Classic promotion and its lifecycle rules separately from the Community Curation launch. See the [community discovery brief](glutton-community-discovery.md).

The unfiltered board shows published curations and Film Debriefs together, ordered by latest update. Film Debriefs are visible on the board and at their direct URLs only for films marked Watched in the viewer’s Library. Apply each post’s access and participation rules to board reads and direct routes.

Published posts share a compact heading with the title, badges and attribution above the description. A Film Debrief places its Follow or Following action beside its badge and uses the primary accent to distinguish the action. Its description spans the full width below the poster on mobile.

The Community board uses a paginated two-column grid of cards that stack on narrow screens. Published cards link to their posts. Both card types have a poster-shaped artwork slot on the left. Film Debriefs, debrief placeholders and single-film Curations fill the slot with one poster. Curations with multiple films arrange up to five posters on a 9×9 grid within the same slot. On the right, published cards group a single-line title, badges and attribution on successive rows. Long titles truncate with an ellipsis. The footer holds film, endorsement and comment counts for Curations and a comment count for Film Debriefs. Film Debriefs use a Glutton identity marker with no member account. Eligible viewers see a creation button below the title in a Film Debrief placeholder.

A request post stores its author, title and description. Store comment structure in `comments` and the body and author in `comment_contents`. Removing content can preserve a comment’s structure and replies. Each reply references its post, immediate parent and root comment. The root comment anchors one conversation within the post. The shared discussion capability handles ancestry, bounded reads, comment removal and moderation.

Use single-table inheritance from launch. `Community::Post` is the shared base for the `posts` table and owns the comment relationship. Comments reference that shared table. Follow Identity’s naming convention with the base name first and the concrete role after it.

- `Community::PostCommunityCuration` stores the member’s title and prompt and links any canonical reference films. It owns curation lifecycle and access rules.
- `Community::PostFilmDebrief` is a system-owned post, with at most one per canonical film. An eligible member opens it from a search placeholder. The thread opens directly and renders its introduction from the canonical film title and locale copy. Eligible members can add top-level comments and branching replies, and edit and delete their own contributions. Watched access is required for discussion reads and all thread controls. Deleting a member’s comment preserves the film post and surviving replies.

On each read or write, resolve the owning post and apply its access and lifecycle rules before rendering or changing comments. Shared operations enforce thread ancestry, authorship and comment deletion. The owning workflow supplies eligibility and coordinates writes against current state. This applies to direct requests and Turbo updates as well as navigation from a post.

Film Debrief creation uses a unique film association and checks the existing Community posting rules and Watched status. Film Debriefs use the shared comment storage and reply ancestry rules. Their roots reference the post’s canonical film.

### Community Curation behaviour

Community Curation uses Film Endorsements to enforce participation rules and supply eligible endorsements. The Community read workflow groups those endorsements by canonical film and presents them in the Nominated Films list. Keep the implementation specific to the curation workflow. Revisit a shared `PostDiscovery` abstraction when another member-created post type serves the platform’s discovery goals and has concrete behaviour to share.

### Find curations by film

The board filter matches a visible curation's title, description or any canonical film title in its Nominated Films list. Curation matches include films outside the viewer's Library. One curation appears once even if several of its films match.

During active search, show matching Watched films without a thread first, ordered by film title. Each placeholder offers eligible members a **Create Film Debrief** action. Matching published debriefs follow, then matching curations. Each group of published posts sorts by latest update. Paginate the combined list at ten results per page.

## In-app notifications

The global header shows the inbox bell to viewers who can access Account. Community access applies when the inbox checks which Community items are visible, including for the unread indicator. Account → Community holds private notification settings for confirmed members, including readers without a public profile and members whose participation is suspended.

- Film Debrief preferences cover new top-level comments. Members can independently select Brilliant, Pretty Good, Not for Me, Garbage and Not Rated. All five start unchecked. All and None select or clear the five choices together. Each debrief shows Follow or Following according to the member’s effective preference. Switching to a state that differs from the account default saves a Follow or Mute preference for that post. Returning to the account default removes the post preference. Watched access still applies.
- Discussion preferences cover participation in ongoing comment threads. Direct replies in both post types notify the author of the immediate parent comment by default. Members can turn off direct-reply notifications in their account settings. A Debrief mute applies to new top-level comments. Replies in other branches and a member’s own activity produce no alert.
- Curation preferences cover newly published opening comments. Author alerts default on. Members can opt in to opening comments on films they actively endorse in the same curation. An opening comment produces one item per eligible recipient, including when authored-post and endorsed-film preferences overlap. Endorsements without comments, edits and withdrawals produce no alerts. Disassociation ends author alerts.
- Follow / Following shows the effective opening-comment preference for a whole curation or a visible nominated film. An explicit film choice takes precedence over a curation choice, which takes precedence over Account settings. Turning off an explicit whole-curation follow returns to Account defaults and preserves explicit film choices. Each film choice has its own row, and a row without a film applies to the whole post. Direct replies continue to use the All Posts preference.
- Community enqueues durable delivery with publication. Delivery uses current preferences, blocks and source access. Film Debriefs also use current Watched status and rating. Curation delivery evaluates current authorship and endorsements. Saving settings affects future delivery attempts.
- The inbox list, unread indicator and open action enforce current source visibility. Opening an item marks it read and goes to the comment. Deleting its content removes the item, including when its replies survive. Account closure and restore replay remove private notification state.
- Delivery is in-app. Comment-thread subscriptions, chat and report outcome notifications are separate work.

## Personal match and privacy

Recommendations supplies the same match calculation and evidence gate used on its live card. It reads current Ratings scores and Registry qualities for the nominated films. Community does not apply Recommendation queue exclusions to the list of member nominations. An imported film can be nominated before it has enough evidence for a match.

Every eligible reader can see endorsement totals and their ordering. For the requester only, show each available Glutton Match percentage and identify the top endorsed film and top personal match among active nominations. One nomination can carry both indicators. Use the same unrounded points as Recommendations to determine the match leader among displayable scores, with a stable tie-break. Where evidence is insufficient, use the existing “Limited evidence for a match” message and omit a personal leader if no film qualifies.

Authorisation happens before calculating or serializing match information. Other members receive the same endorsement list without the requester’s match data or match-derived ordering. Thread text, previews and counts respect request visibility and moderation, including in cached fragments. Public contributions never feed the private scoring or profile workflows in this release.

## Moderation and deletion

Build moderation in the existing Rails and PostgreSQL application. Community owns the report queue, moderator authorisation, public profile writes and Community content enforcement. Community owns member blocking and suspension of Community participation. Both are required for public launch. Identity owns accounts, sessions, account closure and restore replay.

### Moderator access

Site superusers can grant and revoke the Community moderator role from a registered member's existing Admin → Users account detail page. The separate Community moderator role gives access to the Community workspace, reports and enforcement. Check current authority on every workspace request and moderation submission, including when a role was revoked after a page was opened. Record who granted or revoked a role and when. Moderator access exposes Community content and report evidence relevant to review, including reported debrief text. Private Library, ratings, notes and Glutton Profiles remain private.

### Reports and decisions

- Members can report a visible whole curation, a published comment or reply, or a public Community profile. Confirm the reporter can see the target at submission, including the Watched requirement for Film Debrief discussions. Allow one open report per reporter and target, including after an edit. Launch has no hourly report limit.
- Post and comment bylines link to a stable public Community profile showing the username and preset avatar. Confirmed members can read and report a profile independently of the discussion they came from. Profiles omit contributions and private account information. The shared Report action captures the username today. Custom avatar evidence can be added when custom avatars are supported.
- Ask the reporter for a plain-language reason and optional explanation. Base the launch reasons and moderator guidance on [Ofcom's illegal-content risk profiles](https://www.ofcom.org.uk/siteassets/resources/documents/online-safety/information-for-industry/illegal-harms/updates/risk-assessment-guidance-and-risk-profiles.pdf?v=419947) and [guidance on content harmful to children](https://www.ofcom.org.uk/online-safety/protecting-children/protection-of-children-duties-under-the-online-safety-act). Keep the submitted reason distinct from the moderation classification and priority.
- Persist each report with its target, reporter, reported member where applicable, submitted reason, optional explanation, time and a snapshot of the reported text. A subsequent edit leaves the report open. Show the reported and current versions together. A moderator can act on a violation in any current reportable field from the same report, including content added or changed since submission. Apply the actions the model permits. Before a destructive decision, lock the source and check that it still matches the reviewed version. If it changed after review, show the latest version in the same report for fresh review.
- Record a durable resolution with the moderator, time, outcome, any action taken and a redacted summary. The submission reason supports prioritisation. The resolution records whether a violation was confirmed.
- Defer member notifications about report outcomes to the notification feature. Handle challenges to moderation decisions through the usual Glutton contact channels.
- Copy the agreed identifying account details into the report at submission. The report preserves the copied evidence and is accessible only to authorised reviewers. Account closure and restore replay leave the copied evidence and identifying details intact for both pending and escalated reports. Clear live account references affected by closure and clear the live source reference if the reported record is deleted. An authorised reviewer can move a pending report to **Escalated** to flag it for further handling. At resolution, remove identifying account details and any source reference or copied text that still identifies someone. Retain relevant anonymised evidence and resolution history indefinitely. Keep report volume, assessed findings and any finding of report misuse distinct. Agree how to anonymise the retained record and verify the policy through account closure and restore replay.
- For confirmed violations, moderators can delete a curation or published comment, or independently remove an attribute explicitly offered by the reportable model. A protected curation's additional description is independently removable. Comment deletion preserves surviving replies. Reversible hiding and restoration would be a separate policy decision.
- Username removal keeps the Community profile and its contributions and displays “Community member” on its bylines. The member can choose another username in Account → Community when they are eligible to participate.

### Report targets

Use a Rails polymorphic `belongs_to :reportable` on the Community-owned report, backed by indexed `reportable_type` and `reportable_id` columns. Use the curation record for a curation report and the published comment content for a comment or reply report. Content report URLs use the post and comment IDs to check access and resolve that content. Profile report URLs use the Community profile ID. Store a snapshot of the whole reportable record's reportable attributes. Keep report history available for authorised review if the live target disappears, subject to the agreed retention and redaction rules.

The post and profile report workflows each own the transaction and authorise and lock the current target before handing it to `ReportSubmission`. A post report locks the reporter first, then the Watched entry for a Film Debrief, the post and any reported comment content. A profile report locks the reporter and profile owner's accounts in account ID order, then the profile. The shared submission operation receives the locked target and reporter and applies the evidence, revision and duplicate rules through the reportable interface.

Use a reusable `Reportable` concern for the inverse `has_many :reports, as: :reportable` association and the reporting behavior shared across explicitly opted-in models. Sources can override the default reasons. Curations offer the spoiler reason, and comments use their parent discussion’s reasons. The form and new-report validation use the same source policy. Each model declares whether moderators can delete its entire record and which reportable attributes they can clear independently. Both permissions default to no deletion. A field must be reportable before the model can offer to clear it. The resolution form uses these declarations to show available actions, and the resolution workflow enforces them under the source lock.

`PostCommunityCuration` allows whole-record deletion and independent removal of `additional_description`. `CommentContent` allows whole-record deletion and preserves surviving replies. Username reporting uses `CommunityUser` as the source and allows clearing `community_username` only. Whole-record deletion remains unavailable through moderation reports for that profile. Community owns report submission and the queue, and checks access to the specific target before taking a snapshot. Resolve the target through trusted application entry points.

### Review priority

The proposed member-facing reasons are threats or immediate safety concerns, sharing someone's private information, harassment, hate or impersonation, sexual abuse or child safety, suicide or self-harm concerns, spam or scams, spoilers in a spoiler-free discussion, and other or unsure.

Show high-risk reports first in the moderation queue. The submitted reason determines initial priority. Treat suspected threats, serious privacy exposure, possible sexual exploitation or child harm, and immediate self-harm risk as priority signals. Review out-of-hours response arrangements during release preparation.

Destructive moderation actions require a moderator decision.

### Member blocking

Member blocking is implemented for public launch.

Members eligible to post can block another member. The member confirms the block on the public profile and can remove it from the dated list in Account → Community. While a block exists in either direction, direct replies and profile access are unavailable to both members. Reject stale reply forms and enforce the block on direct and partial reads. In shared discussions, a neutral marker takes the place of the hidden comment and preserves access to other members' replies. The marker has no link to reveal the comment. Curations remain available with their titles, descriptions, films and aggregate endorsements. Show **Glutton** as the curation byline where the author is blocked for that viewer. Keep the underlying authorship and permissions. Removing the block restores ordinary visibility when neither member has an active block against the other. Members report the other person's profile or comments before blocking. Moderators can still review reports already submitted.

### Community suspension

Community moderators can suspend a member’s public participation from Community moderation or an unresolved report with a live reported member. A moderator lifts the suspension. A suspension blocks public profile edits, publishing, endorsements and changes to posts or discussion. It leaves the account, session, Community reading, private report submission, Library, Ratings and existing contributions available. Community checks suspension inside its account-locked write workflows. Suspension and report resolution are separate actions.

The Community board links to moderation on desktop. Open, Escalated and Resolved use `/community/moderation/reports` with report state in the query string. Active suspensions and Lifted suspensions use `/community/moderation/suspensions` with the lifted state in the query string. Each tab shows up to 20 records per page. Moderators can lift an active suspension from its table row. They can start a suspension from a member’s profile or an eligible report.

The suspended member sees a banner beneath the header on Community pages. The suspension and guest banners overlay the content at 32px on desktop. On mobile they grow to fit and sit above the content in the page flow. Account → Community shows the notice below the tabs with the same amber accent. Both suspension notices link to Glutton’s contact address.

Show the affected member that their Community access is suspended. Point them to the usual Glutton contact channel to challenge the decision.

### Release policy

Glutton is aimed at UK audiences and is available internationally. The launch design uses no geographic restrictions or technical age verification. A self-declared minimum age is an option if a membership age is chosen. Treat children as able to access Community when carrying out the [Ofcom children's access assessment](https://www.ofcom.org.uk/online-safety/illegal-and-harmful-content/childrens-access-assessment-duties-under-the-online-safety-act). Assess illegal-content risks and the reporting, complaints and response arrangements before public release. Assess EU applicability if the service targets EU users or develops a substantial EU user base. See [Ofcom guidance for small services](https://www.ofcom.org.uk/online-safety/illegal-and-harmful-content/helping-small-services-navigate-the-online-safety-act) and [Digital Services Act recitals 7–8](https://eur-lex.europa.eu/legal-content/EN/TXT/?qid=1697614632123&uri=CELEX%3A32022R2065).

### Author and account deletion

- **Request below the threshold.** The author can hard-delete the request, including its endorsements and discussion. Make that consequence explicit before submission. Account deletion also removes these requests.
- **Protected request.** Once enough other members have contributed, the author can remove their attribution directly. Keep the title, original and additional descriptions, and other members’ contributions. Account deletion does the same for protected requests. Moderators can remove a protected request or its independently removable additional description. Disassociation leaves moderation reports and actions applicable to the retained request.
- **Comments and endorsements.** On retained posts, delete a comment outright if it has no replies. Otherwise, remove its body and attribution and preserve those replies. Removing an endorsement comment leaves the endorsement in place. Apply the same comment rule on account deletion. End the member’s active endorsements and archive any conversations attached to them while preserving others’ replies. A film remains in Nominated Films while any active endorsement or visible comment survives. Hosted restore must replay the same account deletion behaviour.
- **Withdrawal.** Withdrawing a request keeps its conversation available as a read-only archive. Withdrawing an endorsement on an open request preserves surviving replies under a removal marker, where members can continue the discussion.

The launch threshold is three distinct other members with active endorsements, or five visible comments from at least two other members. The requester’s reference endorsements contribute to the film totals. The endorsement protection threshold counts other members only. Protection stays in place once reached.

## Domain ownership

| Owner | Launch responsibilities |
| --- | --- |
| **Community** | Public profiles, usernames and avatars, Code of Conduct policy, the board, posting access, discussions, post lifecycle rules, endorsements, reporting, moderator roles, member blocking and suspension of Community access. |
| **Identity** | Accounts, credentials, sessions, the stored conduct receipt, account closure and restore replay. |
| **Registry** | Canonical film search, TMDB-backed horror eligibility, import and existing quality assignment. |
| **Library** | Current collection state and the explicit Add to Watchlist and Mark Watched actions. Community checks Watched state when a contributor nominates or endorses. |
| **Recommendations** | Read-only film match calculation and display eligibility. |
| **Ratings** | Private ratings, notes, applied quality scores and Glutton Profile. Community makes no changes to these records. |

Community Curation and its comments use the existing Rails and PostgreSQL application. Registry import and Library actions are explicit commands owned by their domains. Community orchestrates curation shortcuts, checks its own membership and nominations, and retains return context. Library publishes its existing transition events. See the [boundary index](domain_boundaries.md) for read wiring and transaction ownership.

## Persistence and verification

- Keep requester withdrawal separate from moderator visibility so restoring a hidden archive cannot reopen it. Constrain active endorsements by request, film and account. Enforce at most one root comment with authored content for each endorsement, including under concurrent submissions. Preserve the film association when an endorsement ends so archived conversations stay grouped with the film.
- Within Community, serialize conflicting changes at the request boundary. Check fresh member access and request state before applying writes. Test concurrent endorsements of a film, duplicate endorsements and root comments, and writes against a request that becomes withdrawn or hidden. Repeat checks on direct read routes after withdrawal, suspension, name moderation, and account deletion.
- The proposed representation leaves the parent and root empty on a root comment. A reply stores its parent and the ID of its conversation’s root. Enforce that parent and root belong to the same post and conversation. Decide whether to remove a comment row or clear its body and author under the same post lock used to add replies. A concurrent reply can commit before deletion and be preserved, or arrive after a leaf has been deleted and fail clearly.
- Record request protection as a one-way transition in the same transaction as the contribution that crosses the threshold. Evaluate author edits, deletion and disassociation against fresh state at the same request boundary. Reject replacement of existing text from a stale edit form after protection. Use cascades for children of a hard-deleted request. Preserve report snapshots under the agreed evidence retention rules when moderators delete content.
- Verify ordinary account deletion and backup replay. Check that unprotected requests are gone, protected requests keep their prompt without attribution, and deleted comment text is gone while replies remain. Check that reports, revisions, search data and logs carry no copies of removed text or attribution.
- Keep comment removal and moderation separate from the conversation’s read-only state. Cap indentation in the UI and page large posts and comment trees. Index open request activity, endorsements by request and film, and comments by post and root. Verify that hidden text and private match data stay out of unauthorized HTML, Turbo payloads and shared caches.
- Implementation records should settle exact title and description limits, reference film storage and edit rules, normalization and reserved-name rules, rate limits, and handling of resolved reports and stale targets. Before rollout, update the versioned Privacy Notice for Community content and its deletion behaviour.

## Suggested implementation order

1. **Community — public profile.** Verify username claims and changes in Account, including concurrent claim handling, and support Glutton avatar presets. Custom uploads are separate profile work.
2. **Community — Community Curation creation and initial Nominated Films.** Introduce `Post` and `PostCommunityCuration` on the shared posts table. Verify the entry gate and creation with zero, one and several canonical reference films from the author's Watched list. Reject ineligible references at publication. Each reference enters Nominated Films with one endorsement from the requester. Scope author editing, withdrawal, archive navigation and protected-request lifecycle separately.
3. **Community — respond with film endorsements.** Integrate the existing Registry and Library entry points. Verify several films per response, repeat responses, horror and Watched eligibility, and one grouped film entry under concurrent endorsements. Verify that an endorsement of a reference increases its existing count. Build the shared endorsement editor, including withdrawal, before enabling member responses. Scope post protection separately. Any necessary change to an existing Registry or Library command gets its own narrowly scoped owning task.
4. **Recommendations — read-only match for specified films.** Verify the shared calculation and evidence gate without selecting, enqueueing, or suppressing a recommendation. **Community** separately integrates the requester-only presentation.
5. **Community — discussions and endorsement integration.** Verify that each film in a response can have its own optional root comment, that comments are grouped by film, and that replies branch from their own comment. Verify reply ancestry and preservation after comment removal. Verify that a member can add their one root comment later or after deleting the previous comment while preserving its replies. Verify that other contributors can reply without endorsing and that an archive blocks edits and new replies while allowing comment removal. Verify that new contributions move a request up the list and edits and removals leave the order unchanged.
6. **Community — moderator access.** Scope superuser grant and revoke of the Community moderator role from the Admin account detail page, and guard the Community moderation entry point. Verify a moderator without superuser access can enter the workspace, a superuser without the Community role has no moderation access, and a revoked moderator loses access even in an existing session. Verify that only site superusers can manage role assignments.
7. **Community — reports and content review.** Verify reportable associations, preserved evidence, priority ordering, current-version review, durable resolutions and deletion outcomes. Member blocking is a separate workflow. Check direct requests, concurrent changes, account closure and restore replay.
8. **Community — username moderation.** Verify review of both names, removal of a violating current name from the original report, and fresh review after a further rename.

When implementing posting, apply Community’s current-version acceptance check to the stored Identity receipt and use the Community-owned profile. Verify that each missing prerequisite blocks posting through ordinary controls and direct submissions, and that members can post when all prerequisites are met.

Create and browse Film Debriefs through the Community board and film search. Verify that searching by film finds the accessible debrief and every visible curation where that film appears, including curations that list it as a reference. Scope Film Debrief comments separately.

Scope the nominated-film Library shortcuts as a separate Community integration using Library’s existing commands. Verify both actions through a request, including for its requester and a member who has yet to complete onboarding. Verify that a Library action leaves endorsement counts and request activity intact. Any required change to a Library action belongs in a Library task.

Before enabling curations for members, verify that eligible members can create, contribute to and read curations, that unauthorised submissions are rejected, and that endorsement totals update when an eligible contribution changes. Publish the Code of Conduct and complete the onboarding, moderation and deletion checks.
