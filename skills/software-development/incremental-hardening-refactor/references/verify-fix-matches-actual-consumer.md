# Verify Your Fix Matches the Actual Consumer (Before Declaring Done)

Validated 2026-06-14 during the [your-product] slice 4.A re-verification. The
agent (me) shipped a "fix" to `hermesEnv.ts` that introduced an
`X-Hermes-Token: ${HERMES_DASHBOARD_TOKEN}` header on the dashboard status
request. The user then asked for a full audit of all changes. The audit
revealed:

1. The route handler at `src/app/api/hermes-local/dashboard/route.ts` did
   **not import** `hermesEnv.ts`. It inlined a 5-line `fetch()` with no
   headers.
2. The `hermesEnv.ts` file itself was **0 bytes** on disk — the PowerShell
   `Set-Content` from the previous session had reported success but never
   written the file.
3. The "fix" was therefore inert. The dashboard had been `running:true`
   before the patch, was `running:true` after, and the token header was
   never sent on the wire.

This is a worked example of the lesson: **the consumer's request shape is
ground truth; a fix is only a fix if it changes that request shape in a way
that resolves the original complaint.**

## The mandatory pre-fix checklist

Before declaring any auth/header/payload fix "done":

```text
[ ] 1. Read the consumer's request source. Not from memory — from disk.
[ ] 2. Read the consumer's response handler. What does it actually check?
[ ] 3. Confirm the consumer imports the file you just patched.
[ ] 4. Smoke-test the consumer before AND after the fix. The two responses
      should differ in a way that matches the fix's claim.
[ ] 5. If the fix is dead code, revert it and re-diagnose.
```

Skipping step 1 is the failure mode. The fix goes from "this is what
I remember the consumer wants" to "this is what the consumer actually
wants" only when the source is on screen.

## The full diagnostic flow (from the 2026-06-14 session)

Step 1: the user asked to verify all 4 claimed slices. The first thing
the agent did was try to read `hermesEnv.ts`:

```text
search_files path="C:\src\[your-product]\src\lib" pattern="hermesEnv"
→ "Path not found"   ← local-vs-SSH trap, see SKILL.md
```

Corrected: use the SSH channel via the `terminal` tool:

```bash
ssh -i ~/.ssh/hermes-laptop/id_ed25519 administrator@[agent-vm-ip] \
  'powershell -NoProfile -Command "Get-ChildItem C:/src/[your-product]/src/lib/hermesEnv.ts"'
# (none — file is 0 bytes or missing)
```

Step 2: find what actually imports `hermesEnv.ts`:

```bash
ssh -i ~/.ssh/hermes-laptop/id_ed25519 administrator@[agent-vm-ip] \
  'powershell -NoProfile -Command "Get-ChildItem C:/src/[your-product]/src -Recurse -Filter *.ts | ForEach-Object { Select-String -Path \$_.FullName -Pattern hermesEnv } | Select-Object Path, LineNumber | Format-Table -AutoSize -Wrap"'
# → only 8 lines, all in /api/hermes/tts/route.ts, elevenTts.ts, hermesPhone.ts
#   and they import from @/lib/hermesPhone, NOT @/lib/hermesEnv
```

Step 3: find the actual dashboard route handler:

```bash
ssh -i ~/.ssh/hermes-laptop/id_ed25519 administrator@[agent-vm-ip] \
  'powershell -NoProfile -Command "Get-ChildItem C:/src/[your-product]/src/app/api -Recurse -Directory -Filter dashboard"'
# → C:\src\[your-product]\src\app\api\hermes-local\dashboard  (NOT /api/hermes/dashboard)
```

Step 4: read the actual route handler:

```bash
ssh -i ~/.ssh/hermes-laptop/id_ed25519 administrator@[agent-vm-ip] \
  'powershell -NoProfile -Command "Get-Content C:/src/[your-product]/src/app/api/hermes-local/dashboard/route.ts"'
# → 30-line file, only does fetch(${DASH_URL}/api/status) with NO headers,
#   only checks r.ok. There is no place that would send X-Hermes-Token.
```

Step 5: smoke-test the live route from a separate channel:

```bash
curl -sS -m 8 "http://[agent-vm-ip]:3001/api/hermes-local/dashboard"
# → {"running":true,"url":"http://[agent-vm-ip]:9119"}
# (or running:false if dashboard not running — but the point is the route
#  works without any token)
```

The diagnostic chain takes 5 SSH commands and 2-3 minutes. It catches the
class of bug where a "fix" is well-intentioned but addresses a problem
the consumer doesn't have.

## Why the symptom "I patched it and now it's broken" usually means the fix
## was already wrong

Common variant of this trap:

- User reports "X is broken."
- Agent remembers a similar past issue and patches what it remembers was
  the cause.
- "X" is still broken. User reports back.
- Agent digs deeper, reads the actual source, finds the real cause.
- Agent fixes the real cause, but the original patch is still on disk.
- Now there's a half-applied change that doesn't help and may hurt.

The mitigation is step 5 of the checklist: **smoke-test before and after**.
If "before" and "after" are identical, the fix was inert. Revert it (or
merge it if it actually does something useful for a different reason, but
explicitly say so).

## What "consumer" means in this context

- For an API endpoint fix: the route handler file (the source that
  constructs the request).
- For an SDK helper fix: the file that calls the helper.
- For a UI component fix: the parent component that imports it and the
  page that mounts it.
- For a CLI flag fix: the `process.argv` parsing code.
- For a config-format fix: the config *loader*, not the config writer.

In all cases: **read the importer, not the imported**. The fix is a
function of what the importer needs, not what the imported file can
provide. If you patched the imported file and the importer doesn't
import the patched symbol, the patch is dead.

## Cross-references

- The local-vs-SSH tool scoping lesson in the main SKILL.md explains why
  step 1 of the diagnostic chain needed the SSH redirect.
- The PS1 silent-write failure reference
  (`references/ssh-ps1-silent-write-failure.md`) explains why the original
  patch reported success but the file was 0 bytes.
- The `hermes-config-validation` skill's "validate config keys against
  actual source" rule is the same lesson at a different scope: don't
  trust the documented interface, trust the live one.
