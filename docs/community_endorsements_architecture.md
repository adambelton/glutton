# Community Endorsements architecture

Status: Proposed for review  
Updated: 21 November 2026

## Launch scope

Endorsement requests are the first post type on the Community board. A member describes the horror experience they want. Other members nominate films, endorse existing nominations, and discuss films in endorsement threads. The requester sees both community support and their own Glutton Match.

The current launch scope covers asking, nominating, endorsing and discussing, with private Library shortcuts, reporting and moderation. Structured film selection and post-watch outcomes, requester-side Watchlist sharing or filtering, exclusion of films the requester has seen, notifications, member blocking, and Film Debrief are deferred. Community contributions are separate from private ratings, notes, and Glutton Profiles. The [social and community direction](glutton-social-community-direction.md) covers the vocabulary and later product ideas.

## Community onboarding

During development, the Community page, Community tab in Account and their forms are a superuser preview. Other signed-in users see a Coming soon lock in navigation and Account. The public Code of Conduct remains readable.

- Publish the **Community Code of Conduct** at release. Make it easy to find in Community and readable before acceptance. It should explain expected conduct, spoiler etiquette in Endorsements, how to report problems, and how moderation works.
- Confirmed members can browse and use private Library shortcuts before completing onboarding. Before creating a request, nominating, endorsing, or posting a reply, a member explicitly accepts the code and chooses a public username and avatar. Members can pick a Glutton avatar or upload a custom image when eligible. Apply the same gate to Community posting through direct requests and Turbo submissions. Email, credentials, and private activity stay private.
- Identity owns the Community profile. Members choose one editable public username from the Community tab in Account and continue to sign in with email. Usernames use 3–24 ASCII letters, digits or underscores. Keep the member's capitalization, enforce case-insensitive uniqueness in the database, and reserve `admin`, `administrator`, `moderator`, `glutton`, and `support` regardless of case. Use stable account references for authorship so a rename updates existing attribution. A moderator-hidden name displays a generic member label on existing contributions while the member chooses a replacement through Account.
- Community owns the code, acceptance and posting access. Account and Community use the same acceptance form, and any reader can open the code at its versioned URL. A confirmed member explicitly accepts the current version before they can post. Keep earlier acceptances as history, record the first timestamp for each version, and remove the history when the account is deleted.

## Requests

- A request has a short title and a free-text description. The requester can edit both while it is open and unprotected. Once protected, requester edits are append-only. Keep the title and existing content intact and show additions as labelled updates, including feedback after watching. The requester cannot nominate or endorse on their own request.
- At launch the Community board shows open requests by most recent activity. Creating a request, nominating a film, endorsing it, or posting a comment or reply updates that order. Edits, removals and withdrawals leave the activity timestamp unchanged. Use a stable tie-break when paginating.
- A requester can withdraw their request. It remains available in a separate archive for eligible members, including its visible threads. Withdrawing stops request edits, new nominations and endorsements, comment edits and new replies. Authors can still remove their own comment text and attribution. Reporting, Community moderation and account deletion still apply. A moderator-hidden request is absent from member lists, archives and direct views.

## Nominate and endorse

The contributor searches Glutton’s catalogue or TMDB from the request. Only films TMDB classifies as horror are eligible. Registry verifies the film and resolves or imports its canonical film ID. A valid film can be nominated while Wikipedia context or film qualities are unavailable.

The contributor must have a Library Watched entry when nominating or endorsing. Offer the explicit **Mark Watched** action in the flow when it is missing. This uses the Library-owned action and requires no rating or notes. The contributor returns to their draft and submits the nomination or endorsement. The Community command rechecks eligibility for the open request and the canonical film. If the request closes after import or Mark Watched, report that the contribution could not be added. The member’s explicit Library action and the canonical import have their own lifecycles.

An endorsement links the request post, canonical film and endorsing member. **Nominate a Film** is the member-facing action for introducing a film through an endorsement. All endorsements use the same action and rules. Nominated Films groups active endorsements by film within the request and orders the films by count. Each member has at most one active endorsement for that film on that request. Opening comments and replies leave the count unchanged. If a film loses its final endorsement, keep any archived discussion reachable from the request below the active list.

## Library actions on nominated films

Any member who can see a nominated film, including the requester and members who have yet to complete onboarding, can use **Add to Watchlist** or **Mark Watched** for their own Library when that action is available. Library owns the transitions and their eligibility, including for films already in the collection. Keep the member in the request flow. These actions affect only the member’s private Library and its existing reactions. They leave nominations, endorsements and request activity as they were.

## Endorsement threads

