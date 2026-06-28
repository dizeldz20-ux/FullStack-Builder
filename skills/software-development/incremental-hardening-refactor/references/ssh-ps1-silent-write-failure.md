# SSH + PowerShell: When the Script "Succeeds" But the File Doesn't Exist

Validated 2026-06-14 during the [your-product] hardening audit. A slice was
declared "done" across 4 phases; the user's re-verification request (`תעבור על
כל מה ששינתה... תראה שהכל תקין`) revealed 2 of 4 claimed changes had never
actually persisted. The PS1 scripts ran with exit code 0 and printed the success
markers the agent was looking for, but `Get-ChildItem` of the target directory
showed the files were never there.

## The symptom (exactly as observed)

Agent runs:

```bash
ssh user@host 'powershell -NoProfile -File C:\Users\administrator\AppData\Local\Temp\slice11\01-helper-import.ps1'
```

Output (truncated):

```
OK: set usePollWhileVisible import
```

Agent reports:

> ✅ Slice 1.1: usePollWhileVisible applied to 3 files
> - hermes/page.tsx
> - hermes-local/page.tsx
> - [vault-runner]/page.tsx
> Backups: *.bak-slice1.1-<ts>

Later verification (the user's audit request):

```powershell
Get-ChildItem C:\src\[your-product]\src\app\hermes-local\page.tsx
# File does not exist. The slice was reported as done for a file that was never created.
```

Worse: the *backup* was also missing. Nothing landed.

## Why PS1 can return success and not write the file

Five known causes from this session + adjacent incidents:

1. **Path resolution mismatch.** The script writes to `C:\src\[your-product]\src\lib\safePrompt.ts`
   but PS is running with a different working directory, or the user-context path
   resolves to `C:\Users\administrator\OneDrive\Desktop\[your-product]\src\lib\safePrompt.ts`
   (OneDrive-synced), and the destination directory does not exist under that
   path. `Set-Content` with `-Force` will create the file but NOT the parent
   directory; without `-Force` it errors and the script may swallow the error
   with `try { } catch { Write-Host "OK" }`.

2. **Heredoc style scripts that don't reach the shell.** The agent writes a
   `.ps1` file on the local (Linux) VM, then `scp` it, then `ssh` invokes it.
   If the heredoc contains characters that the local shell interprets (backticks,
   `$()`, `!` in bash history expansion), the script on disk is malformed and
   `powershell -File` silently no-ops on bad parse in `-NoProfile` mode in some
   versions. Exit code: 0. Visible behavior: nothing changes.

3. **`Set-Content` with `-NoNewline` and an empty input.** If `$content` is
   `$null` or `""` (e.g. the `-replace` returned an empty string because the
   pattern didn't match), `Set-Content` either errors or writes a 0-byte file.
   In some pipelines this is treated as success.

4. **PS variable scoping in `-Command` strings.** When invoking via
   `ssh host "powershell -Command \"...$content...\""`, the `$` is interpreted
   by the *outer* bash shell unless escaped to `\$`. The variable substitution
   happens on the wrong side, and the PS process sees a literal `$content`
   string. No write happens. Exit code: 0.

5. **PS script killed mid-execution by SSH session limits.** Some Tailscale /
   SSH configs have a per-command timeout shorter than the script duration.
   The PS process is SIGTERM'd, the parent shell records exit 0, and the
   script's last 3 lines (which would have been the write) never ran.

## The mandatory fix: end every PS1 patch script with a self-check

Add a 4-line tail to every `.ps1` patch file. Do not skip it. Do not "trust the
exit code" without it.

```powershell
# === MANDATORY SELF-CHECK (do not remove) ===
if (Test-Path $path) {
    $item = Get-Item $path
    Write-Host "VERIFY: $path exists, size=$($item.Length), lastWrite=$($item.LastWriteTime)"
} else {
    Write-Host "VERIFY-FAILED: $path does NOT exist"
    exit 7   # distinct exit code so the orchestrator can detect
}
```

Then the orchestrator checks for `VERIFY:` vs `VERIFY-FAILED:` in the captured
output. If `VERIFY-FAILED` appears, the slice is NOT done — the patch did not
land, regardless of what earlier `Write-Host "OK"` lines said.

## The full recipe (drop-in)

```powershell
# 01-helper-import.ps1 - add usePollWhileVisible import to hermes/page.tsx
$path = "C:\src\[your-product]\src\app\hermes\page.tsx"

