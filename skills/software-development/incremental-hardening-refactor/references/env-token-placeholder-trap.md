# `.env.local` Token-Placeholder Trap

When a project uses a remote bridge/API that authenticates with a
bearer token, and a downstream consumer (UI, dev server, or another
service) reads that token from `.env.local`, the token can drift from
the real value in two ways:

1. **The original setup wrote a placeholder.** A template like
   `HERMES_BRIDGE_TOKEN=*** paste-from-vault-here` is committed (or
   written by the agent) and never replaced.
2. **A tool partially rewrote the file.** When a copy-paste drops
   bytes mid-token, or a hook appends a marker string
   (`PLACEHOLDER***`, `*** edit-me`, etc.) to the end of the line,
   the token still *starts* with the right bytes, so casual
   `head -c 8` checks pass — but the full string sent to the
   server has trailing junk, and the server returns 401.

## Symptom

- `curl -H "Authorization: Bearer <token>"` from one machine works.
- The same request from the app (Next.js / Vite / etc.) fails with
  `unauthorized` or HTTP 401.
- The dev server logs do NOT show the error; the error is surfaced
  only through a UI panel that says "Couldn't reach the Hermes
  dashboard — unauthorized" or similar.

## How to diagnose

1. Read the literal bytes of the token from the consumer's
   `.env.local` (no truncation, no `${VAR:0:8}` preview).
2. Read the literal bytes of the token from the producer's env
   (e.g. `/proc/<bridge-pid>/environ` on Linux,
   `Get-CimInstance Win32_Process` on Windows, or the producer's
   own `.env.local` / `.env`).
3. Compare with `===` (string equality) AND `len()` (length).
   Placeholder-suffix bugs leave the prefix matching but the length
   off by the marker length.

```python
import subprocess
# Producer side (the bridge VM)
vm = subprocess.run(['grep', '^HERMES_BRIDGE_TOKEN',
                    '/path/to/bridge/.env.local'],
                   capture_output=True, text=True)
vm_token = vm.stdout.strip().split('=', 1)[1]

# Consumer side (the laptop, via scp to avoid shell quoting)
import shutil
shutil.copy('/tmp/laptop-env.txt', '/tmp/laptop-env-fixed.txt')
# ... then load, compare
```

4. As a sanity probe, hit the bridge directly with the consumer's
   token (read fresh, no env-var caching). If the bridge returns
   200, the token is correct. If 401, the token is wrong.
   This isolates "the token in the file" from "the token the
   runtime actually loaded" — Next.js reloads `.env.local` on file
   change, so a stale runtime can keep using the old (bad) token
   even after you fix the file.

## Fix

1. Edit the consumer's `.env.local` so the line is exactly the
   producer's token, byte-for-byte.
2. **Restart the dev server** — Next.js reads `.env.local` on
   boot. A file change after boot triggers `Reload env: .env.local`
   in the dev-server log, but some routes cache the old value.
3. Re-test. If the dev server is mid-compile and the request
   times out, the fix is not in the token — it's in the runtime.

## Prevention

- **Use a setup probe, not a file write.** When a token needs to
  be shared between two machines, run a one-liner on the consumer
  that `curl`s the producer with the token BEFORE writing the
  file. If it returns 200, write it. If 401, the source token is
  wrong; do not propagate a bad value.
- **Store the token in a script, not a hand-typed line.** A bash
  helper that does `printf 'HERMES_BRIDGE_TOKEN=%s\n' "$TOKEN" >>
  .env.local` is less error-prone than a copy-paste.
- **Make the placeholder obvious.** If a placeholder is intentional
  (template committed, real value added later), use a sentinel
  that fails fast on use, e.g. `__REPLACE_BEFORE_USE__` instead of
  `***` (which looks like it could be a real marker).

## Where this fits in the pack-merge flow

After step 6 (copy the new files) in the selective pack-merge
pattern, BEFORE step 7 (tsc), do a quick `.env.local` integrity
check:

```bash
# Producer side
grep '^HERMES_BRIDGE_TOKEN' /path/to/bridge/.env.local > /tmp/prod.tok
# Consumer side
scp laptop:/path/to/.env.local /tmp/cons.tok 2>/dev/null
grep '^HERMES_BRIDGE_TOKEN' /tmp/cons.tok > /tmp/cons-line.tok
diff /tmp/prod.tok /tmp/cons-line.tok || echo "TOKEN MISMATCH"
```

A mismatch here is cheaper to find than a "dashboard says
unauthorized" report at the end of the session.
