# Community Discovery architecture

Status: Proposed for review  
Updated: 23 November 2026

## Launch scope

The Community plan covers two concrete post types. Build member-created Community Curation first, then system-created Film Debrief. Film search connects a film's discussion to the curations that include it.

The board derives each post’s tag from its type. **Create a Community Curation** is the primary action on the right of the board heading. Published posts show the Community Curation or Film Debrief tag automatically.

In a Community Curation post, a member writes a prompt for a specific horror quality, theme or experience and starts the community list with optional reference films marked Watched in their own Library. The requester is the first endorser for each reference. Members use **Endorse films** to add or endorse several films at a time, with an optional comment per film. Nominated Films is the living discovery artefact, ordered by endorsement count. Each endorsement signals fit with the prompt. Personal enjoyment, ratings and the requester’s Glutton Match are distinct signals.

The launch includes private Library shortcuts, reporting and moderation. Requester selection of films to watch, post-watch outcomes, requester-side Watchlist sharing or filtering, suggestion exclusions based on reference films or the requester’s Watched list, notifications and member blocking are deferred. Film Debrief follows the initial Community Curation work. Community contributions are separate from private ratings, notes, and Glutton Profiles. The [Community product brief](glutton-community-discovery.md) covers the vocabulary and later product ideas.

## Community onboarding

During development, the Community page, Community tab in Account and their forms are a superuser preview. Other signed-in users see a Coming soon lock in navigation and Account. The public Code of Conduct remains readable.

- Publish the **Community Code of Conduct** at release. Make it easy to find in Community and readable before acceptance. It should explain expected conduct, how to respect each discussion’s spoiler rules, how to report problems, and how moderation works.
- Confirmed members can browse and use private Library shortcuts before completing onboarding. Before creating a request, nominating, endorsing, or posting a reply, a member explicitly accepts the code and chooses a public username and avatar. Members can pick a Glutton avatar or upload a custom image when eligible. Apply the same gate to Community posting through direct requests and Turbo submissions. Email, credentials, and private activity stay private.
- Identity owns the Community profile. Members choose one editable public username from the Community tab in Account and continue to sign in with email. Usernames use 3–24 ASCII letters, digits or underscores. Keep the member's capitalization, enforce case-insensitive uniqueness in the database, and reserve `admin`, `administrator`, `moderator`, `glutton`, and `support` regardless of case. Use stable account references for authorship so a rename updates existing attribution. A moderator-hidden name displays a generic member label on existing contributions while the member chooses a replacement through Account.
- Community owns the code and acceptance policy. Account → Community shows the full current text followed by the acceptance checkbox. The board points members who still need onboarding to those settings. The public Code of Conduct shows the current text without a version label and uses the normal header for the viewer’s sign-in state. Identity records the latest accepted version and timestamp on the account, preserving the timestamp for repeated acceptance of the same version. Accepting a new version replaces that pair. In Account, accepting the current version unlocks the username and avatar settings and replaces the full text with a brief acceptance reminder and a link to the current text. A confirmed member must also accept the current version before posting.

## Requests

In the superuser preview, authors can edit the title and description or confirm permanent deletion until the curation meets a protection threshold. Text edits preserve endorsements, comments and board activity. Protected curations retain their original text and allow an editable additional description and confirmed disassociation. Closing the author's account removes unprotected curations and clears attribution on protected ones.

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

