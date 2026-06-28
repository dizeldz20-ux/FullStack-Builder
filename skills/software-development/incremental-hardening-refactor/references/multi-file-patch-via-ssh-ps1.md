# Multi-File Patch via SSH + PowerShell — the line-based recipe

Use when you need to edit N files on a Windows host (or any SSH-reachable host) where each edit is a multi-line string and you need to verify each one compiles. Validated on 2026-06-13 hardening pass on [your-product] (3 polling useEffects, 1 vitals route, 2 Promise.allSettled conversions, 8 empty catches — all green).

## Why this recipe exists

- Direct `sed -i` or `patch` on the host doesn't work for files with Hebrew paths, Windows CRLF, or PowerShell-specific syntax.
- `cat > file.ps1 <<'EOF' ... EOF` works for **building** a new file but **not** for **editing** a specific section of an existing file.
- Base64 round-trip works but is overkill when you have many files to patch.
- A single SSH+`-File` call per edit is reliable, slow but bounded.

## The recipe (3 stages)

### Stage 1: Build all PS1 patches locally

```bash
# On the local (Linux) side
mkdir -p /tmp/slice11

cat > /tmp/slice11/01-helper-import.ps1 <<'PSEOF'
# 01-helper-import.ps1 - add usePollWhileVisible import to hermes/page.tsx
$path = "C:\src\[your-product]\src\app\hermes\page.tsx"
$content = Get-Content $path -Raw
$content = $content -replace '(import \{ useEffect, useState \} from "react";)', '$1' + [Environment]::NewLine + 'import { usePollWhileVisible } from "@/lib/usePollWhileVisible";'
Set-Content -Path $path -Value $content -NoNewline
PSEOF

# Repeat for each edit, naming files 01-, 02-, 03-...
```

Each script is self-contained: reads file, transforms, writes back. **No state between scripts.**

### Stage 2: Upload + run all in one SSH session

```bash
# SCP all scripts at once
scp -i ~/.ssh/key -o StrictHostKeyChecking=no /tmp/slice11/*.ps1 user@host:/Users/administrator/AppData/Local/Temp/slice11/

# Run them in order
ssh -i ~/.ssh/key -o StrictHostKeyChecking=no user@host "powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\administrator\AppData\Local\Temp\slice11\01-helper-import.ps1"
ssh -i ~/.ssh/key -o StrictHostKeyChecking=no user@host "powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\administrator\AppData\Local\Temp\slice11\02-poll-block.ps1"
# ...
```

**Why `-File` not `-Command`:** `-File` reads the entire script and runs it as a unit, so `Get-Content` + `Set-Content` can read the source on disk and write it back without round-trip escaping.

### Stage 3: Verify + smoke test on the same SSH session

```bash
# Verify import is present + old setInterval is gone
ssh user@host "powershell -NoProfile -Command \"\$c = Get-Content 'C:\src\[your-product]\src\app\hermes\page.tsx' -Raw; Write-Host (\\\"usePollWhileVisible: \\\" + (\$c -match 'usePollWhileVisible')); Write-Host (\\\"setInterval left: \\\" + (\$c -match 'setInterval\(fetchIt, 8000\)'))\""

# Smoke test: hit the page
ssh user@host "powershell -NoProfile -Command \"(Invoke-WebRequest -Uri 'http://127.0.0.1:3001/hermes' -UseBasicParsing -TimeoutSec 30).StatusCode\""
```

**Smoke test must be a real HTTP hit, not a syntax check.** A file can `Set-Content` cleanly and still be syntactically broken — the dev server's compile step is the only true validator.

## The 4 PowerShell pitfalls (every patcher hits these)

### 1. `-replace` takes exactly 2 args, not 4

```powershell
# ❌ "The -ireplace operator allows only two elements to follow it, not 4"
$content = $content -replace 'pat', '$1' + "`r`n" + 'replacement'

# ✅ Build the replacement string first
$replacement = '$1' + "`r`n" + 'replacement'
$content = $content -replace 'pat', $replacement

# ✅ Alternative: use [regex] object
$regex = [regex]'pat'
$content = $regex.Replace($content, '$1' + "`r`n" + 'replacement')
```

### 2. `[Environment]::NewLine` for cross-platform line endings

`"\n"` is **LF only** on PowerShell. When the file's natural line ending is **CRLF** (Windows convention), mixing them in regex replacement creates mixed-ending files that some tools reject.

```powershell
# ✅ Always use [Environment]::NewLine for insertions
$content = $content -replace 'pat', '$1' + [Environment]::NewLine + 'replacement'
```

### 3. `Get-Content` + `Set-Content` round-trips lose BOM and encoding

If the original file has a UTF-8 BOM or specific encoding, a naive read/write loop strips them. For TS/JS files this is usually fine, but for `.env`/PowerShell files with Hebrew, it can corrupt them.

```powershell
# Safer: use -Raw + write as UTF-8 with BOM if original had it
[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($true))
```

### 4. `Get-Content -TotalCount` vs `Select-Object -First`

`Get-Content $f | Select-Object -First 50` reads the **entire file** first. For multi-MB log files this is 30+ seconds.

```powershell
# ✅ Reads only 50 lines
Get-Content $f -TotalCount 50
```

## Backup before any batch

Always create a backup with a timestamp pattern before patching. Multiple stages = multiple backups, all suffixed with the same timestamp for grouping:

```powershell
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $path "$path.bak-slice1.1-$ts" -Force
```

Then in commit message:
```
Slice 1.1: usePollWhileVisible (3 files)
- hermes/page.tsx — replaced setInterval with usePollWhileVisible
- hermes-local/page.tsx — same
- [vault-runner]/page.tsx — same
Backups: *.bak-slice1.1-<ts>
Verified: HTTP 200 on /hermes, /hermes-local, /[vault-runner]
```

## When to abort a slice

Abort and re-investigate if:
- More than 30% of the planned files fail to patch (likely the pattern changed across versions).
- The dev server returns 500 (compile error) on any patched file.
- The smoke test endpoint that worked before is now 404 (the patch removed a route).

Don't commit on a partial pass. The backup files let you always revert with `Move-Item $path.bak-* $path`.