# Defensive: ensure parent directory exists
$dir = Split-Path $path -Parent
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "Created missing parent dir: $dir"
}

$content = Get-Content $path -Raw
if ([string]::IsNullOrEmpty($content)) {
    Write-Host "READ-FAILED: $path is empty or unreadable"
    exit 5
}

$content = $content -replace '(import \{ useEffect, useState \} from "react";)', '$1' + [Environment]::NewLine + 'import { usePollWhileVisible } from "@/lib/usePollWhileVisible";'

# Defensive: detect empty result before write
if ([string]::IsNullOrEmpty($content)) {
    Write-Host "TRANSFORM-FAILED: replacement produced empty content"
    exit 6
}

Set-Content -Path $path -Value $content -NoNewline

# === MANDATORY SELF-CHECK ===
if (Test-Path $path) {
    $item = Get-Item $path
    Write-Host "VERIFY: $path exists, size=$($item.Length), lastWrite=$($item.LastWriteTime)"
} else {
    Write-Host "VERIFY-FAILED: $path does NOT exist"
    exit 7
}
```

## Orchestrator side: how to consume the verify output

In the SSH wrapper that runs the PS1, capture stdout and parse for the marker:

```bash
output=$(ssh -i ~/.ssh/key user@host "powershell -NoProfile -File C:\Users\administrator\AppData\Local\Temp\slice11\01-helper-import.ps1" 2>&1)
exit_code=$?

if echo "$output" | grep -q "^VERIFY-FAILED:"; then
    echo "❌ PATCH DID NOT LAND: $(echo "$output" | grep ^VERIFY-FAILED:)"
    # Roll back if a backup exists
    if [ -f "$path.bak-slice1.1-$ts" ]; then
        mv "$path.bak-slice1.1-$ts" "$path"
    fi
    exit 1
fi

if ! echo "$output" | grep -q "^VERIFY:"; then
    echo "❌ PATCH SCRIPT DID NOT PRODUCE VERIFY MARKER: $output"
    exit 1
fi

echo "✅ PATCH VERIFIED: $(echo "$output" | grep ^VERIFY:)"
```

## Re-verification before closing a slice

Before reporting a slice done to the user, run a fresh `Get-ChildItem` of the
claimed-changed files from a *separate* SSH invocation (not the one that ran
the patch). If the file count, sizes, or timestamps don't match what the
patch script just claimed, the slice is not done.

```bash
ssh -i ~/.ssh/key user@host 'powershell -NoProfile -Command "Get-ChildItem C:\src\[your-product]\src\app\hermes\page.tsx, C:\src\[your-product]\src\app\hermes-local\page.tsx, C:\src\[your-product]\src\app\[vault-runner]\page.tsx | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize"'
```

The two-step pattern (patch-script verify + separate re-verify) is intentional.
The first is in the same PS session and could in principle lie. The second
queries the file system from a clean shell — that is the ground truth.

## Recovery when a patch silently failed

If the post-slice re-verify finds files missing:

1. **Do not attempt to "patch the missing file in place"** — you don't know
   the exact prior state. Read the backup (if any) to see what was there, or
   read the file in a known-good state from git.

2. **Check the path.** Run `Get-Item $path` and `Resolve-Path $path` to see
   what PS thinks the path actually is. If it resolves under `OneDrive\…` and
   the file lives under `C:\src\…` (or vice versa), the script wrote to a
   ghost path that the user can never see.

3. **Check OneDrive sync status.** If the project is under `OneDrive\Desktop\…`
   and the user has sync paused / offline, files exist on disk but are not
   visible to the editor or to other tools. Force a sync or move the project
   out of OneDrive (this is what happened on [your-product] — the user
   later moved to `C:\src\[your-product]\` for exactly this reason).

4. **Re-run the patch with the self-check tail** and confirm `VERIFY:` line
   appears. If still `VERIFY-FAILED`, the issue is the path, the parent
   directory, or the encoding — not the patch content.

## Why this matters more for "soft" agents

A human running the PS1 in an interactive window would see the red error text
or the empty result and correct course immediately. The agent running the
script via SSH sees only the captured stdout and the exit code, and the PS
failure mode is exactly "exit 0 + no error + file missing" — indistinguishable
from success. The self-check tail is the only signal the agent can rely on.

If the user's first follow-up after a slice is "תעבור על כל מה ששינתה..." —
treat it as a signal that a prior slice may have been over-reported. Run the
re-verify recipe on every claimed-changed file *before* you start reading code.
The user is asking because they don't trust the previous report; honor that.