- An endorsement allows one authored root comment at a time. The endorser can add an opening comment in the endorsement editor and edit the published comment inline on the curation. A saved text change shows an edited marker. Use Delete under the published comment to remove just the comment. Deleting the comment’s text frees the slot for a fresh comment under the same conditions. Keep any existing replies attached to the original root. The opening comment has no character limit. Use a composer prompt along these lines: “Why do you endorse this film? How does it match what the requester is looking for? Please avoid spoilers.”
- Anyone allowed to read a request can read its visible threads. Anyone allowed to contribute can reply in any open thread on an open request, including the requester. These actions require neither an endorsement nor a Watched entry for the film. Check request and thread state on direct URLs and Turbo updates.
- Replies can be nested and have a 1,000-character limit. Members can edit their own comments in open threads on open requests. Authors can delete their own comments in both open and archived discussions. Delete the comment row if it has no replies. If it has replies, clear the author and body and render a neutral removal marker. The same rule applies when the removed comment is the root.
- Removing a film from the endorsement editor withdraws that endorsement and deletes its opening comment. A root with replies becomes an unreplyable removal marker. Members can still reply to the surviving comments on an open curation. Re-endorsing creates a fresh endorsement. Its optional opening comment starts a new thread, and previous replies remain under the original marker.
- Keep threads spoiler-free with an instruction at the composer and a **Contains spoilers** report reason. Moderators review reports and can hide the offending content.

## Community board and post types

The board supports Community Curation and Film Debrief. Eligible members create curations. Glutton creates a long-lived Film Debrief post for each film on demand. A future Classic designation would keep a curation permanently open to participation. Scope Classic promotion and its lifecycle rules separately from the Community Curation launch. See the [community discovery brief](glutton-community-discovery.md).

The unfiltered board shows published curations and Film Debriefs together, ordered by latest update. Film Debriefs are visible on the board and at their direct URLs only for films marked Watched in the viewer’s Library. Apply each post’s access and participation rules to board reads and direct routes.

The Community board uses a paginated two-column grid of cards that stack on narrow screens. Published cards link to their posts. Both card types have a poster-shaped artwork slot on the left. The right column starts with a single-line title that truncates with an ellipsis. Published cards show badges on the next line. Eligible viewers see a creation button on that line in a debrief placeholder. Debriefs and their placeholders show a single poster. Curations arrange up to five film posters on a 9×9 grid within the same slot. Curation cards show film, endorsement and comment counts above the author. Published Film Debriefs show a comment count above a Glutton identity marker. Glutton has no member account for that marker.

A request post stores its author, title and description. Store comment structure in `comments` and the body and author in `comment_contents`. Removing content can preserve a comment’s structure and replies. Each reply references its post, immediate parent and root comment. The root comment anchors one conversation within the post. The shared discussion capability handles ancestry, bounded reads, comment removal and moderation.

Use single-table inheritance from launch. `Community::Post` is the shared base for the `posts` table and owns the comment relationship. Comments reference that shared table. Follow Identity’s naming convention with the base name first and the concrete role after it.

- `Community::PostCommunityCuration` stores the member’s title and prompt and links any canonical reference films. It owns curation lifecycle and access rules.
- `Community::PostFilmDebrief` is a system-owned post, with at most one per canonical film. An eligible member opens it from a search placeholder. The thread opens directly and renders its introduction from the canonical film title and locale copy. The discussion follow-up will let eligible members add top-level comments and branching replies. The Watched rule applies to both. Deleting a member’s comment will preserve the film post and surviving replies.

On each read or write, resolve the owning post and apply its access and lifecycle rules before rendering or changing comments. Shared operations enforce thread ancestry, authorship and comment deletion. The owning workflow supplies eligibility and coordinates writes against current state. This applies to direct requests and Turbo updates as well as navigation from a post.

Film Debrief creation uses a unique film association and checks the existing Community posting rules and Watched status. The shared comment storage and reply ancestry rules also apply when Film Debrief discussion is added.

### Community Curation behaviour

Community Curation uses Film Endorsements to enforce participation rules and supply eligible endorsements. The Community read workflow groups those endorsements by canonical film and presents them in the Nominated Films list. Keep the implementation specific to the curation workflow. Revisit a shared `PostDiscovery` abstraction when another member-created post type serves the platform’s discovery goals and has concrete behaviour to share.

### Find curations by film

The board filter matches a visible curation's title, description or any canonical film title in its Nominated Films list. Curation matches include films outside the viewer's Library. One curation appears once even if several of its films match.

