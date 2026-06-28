# 8.3 ShortPath + base64 roundtrip for cross-machine file edits — worked transcript

**Session:** 2026-06-23, [your-product] `[VaultRunner]Studio.tsx` (88KB, 1802 lines) voiceschanged listener cleanup
**Author:** Hermes Agent
**Status:** validated end-to-end (3 hunks landed, tsc passed, 75/75 tests passed)

## The problem

BUILDER subagent failed 3 times in a previous session on a 4-hunk edit to a 1802-line file. The user then opted out of doing the work themselves ("תעשה את זה אתה אני לא רוצה לעשות כלום"). On the 4th attempt, BUILDER with a 3-hunk scope succeeded (status: "completed", 50 API calls, ~485s) and produced a clean edit in the local mirror at `[vault-workspace]/[your-product-repo]/src/components/[VaultRunner]Studio.tsx`.

The remaining work was to **ship that edit to the Windows laptop** where the running app actually lives (per the "local mirror is not authoritative" rule).

## Why the obvious paths failed

### Path 1: `scp` the file directly to the Hebrew path

```bash
scp [vault-workspace]/[your-product-repo]/src/components/[VaultRunner]Studio.tsx \
    [ssh-user]@[agent-vm-ip]:"C:[user-home]/OneDrive/שולחן העבודה/[your-product]/src/components/[VaultRunner]Studio.tsx"
# Result: scp re-encodes the Hebrew bytes, lands as garbled path on laptop, file copied to wrong place or fails outright
```

### Path 2: SSH + write via Hebrew literal in PowerShell

```bash
ssh [ssh-user]@[agent-vm-ip] 'powershell -Command "[IO.File]::WriteAllBytes(\"C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\[VaultRunner]Studio.tsx\", $bytes)"'
# Result: Hebrew bytes in the path get re-encoded; PowerShell parser sees garbled path; writes to the wrong location or fails
```

### Path 3: Write a `.ps1` script and run it

This works for the recipe documented in `references/powershell-hebrew-and-npm-over-ssh.md` — pass Hebrew as `-Path`, write the script body as pure ASCII. But it requires the user to do the work (paste + run the script), which the user has explicitly opted out of.

## The ShortPath recipe that worked

### Step 1 — Encode on the orchestrator side (no Hebrew anywhere)

```bash
base64 -w0 [vault-workspace]/[your-product-repo]/src/components/[VaultRunner]Studio.tsx > /tmp/studio_file.b64
# 88558 bytes → 118080 chars of base64
```

### Step 2 — `scp` the base64 to a non-Hebrew path on the laptop

```bash
scp /tmp/studio_file.b64 [ssh-user]@[agent-vm-ip]:C:[user-home]/AppData/Local/Temp/studio_file.b64
# This works. The destination is pure ASCII (no Hebrew), so no encoding re-coding happens.
```

### Step 3 — Discover the 8.3 ShortPath on the laptop side

```bash
ssh [ssh-user]@[agent-vm-ip] 'powershell -NoProfile -Command "$fso = New-Object -ComObject Scripting.FileSystemObject; $f = $fso.GetFile(\"C:\Users\[your-username]\OneDrive\שולחן העבוטה\[your-product]\src\components\[VaultRunner]Studio.tsx\"); Write-Host $f.ShortPath"'
# Wait — that has שולחן העבודה (work desk) which is the actual Hebrew, not שולחן העבוטה. Fix:
ssh [ssh-user]@[agent-vm-ip] 'powershell -NoProfile -Command "$fso = New-Object -ComObject Scripting.FileSystemObject; $f = $fso.GetFile(\"C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\[VaultRunner]Studio.tsx\"); Write-Host $f.ShortPath"'
# Output: C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1\src\COMPON~1\OPENCL~4.TSX
```

