# Read-only retrieval hardening pattern

Use this when adding a data-reading feature adjacent to side-effecting personal-assistant actions.

## Core rule

Read-only retrieval is not the same class as a mutation action. Do not route it through a preview/approval queue unless it will actually mutate external state.

Examples:
- summarizing latest email: read-only retrieval
- listing calendar availability: read-only retrieval
- sending/replying/deleting/marking email: mutation action
- creating/updating/deleting calendar event: mutation action

## Implementation pattern

1. Add an explicit backend-only enable flag and provider selector.
2. Fail closed when provider config is missing: tell the user the integration is not connected.
3. Route the retrieval intent before stale side-effect draft state so old Calendar/WhatsApp state cannot steal the request.
4. Keep mutation verbs out of the read-only matcher.
5. Do not create `actionId`, pending action metadata, or confirmation prompts for retrieval-only answers.
6. Add a queue guard rejecting accidental future payloads for the retrieval feature.
7. Smoke providers with safe metadata only: status, counts, lengths, boolean classification checks, and secret-pattern checks — never raw private records.

## Tests to require

- request classifier recognizes read-only phrasing
- mutation phrasing does not match
- missing config returns truthful no-connection response without pending action
- configured provider returns bounded output
- stale state from a previous draft cannot hijack the retrieval request
- action queue rejects accidental retrieval payloads
- unsafe provider base URLs are rejected before network calls

## Delayed voice route evidence

If the live voice route has a short soft timeout, a retrieval response may arrive via delayed notification. Valid evidence is:

- initial route returns `pendingTurnId`
- scoped notification drain with `conversationId` + `turnId` receives a response
- response metadata/booleans prove it is the expected retrieval class
- no action id, confirmation, stale side-effect language, or secret pattern appears