During active search, show matching Watched films without a thread first, ordered by film title. Each placeholder offers eligible members a **Create Film Debrief** action. Matching published debriefs follow, then matching curations. Each group of published posts sorts by latest update. Paginate the combined list at ten results per page.

## Personal match and privacy

Recommendations supplies the same match calculation and evidence gate used on its live card. It reads current Ratings scores and Registry qualities for the nominated films. Community does not apply Recommendation queue exclusions to the list of member nominations. An imported film can be nominated before it has enough evidence for a match.

Every eligible reader can see endorsement totals and their ordering. For the requester only, show each available Glutton Match percentage and identify the top endorsed film and top personal match among active nominations. One nomination can carry both indicators. Use the same unrounded points as Recommendations to determine the match leader among displayable scores, with a stable tie-break. Where evidence is insufficient, use the existing “Limited evidence for a match” message and omit a personal leader if no film qualifies.

Authorisation happens before calculating or serializing match information. Other members receive the same endorsement list without the requester’s match data or match-derived ordering. Thread text, previews and counts respect request visibility and moderation, including in cached fragments. Public contributions never feed the private scoring or profile workflows in this release.

## Moderation and deletion

Revisit member blocking only if a concrete need emerges.

Build a Community moderator role for launch. The owner can grant and revoke it. Moderators can perform all planned Community moderation actions, including reviewing reports and hidden reported content, hiding and restoring content, moderating public names and avatars, restricting custom avatar uploads, and suspending Community access. The owner manages role assignments.

Community owns moderation authorization and serves the moderation workspace, report queue and role management UI outside site Admin. Authorize moderation through the Community role on both page loads and direct submissions. Site superuser authority is independent. Moderators gain access to Community moderation data and public profile targets relevant to reports. Private Library, ratings, notes and profiles stay private.

Members can report visible requests, nominations, individual comments, display names and custom avatars.

Review custom avatars in response to reports and copyright notices. Sensitive imagery and other Code of Conduct violations are the primary moderation concern because avatars appear alongside posts throughout Community. Give members a clear way to report an avatar for a conduct violation. Agree the specific content rules in the Code of Conduct before release.

A moderator can disable the specific upload under review. A report about a replaced avatar targets the reported upload. A disabled image becomes unavailable through its old URL, including cached copies Glutton controls. Glutton displays one of its avatars as the fallback. A moderator can also restrict a member to Glutton avatars when the circumstances warrant it. Apply the fallback if their current avatar is custom and enforce the restriction on upload and avatar selection, including direct submissions. The member can choose another Glutton avatar and participate under the ordinary access rules. Decide Community suspension separately. A report or copyright notice goes through review before any member-level restriction is applied.

Publish the copyright contact email where rights holders can find it without a Community account. Include this notice in the Code of Conduct:

> Custom avatars may be subject to copyright infringement notices. If we receive a complaint about your avatar, we may remove it.

Hide a request or a nominated film as a unit. For film-level moderation, use the request and canonical film as the target. Store the visibility decision against that pair so it applies to the whole group, including its comment trees, independently of any single endorsement. Hide an individual comment in place so eligible readers can still see surviving replies. A hidden display name uses a generic label. A stale report about a replaced name must not let a moderator hide the replacement. Suspension blocks Community access without changing a member’s Identity session or private film workflows. Existing contributions remain unless separately moderated. Apply server-side rate limits to posting and reporting. Keep report details and moderation records in the authorized Community workspace.

### Author and account deletion

