# Async Test Flakes: Fixed Sleeps vs Background Side Effects

Use this when tests intermittently fail around delayed replies, background queues, notification drains, local bridge calls, or worker timers.

## Symptom pattern

- Test does `await sleep(40/80/120ms)` then asserts a background side effect exists.
- Failure is intermittent and reruns pass.
- Assertion sees “not yet” state, e.g. notification length `0`, send call count `0`, health probe count `0`.
- The implementation uses timers/promises/queues such as `setTimeout`, `promise.then(...)`, async executor, HTTP bridge call, or queued notification.

## Root-cause workflow

1. Read the exact failing assertion and note the expected vs observed value.
2. Trace the side effect path from request/command to the asserted state.
3. Identify all async boundaries: soft timeout, background promise continuation, executor timer, fetch/HTTP handler, notification queue, drain endpoint.
4. Calculate the nominal timing margin. Small margins are not reliable under CI/event-loop load.
5. Check if the observation endpoint is destructive. Drain-once endpoints require preserving the body returned by the poll that observed success.
6. Fix the test wait strategy before changing production code, unless tracing shows real product behavior is wrong.

## Preferred test helper shape

```ts
async function waitFor<T>(
  read: () => Promise<T> | T,
  predicate: (value: T) => boolean,
  options: { timeoutMs?: number; intervalMs?: number } = {},
): Promise<T> {
  const timeoutMs = options.timeoutMs ?? 1500
  const intervalMs = options.intervalMs ?? 10
  const deadline = Date.now() + timeoutMs
  let lastValue: T | undefined

  while (true) {
    lastValue = await read()
    if (predicate(lastValue)) return lastValue
    if (Date.now() >= deadline) return lastValue
    await new Promise((resolve) => setTimeout(resolve, intervalMs))
  }
}
```

For drain-once endpoints:

```ts
const drainedBody = await waitFor(
  () => drainNotifications(server, conversationId),
  (body) => body.notifications.length === 1,
)
assert.equal(drainedBody.notifications.length, 1)
```

Do not poll until success and then fetch again from a drain-once endpoint; the successful poll may have consumed the state.

## Verification

- Run the focused test once.
- Stress the flaky file several times, e.g. 5 repeated runs.
- Run the full workspace/project test gate.
- If the project convention requires it, run build and audit after tests.
- Commit only after review if the change touches shared helpers or safety-related tests.