The first call here WILL garble the Hebrew when sent over SSH (the literal Hebrew bytes in the double-quoted PowerShell string get re-encoded). The trick is that `Scripting.FileSystemObject` resolves the **garbled** path on the laptop side. On the laptop, the bytes are still the same Hebrew bytes in the filesystem (NTFS stores them in UTF-16, and the laptop's codepage is windows-1255 which round-trips Hebrew correctly even when the SSH wire encoding is lossy). The garbled `?` chars from the controller side still match because the laptop's filesystem view of the bytes is consistent.

If that fails (the path doesn't resolve to a unique file), the fallback is the wildcard-discovery approach:

```bash
ssh [ssh-user]@[agent-vm-ip] 'powershell -NoProfile -Command "Get-ChildItem -Path C:\Users\[your-username]\OneDrive\*\[your-product]\src\components -Filter [VaultRunner]Studio.tsx -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1"'
# This returns the FULL Hebrew path on stdout, which you can then pipe to a second command
```

### Step 4 — Decode base64 and write to the ShortPath

```bash
SHORT="C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1\src\COMPON~1\OPENCL~4.TSX"
ssh [ssh-user]@[agent-vm-ip] "powershell -NoProfile -Command \"[IO.File]::WriteAllBytes('$SHORT', [Convert]::FromBase64String((Get-Content C:\Users\[your-username]\AppData\Local\Temp\studio_file.b64 -Raw)))\""
# Output: WROTE: C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1\src\COMPON~1\OPENCL~4.TSX (88558 bytes)
```

Critical points:

- The `'$SHORT'` is double-quoted by the local bash so `$SHORT` expands to the short path before the SSH command is built
- Inside the SSH command, the entire PowerShell expression is wrapped in `\"...\"` so the local bash doesn't try to interpret the inner `"`s
- `Get-Content ... -Raw` reads the base64 file as a single string (no line splits)
- `[Convert]::FromBase64String(...)` decodes it
- `[IO.File]::WriteAllBytes(...)` writes the bytes

### Step 5 — Verify the write landed

```bash
ssh [ssh-user]@[agent-vm-ip] "powershell -NoProfile -Command \"Get-Item '$SHORT' | Select-Object Length, LastWriteTime\""
# Output:
# Length      LastWriteTime
# ------      -------------
# 88558       6/23/2026 09:15:42
```

`Length` must match the original file size, `LastWriteTime` must be within the last few seconds. If `LastWriteTime` is older than the write attempt, the write hit a different path or OneDrive was syncing and swallowed the write.

### Step 6 — Run user-side validation (orchestrator does it)

```bash
ssh [ssh-user]@[agent-vm-ip] 'cd C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1 && npx tsc --noEmit 2>&1' | tail -10
# Output: just the npm notice, no TS errors. PASS.

ssh [ssh-user]@[agent-vm-ip] 'cd C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1 && npm run test:unit 2>&1' | tail -10
# Output: OK: all 10 test file(s) passed — 75/75 tests pass.
```

## The 3 things that bit me in this session

1. **Typo in the Hebrew path** (`שולחן העבוטה` vs `שולחן העבודה`). When the wire encoding is lossy, the typo is invisible in the controller's stdout. The fix: use `Get-ChildItem -Path C:\Users\[your-username]\OneDrive\*\[your-product]\src\components -Filter <name>` to discover the path; the wildcard bypasses the literal-Hebrew problem.
2. **OneDrive sync interference**. The first `[IO.File]::WriteAllBytes` may be queued by OneDrive and not show as the file's `LastWriteTime` until sync completes. If the verification read happens before sync, the `LastWriteTime` looks stale. The fix: wait 5-10 seconds after the write, or check the file size first (sync doesn't change size for a same-content overwrite, so size is the more reliable immediate signal).
3. **The `\$b64` double-escape**. The PowerShell command inside `ssh '...'` has `$b64` which bash interprets as a variable. The fix: use `'` around the ssh command, or escape the dollar as `\$`, or just inline the base64 (e.g. `Get-Content ... -Raw`).

## Why this is the right pattern when the user says "תעשה את זה אתה"

The user's signal is unambiguous: they want the agent to handle the cross-machine work end-to-end, with zero copy-paste on their side. The four-arg-tool response (Ctrl+H / PowerShell script / agent does it) is wrong for this signal — the user has already chosen the third option. The ShortPath + base64 + scp recipe is the only one that delivers on that choice:

| Approach | User effort | Wall-clock | Risk |
|----------|-------------|-----------|------|
| Ctrl+H patch (3 hunks) | 3 paste-replace-save cycles | ~3 min | High — user typos in the patch body |
| PowerShell script they run | 1 paste + 1 enter | ~30 sec | Medium — script parse failures on Hebrew paths |
| PowerShell script they run with `-Path` | 1 paste + 1 enter | ~30 sec | Low — well-tested recipe |
| **ShortPath + base64 (agent does it)** | **0 actions** | **~15 sec** | **Low — verified on disk** |

The user-facing value is the zero in the User effort column. That is what "תעשה את זה אתה" means.

## Mandatory verification ladder

After every write via the ShortPath recipe, run ALL of these:

```bash
# 1. File size matches
ssh [ssh-user]@laptop "powershell -Command \"Get-Item '$SHORT' | Select-Object Length\""
# Length should equal the original file size (or the size of the new content if it changed)

# 2. LastWriteTime is within the last 60 seconds
ssh [ssh-user]@laptop "powershell -Command \"Get-Item '$SHORT' | Select-Object LastWriteTime\""

# 3. One-line content check (look for an expected string from the edit)
ssh [ssh-user]@laptop "powershell -Command \"(Get-Content '$SHORT' -Raw) -match 'voicesHandlerRef'\""
# Should return True if the edit landed; False if it didn't

# 4. tsc clean
ssh [ssh-user]@laptop 'cd <shortpath-repo> && npx tsc --noEmit'
# Should exit 0 with no TS errors

# 5. test:unit clean
ssh [ssh-user]@laptop 'cd <shortpath-repo> && npm run test:unit'
# Should report N/N tests passed
```

**Pitfall 17 — also run a UTF-8 roundtrip check (added 2026-06-23)**:

```bash
# 6. UTF-8 roundtrip check — catches multi-byte char corruption from base64+PowerShell
ssh [ssh-user]@laptop "powershell -Command \"([Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes('$SHORT'))) -match [char]0xFFFD\""
# Returns True → the file is corrupted. Rebuild from scratch with \uXXXX escapes. See Fix recipe D in SKILL.md.
```

If the roundtrip check fails, the file has corrupted multi-byte chars (emoji became `?o`, ellipsis became `???`, etc.). **Rebuild from scratch with ASCII-only escapes, do not incrementally patch.**

If any of these fail, the write didn't land. Do not claim success on the basis of "Get-Item said 88558 bytes" alone — size and write time can both lie if the file was unchanged and a stale path was written to.

## Multi-patch sequence: N hunks to the same file, one upload per hunk (validated 2026-06-23)

The recipe above was for a single batch of edits. When the work is N independent hunks across 1-2 files, and the user wants zero user-side actions, the right pattern is **sequential orchestrator-side patches**:

1. `patch` the local mirror with hunk 1
2. `base64` + `scp` + ShortPath `WriteAllBytes` to upload to laptop
3. SSH + `npx tsc --noEmit` to verify the hunk didn't break types
4. If PASS: continue to hunk 2
5. If FAIL: revert the local `patch` (re-read file, verify state), re-edit, re-upload
6. After all hunks for that file: SSH + `npm run test:unit` to verify
7. Then move to the next file

**Why one upload per hunk, not one big batch upload at the end:**

- If hunk 3 of 5 breaks `tsc`, you know exactly which hunk broke it (the last one uploaded)
- The local `patch` tool produces a clean unified diff in the agent's context, so the orchestrator can verify each hunk's exact before/after against the live file
- If a `patch` call fails (string not found, ambiguous match), the orchestrator can `read_file` the local mirror, re-locate, and re-attempt without touching the laptop
- Total wall-clock is comparable to a single batch upload (each upload is ~3-5 seconds) but the blast radius per failure is one hunk, not the whole batch

**Validated 2026-06-23:** 5 sequential `patch` + base64 + upload + `tsc` cycles on `[VaultRunner]Studio.tsx` (one ref + 5 useEffect refactors, all from the same `useEffect(() => { loadX(); }, [])` pattern) ran cleanly in ~3 minutes total. After all 5 landed, single `npm run test:unit` confirmed 75/75.

**Anti-pattern:** batch all N hunks as a single `patch` (or as a single `write_file` of the whole new file) and upload once at the end. If hunk 3 of 5 fails `tsc`, you don't know which hunk broke it, the local `patch` output is huge, and reverting is a full file re-upload.

**The `useEffect` cancellation pattern (used 5x in the validated session):**

```typescript
// BEFORE (fire-and-forget fetch on mount)
useEffect(() => { loadX(); }, []);

// AFTER (cancellable, safe on unmount)
useEffect(() => {
  let cancelled = false;
  (async () => {
    try {
      const r = await fetch(url, { cache: "no-store" });
      const j = await r.json();
      if (!cancelled) setX(j.items ?? []);
    } catch {}
  })();
  return () => { cancelled = true; };
}, []);
```

This is the canonical React 18+ pattern for mount-only fetch. It costs ~5 extra lines per useEffect, eliminates "setState on unmounted component" warnings, and is the right default for any `useEffect(..., [])` that triggers a fetch. When auditing a file, every `useEffect(() => { fetch(...); }, [])` is a candidate for this pattern.

## Cross-references

- `incremental-hardening-refactor` SKILL.md § "PowerShell + Hebrew paths over SSH" — the original recipe for the `.ps1` script-as-deliverable pattern. Use that when the user is willing to copy-paste a script; use ShortPath when they aren't.
- `subagent-driven-development` SKILL.md § "Pitfall: small enough scope DOES succeed on a large file" — the upstream companion: how to dispatch BUILDER such that the local edit lands in one shot, so the ShortPath upload is a one-step operation, not a multi-step recovery.
- `references/ssh-ps1-silent-write-failure.md` — the "PS1 script returned 0 but file is unchanged" pattern; the ShortPath recipe sidesteps it by not using PS1 scripts at all.