- **Request below the threshold.** The author can hard-delete the request, including its endorsements and discussion. Make that consequence explicit before submission. Account deletion also removes these requests.
- **Protected request.** Once enough other members have contributed, the author can remove their attribution directly. Keep the title, original and additional descriptions, and other members’ contributions. Account deletion does the same for protected requests. Moderator hiding remains reversible. Disassociation leaves any moderation reports and actions applicable to the retained request.
- **Comments and endorsements.** On retained posts, delete a comment outright if it has no replies. Otherwise, remove its body and attribution and preserve those replies. Removing an endorsement comment leaves the endorsement in place. Apply the same comment rule on account deletion. End the member’s active endorsements and archive any conversations attached to them while preserving others’ replies. A film remains in Nominated Films while any active endorsement or visible comment survives. Hosted restore must replay the same account deletion behaviour.
- **Withdrawal.** Withdrawing a request keeps its conversation available as a read-only archive. Withdrawing an endorsement on an open request preserves surviving replies under a removal marker, where members can continue the discussion.

The launch threshold is three distinct other members with active endorsements, or five visible comments from at least two other members. The requester’s reference endorsements contribute to the film totals. The endorsement protection threshold counts other members only. Protection stays in place once reached.

### Moderating protected request text

The additional description can contain abuse even when the original prompt is intact. The proposed moderation flow lets a moderator review and hide it independently. If the original body itself contains abuse or sensitive information, consider a moderator-reviewed redaction or replacement that preserves the context needed by the surviving discussion. An AI-assisted draft is an option to evaluate separately. Ordinary disassociation keeps the request text.

## Domain ownership

| Owner | Launch responsibilities |
| --- | --- |
| **Community** | Code of Conduct and acceptance, the board, posting access, shared discussion threads and comments, post lifecycle rules, requests and endorsements, reporting, moderator roles, moderation UI and authorization, content moderation and suspensions. |
| **Identity** | Confirmed account access and sessions, public profile name and avatar, name uniqueness and rename, disabling names and avatar uploads, member-level custom avatar eligibility, and account deletion and restore replay. |
| **Registry** | Canonical film search, TMDB-backed horror eligibility, import and existing quality assignment. |
| **Library** | Current collection state and the explicit Add to Watchlist and Mark Watched actions. Community checks Watched state when a contributor nominates or endorses. |
| **Recommendations** | Read-only film match calculation and display eligibility. |
| **Ratings** | Private ratings, notes, applied quality scores and Glutton Profile. Community makes no changes to these records. |

Implement Community Curation and its comment layer in the existing Rails and PostgreSQL application. Registry import and Library actions are explicit user commands, with the request page coordinating the steps and retaining return context. Community reads shared authoritative data and writes its own records. Use the existing Library events for its transitions. This launch design requires no new Community event contract.

## Persistence and verification

- Keep requester withdrawal separate from moderator visibility so restoring a hidden archive cannot reopen it. Constrain active endorsements by request, film and account. Enforce at most one root comment with authored content for each endorsement, including under concurrent submissions. Preserve the film association when an endorsement ends so archived conversations stay grouped with the film.
- Within Community, serialize conflicting changes at the request boundary. Check fresh member access and request state before applying writes. Test concurrent endorsements of a film, duplicate endorsements and root comments, and writes against a request that becomes withdrawn or hidden. Repeat checks on direct read routes after withdrawal, suspension, name moderation, and account deletion.
- The proposed representation leaves the parent and root empty on a root comment. A reply stores its parent and the ID of its conversation’s root. Enforce that parent and root belong to the same post and conversation. Decide whether to remove a comment row or clear its body and author under the same post lock used to add replies. A concurrent reply can commit before deletion and be preserved, or arrive after a leaf has been deleted and fail clearly.
- Record request protection as a one-way transition in the same transaction as the contribution that crosses the threshold. Evaluate author edits, deletion and disassociation against fresh state at the same request boundary. Reject replacement of existing text from a stale edit form after protection. Use cascades for children of a hard-deleted request. Hiding a comment for moderation keeps its content available for authorized review and restoration.
- Verify ordinary account deletion and backup replay. Check that unprotected requests are gone, protected requests keep their prompt without attribution, and deleted comment text is gone while replies remain. Check that reports, revisions, search data and logs carry no copies of removed text or attribution.
- Keep comment removal and moderation separate from the conversation’s read-only state. Cap indentation in the UI and page large posts and comment trees. Index open request activity, endorsements by request and film, and comments by post and root. Verify that hidden text and private match data stay out of unauthorized HTML, Turbo payloads and shared caches.
- Implementation records should settle exact title and description limits, reference film storage and edit rules, normalization and reserved-name rules, rate limits, and handling of resolved reports and stale targets. Before rollout, update the versioned Privacy Notice for Community content and its deletion behaviour.

