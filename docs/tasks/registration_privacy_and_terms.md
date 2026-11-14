# Registration privacy notice and terms acceptance

Status: Draft  
Owner: Identity

## Goal

Before creating an account, viewers can understand how Glutton uses and retains their data and explicitly accept the current Terms of Service.

## Scope

- Make the Privacy Notice and Terms of Service available without signing in. Put both links beside the registration action and make the Privacy Notice available before guest entry.
- Show a short disclosure before registration, including guest upgrades. Explain that closing an account removes sign-in details and ends access, and that Glutton keeps activity such as ratings and notes privately to improve the service. Keep the closure dialog consistent with this disclosure.
- Require an unchecked Terms of Service checkbox at registration. Validate acceptance on the server and record the accepted terms version and timestamp, including when email confirmation upgrades a guest account. Keep the privacy disclosure separate from terms acceptance.
- Draft the notice to match actual practices, including who operates Glutton, privacy contact and rights, data uses and lawful bases, recipients and international transfers, retention periods or criteria, and what happens after account closure. Resolve the basis, purpose and retention period or criteria for keeping closed-account activity before finalising the copy.

## Scope restrictions

- This task covers first-release notices and terms acceptance. It does not add marketing consent, change account closure behaviour, or implement backup restoration.
- Finalise the notice and terms against the launch configuration and obtain owner review of the wording before publication.

## Acceptance criteria

- **AC1:** A signed-out viewer can read both documents. Registration and guest upgrades show the retention disclosure before submission, and guest entry links to the Privacy Notice.  
  Check: Request and browser checks.  
  Result: Not run.
- **AC2:** Registration cannot proceed without explicit terms acceptance, and confirmed accounts carry the accepted version and timestamp.  
  Check: Registration request tests, including omitted acceptance and guest upgrade.  
  Result: Not run.
- **AC3:** The notice and closure dialog accurately describe retention and use of closed-account activity. The notice includes the agreed lawful bases, retention criteria and privacy contact.  
  Check: Review copy against the launch configuration and account closure behaviour.  
  Result: Not run.

## Implementation notes

Not implemented.

Review handoff: Pending.