- An endorsement allows one authored root comment at a time. The endorser can include it when endorsing or add it later while the endorsement and request remain open. Deleting the comment’s text frees the slot for a fresh comment under the same conditions. Keep any existing replies attached to the original root. The opening comment has no character limit. Use a composer prompt along these lines: “Why do you endorse this film? How does it match what the requester is looking for? Please avoid spoilers.”
- Anyone allowed to read a request can read its visible threads. Anyone allowed to contribute can reply in any open thread on an open request, including the requester. These actions require neither an endorsement nor a Watched entry for the film. Check request and thread state on direct URLs and Turbo updates.
- Replies can be nested and have a 1,000-character limit. Members can edit their own comments in open threads on open requests. Authors can delete their own comments in both open and archived discussions. Delete the comment row if it has no replies. If it has replies, clear the author and body and render a neutral removal marker. The same rule applies when the removed comment is the root.
- Withdrawing an endorsement closes its entire thread to comment edits and new replies and keeps all existing comments visible under a “This endorsement has been removed” notice. Show archived threads below open threads on the nomination. The member can still read and reply in other open threads, where their existing comments stay visible. A later endorsement may start a new thread and leaves the original archived.
- Keep threads spoiler-free with an instruction at the composer and a **Contains spoilers** report reason. Moderators review reports and can hide the offending content.

## Community board and post types

The preferred direction is one Community board that can show endorsement requests and Film Debrief posts together. Launch with endorsement requests on that board. When scoping Film Debrief, decide how to order and filter the mixed list and whether to show spoiler-safe entries to members who have yet to mark the film Watched. Each post type supplies its own access and participation rules to both board reads and direct routes.

A request post stores its author, title and description. A comment can retain its structure after the body and author are cleared. Each reply references its post, immediate parent and root comment. The root comment anchors one conversation within the post. The shared discussion capability handles ancestry, bounded reads, comment removal and moderation.

Use single-table inheritance from launch. `Community::Post` is the shared base for the `posts` table and owns the comment relationship. Comments reference that shared table. Follow Identity’s naming convention with the base name first and the concrete role after it.

- **Endorsements** launches with `Community::PostEndorsementRequest`. The subtype owns request access and lifecycle rules. Each root comment is linked to the endorsement that permits it. The endorsement supplies its film and whether the conversation is open for edits and replies. Post replies create root comments under this rule. Replies to comments inherit the root and need no endorsement of their own.
- **Film Debrief** adds `Community::PostFilmDebrief` later, with at most one system-created post per canonical film. Create it on demand with the first root comment. Render the introductory copy from the canonical film title and Rails locale strings. Deleting a member’s comment preserves the film post and replies. Members with a Watched entry for the film can read its contents and create multiple root comments and branching replies. The Watched rule applies to both post replies and comment replies.

On each read or write, resolve the owning post and apply its access and lifecycle rules before rendering or changing comments. Shared operations enforce thread ancestry, authorship and comment deletion. The owning workflow supplies eligibility and coordinates writes against current state. This applies to direct requests and Turbo updates as well as navigation from a post.

Build the shared mechanics needed by endorsement threads in the first release. Add Film Debrief routes, storage for the unique film association, and its Watched policy when that feature is scoped.

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
- **Protected request.** Once enough other members have contributed, the author can remove their attribution directly. Keep the title, description, updates and other members’ contributions. Account deletion does the same for protected requests. Moderator hiding remains reversible. Disassociation leaves any moderation reports and actions applicable to the retained request.
- **Comments and endorsements.** On retained posts, delete a comment outright if it has no replies. Otherwise, remove its body and attribution and preserve those replies. Removing an endorsement comment leaves the endorsement in place. Apply the same comment rule on account deletion. End the member’s active endorsements and archive any conversations attached to them while preserving others’ replies. A film remains in Nominated Films while another member endorses it. Hosted restore must replay the same account deletion behaviour.
- **Withdrawal.** Withdrawing a request or endorsement keeps the conversation available as a read-only archive.

The launch threshold is three distinct other members with active endorsements, or five visible comments from at least two other members. Protection stays in place once reached.

### Moderating protected request text

An appended update can contain abuse even when the original prompt is intact. The proposed moderation flow lets a moderator review and hide that update independently. If the original body itself contains abuse or sensitive information, consider a moderator-reviewed redaction or replacement that preserves the context needed by the surviving discussion. An AI-assisted draft is an option to evaluate separately. Ordinary disassociation keeps the request text.

## Domain ownership

| Owner | Launch responsibilities |
| --- | --- |
| **Community** | Code of Conduct and acceptance, the board, posting access, shared discussion threads and comments, post lifecycle rules, requests and endorsements, reporting, moderator roles, moderation UI and authorization, content moderation and suspensions. |
| **Identity** | Confirmed account access and sessions, public profile name and avatar, name uniqueness and rename, disabling names and avatar uploads, member-level custom avatar eligibility, and account deletion and restore replay. |
| **Registry** | Canonical film search, TMDB-backed horror eligibility, import and existing quality assignment. |
| **Library** | Current collection state and the explicit Add to Watchlist and Mark Watched actions. Community checks Watched state when a contributor nominates or endorses. |
| **Recommendations** | Read-only film match calculation and display eligibility. |
| **Ratings** | Private ratings, notes, applied quality scores and Glutton Profile. Community makes no changes to these records. |