## Suggested implementation order

1. **Identity — Community profile.** Start with username claims and changes in Account, including concurrent claim handling. Add Glutton presets and custom uploads as separate profile work. Verify the generic label and replacement flow for a hidden name when profile moderation is implemented.
2. **Community — Community Curation creation and initial Nominated Films.** Introduce `Post` and `PostCommunityCuration` on the shared posts table. Verify the entry gate and creation with zero, one and several canonical reference films from the author's Watched list. Reject ineligible references at publication. Each reference enters Nominated Films with one endorsement from the requester. Scope author editing, withdrawal, archive navigation and protected-request lifecycle separately.
3. **Community — respond with film endorsements.** Integrate the existing Registry and Library entry points. Verify several films per response, repeat responses, horror and Watched eligibility, and one grouped film entry under concurrent endorsements. Verify that an endorsement of a reference increases its existing count. Build the shared endorsement editor, including withdrawal, before enabling member responses. Scope post protection separately. Any necessary change to an existing Registry or Library command gets its own narrowly scoped owning task.
4. **Recommendations — read-only match for specified films.** Verify the shared calculation and evidence gate without selecting, enqueueing, or suppressing a recommendation. **Community** separately integrates the requester-only presentation.
5. **Community — discussions and endorsement integration.** Verify that each film in a response can have its own optional root comment, that comments are grouped by film, and that replies branch from their own comment. Verify reply ancestry and preservation after comment removal. Verify that a member can add their one root comment later or after deleting the previous comment while preserving its replies. Verify that other contributors can reply without endorsing and that an archive blocks edits and new replies while allowing comment removal. Verify that new contributions move a request up the list and edits and removals leave the order unchanged.
6. **Community — moderator access.** Scope owner grant and revoke, including how the first owner is identified, and guard the Community moderation entry point. Verify a moderator without superuser access can enter the workspace, a superuser without the Community role has no moderation access, and a revoked moderator loses access even in an existing session. Verify owner-only role management.
7. **Community and Identity — safety and deletion.** Scope Community reporting, content moderation and suspension separately from the Identity-owned actions on public names and avatars. Invoke those profile actions from the Community moderation UI. Verify that reports target the specific upload and disabling it serves a Glutton avatar and revokes direct access to the image. Verify that a member-level upload restriction blocks custom images while allowing preset selection and otherwise eligible posting. Verify cascade and restore replay against Community data before launch. Verify the full journey with a requester, two endorsers, an ineligible reader and a Community moderator.

When implementing posting, use Community’s current-version acceptance check and the Identity-owned profile. Verify that each missing prerequisite blocks posting through ordinary controls and direct submissions, and that members can post when all prerequisites are met.

Create and browse Film Debriefs through the Community board and film search. Verify that searching by film finds the accessible debrief and every visible curation where that film appears, including curations that list it as a reference. Scope Film Debrief comments separately.

Scope the nominated-film Library shortcuts as a separate Community integration using Library’s existing commands. Verify both actions through a request, including for its requester and a member who has yet to complete onboarding. Verify that a Library action leaves endorsement counts and request activity intact. Any required change to a Library action belongs in a Library task.

Before enabling curations for members, verify that eligible members can create, contribute to and read curations, that unauthorised submissions are rejected, and that endorsement totals update when an eligible contribution changes. Publish the Code of Conduct and complete the onboarding, moderation and deletion checks.