Implement Community Endorsements and its comment layer in the existing Rails and PostgreSQL application. Registry import and Library actions are explicit user commands, with the request page coordinating the steps and retaining return context. Community reads shared authoritative data and writes its own records. Use the existing Library events for its transitions. This launch design requires no new Community event contract.

## Persistence and verification

- Keep requester withdrawal separate from moderator visibility so restoring a hidden archive cannot reopen it. Constrain active endorsements by request, film and account. Enforce at most one root comment with authored content for each endorsement, including under concurrent submissions. Preserve the film association when an endorsement ends so archived conversations stay grouped with the film.
- Within Community, serialize conflicting changes at the request boundary. Check fresh member access and request state before applying writes. Test concurrent endorsements of a film, duplicate endorsements and root comments, and writes against a request that becomes withdrawn or hidden. Repeat checks on direct read routes after withdrawal, suspension, name moderation, and account deletion.
- The proposed representation leaves the parent and root empty on a root comment. A reply stores its parent and the ID of its conversation’s root. Enforce that parent and root belong to the same post and conversation. Decide whether to remove a comment row or clear its body and author under the same post lock used to add replies. A concurrent reply can commit before deletion and be preserved, or arrive after a leaf has been deleted and fail clearly.
- Record request protection as a one-way transition in the same transaction as the contribution that crosses the threshold. Evaluate author edits, deletion and disassociation against fresh state at the same request boundary. Reject replacement of existing text from a stale edit form after protection. Use cascades for children of a hard-deleted request. Hiding a comment for moderation keeps its content available for authorized review and restoration.
- Verify ordinary account deletion and backup replay. Check that unprotected requests are gone, protected requests keep their prompt without attribution, and deleted comment text is gone while replies remain. Check that reports, revisions, search data and logs carry no copies of removed text or attribution.
- Keep comment removal and moderation separate from the conversation’s read-only state. Cap indentation in the UI and page large posts and comment trees. Index open request activity, endorsements by request and film, and comments by post and root. Verify that hidden text and private match data stay out of unauthorized HTML, Turbo payloads and shared caches.
- Implementation records should settle exact title and description limits, normalization and reserved-name rules, rate limits, and handling of resolved reports and stale targets. Before rollout, update the versioned Privacy Notice for Community content and its deletion behaviour.

## Suggested implementation order

1. **Identity — Community profile.** Start with username claims and changes in Account, including concurrent claim handling. Add Glutton presets and custom uploads as separate profile work. Verify the generic label and replacement flow for a hidden name when profile moderation is implemented.
2. **Community — request and archive lifecycle.** Introduce `Post` and `PostEndorsementRequest` on the shared posts table. Verify the entry gate, author editing before protection, append-only updates after protection, withdrawal, access, and list and archive navigation. Verify each threshold path, disassociation and concurrent submissions at the protection boundary.
3. **Community — film endorsements.** Integrate the existing Registry and Library entry points. Verify horror and Watched eligibility on submission, one grouped film entry under concurrent endorsements, and withdrawal. Any necessary change to an existing Registry or Library command gets its own narrowly scoped owning task.
4. **Recommendations — read-only match for specified films.** Verify the shared calculation and evidence gate without selecting, enqueueing, or suppressing a recommendation. **Community** separately integrates the requester-only presentation.
5. **Community — discussions and endorsement integration.** Verify reply ancestry and preservation after comment removal. Verify that a member can add their one root comment with an endorsement, later, or after deleting the previous comment while preserving its replies. Verify that other contributors can reply without endorsing and that an archive blocks edits and new replies while allowing comment removal. Verify that new contributions move a request up the list and edits and removals leave the order unchanged.
6. **Community — moderator access.** Scope owner grant and revoke, including how the first owner is identified, and guard the Community moderation entry point. Verify a moderator without superuser access can enter the workspace, a superuser without the Community role has no moderation access, and a revoked moderator loses access even in an existing session. Verify owner-only role management.
7. **Community and Identity — safety and deletion.** Scope Community reporting, content moderation and suspension separately from the Identity-owned actions on public names and avatars. Invoke those profile actions from the Community moderation UI. Verify that reports target the specific upload and disabling it serves a Glutton avatar and revokes direct access to the image. Verify that a member-level upload restriction blocks custom images while allowing preset selection and otherwise eligible posting. Verify cascade and restore replay against Community data before launch. Verify the full journey with a requester, two endorsers, an ineligible reader and a Community moderator.

The Code of Conduct and acceptance are a Community slice. When implementing posting, use the current-version acceptance record and the Identity-owned profile. Verify that each missing prerequisite blocks posting through ordinary controls and direct submissions, and that members can post when all prerequisites are met.

Scope the nominated-film Library shortcuts as a separate Community integration using Library’s existing commands. Verify both actions through a request, including for its requester and a member who has yet to complete onboarding. Verify that a Library action leaves endorsement counts and request activity intact. Any required change to a Library action belongs in a Library task.

Publish the Code of Conduct and complete the onboarding, moderation and deletion checks before enabling Community for members.
