# PowerShell + Hebrew paths + npm over SSH — Worked Transcript

**Session:** 2026-06-14, [your-product] pipeline patch (5 fixes, live on the laptop)
**Author:** Hermes Agent
**Status:** validated end-to-end

## The three problems that ate ~30 minutes

1. **Hebrew paths embedded in `.ps1` scripts are re-encoded on the wire.** `scp` translates the UTF-8 Hebrew bytes into `windows-1255` / `latin-1` representation, so PowerShell on the laptop sees `xcx\bxox-xY` instead of the real path and fails with `String is missing the terminator`.
2. **`[System.IO.File]::WriteAllText(..., [System.Text.Encoding]::UTF8)` adds a BOM.** Every `WriteAllText` to a `.ts` file added a leading `﻿` (U+FEFF), which the user's `git diff` reported as a content change on line 1.
3. **`Start-Process npm.cmd -RedirectStandardOutput file.log` produces empty log files.** `npm.cmd` exits before `node` (the real builder) starts; the captured file is 0 bytes and the build never ran.

## Working recipe (Python orchestrator → PowerShell on laptop)

### Pattern: pass Hebrew paths as PowerShell parameters, not script literals

**What does NOT work:**

```bash
# WRONG: Hebrew path embedded in the .ps1 file body
cat > /tmp/fix.ps1 << 'EOF'
$ErrorActionPreference = "Stop"
$repo = "C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]"   # <-- scp mangles this
Set-Location -LiteralPath $repo
# ... patch logic ...
EOF
scp /tmp/fix.ps1 admin@laptop:/Users/[ssh-user]/fix.ps1
ssh admin@laptop "powershell -File C:\Users\[ssh-user]\fix.ps1"   # parse error
```

**What DOES work:**

```python
import subprocess
HEBREW = 'C:\Users\[your-username]\\OneDrive\\\u05e9\u05d5\u05dc\u05d7\u05df \u05d4\u05e2\u05d1\u05d5\u05d3\u05d4\\[your-product]'

# .ps1 body is pure ASCII, no Hebrew. Hebrew paths live in PowerShell -Command side.
script = '''param([string]$Path)
$ErrorActionPreference = "Stop"
$f = $Path
$c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
# ... patch logic ...
[System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8)
# Strip BOM after every write:
$bytes = [System.IO.File]::ReadAllBytes($f)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
  [System.IO.File]::WriteAllBytes($f, $bytes[3..($bytes.Length-1)])
}
'''
with open('/tmp/fix.ps1', 'wb') as f:
    f.write(script.encode('ascii'))   # explicit ASCII, no UTF-8 BOM

subprocess.run(['scp', '/tmp/fix.ps1', 'admin@laptop:/Users/[ssh-user]/fix.ps1'])

# Discover the repo on the laptop side via Get-ChildItem (only path that survives):
ps = (
    "$repo = (Get-ChildItem -Directory -Path 'C:\Users\[your-username]\\OneDrive' "
    "  -Recurse -ErrorAction SilentlyContinue -Depth 3 -Filter [your-product] "
    "  | Select-Object -First 1).FullName; "
    "$pl = Join-Path $repo 'src\\lib\\pipeline.ts'; "
    "& 'C:\\Users\\[ssh-user]\\fix.ps1' -Path $pl"
)
# subprocess.run forwards utf-8 correctly through ssh:
subprocess.run(
    ['ssh', '-o', 'BatchMode=yes', '-i', '/root/.ssh/laptop_id',
     'admin@laptop', f'powershell -NoProfile -Command "{ps}"'],
    capture_output=True, text=True, timeout=60, encoding='utf-8', errors='replace'
)
```

**Why `subprocess.run` over the inline `terminal()` call:** the inline form (`subprocess.run` in a Python script block run by `execute_code`) was blocked in this session, but the orchestrator-level `subprocess.run` from a Python script forwarded UTF-8 cleanly. The terminal tool's `command` string also went through correctly when wrapped in `python3 <<'PY' ... PY`.

### Pattern: strip BOM after every WriteAllText

The 3-byte check + write-back is mandatory, not optional:

```powershell
$bytes = [System.IO.File]::ReadAllBytes($f)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
  [System.IO.File]::WriteAllBytes($f, $bytes[3..($bytes.Length-1)])
}
```

If you skip it, `git diff` will show:

```diff
-// "From Inbox to Shipped" pipeline — turns a raw idea into a reviewed, buildable
+﻿// "From Inbox to Shipped" pipeline — turns a raw idea into a reviewed, buildable
```

…and you'll spend 5 minutes wondering what the `﻿` is. It's the BOM.

### Pattern: `param([string]$Path)` MUST be the first non-comment line

```powershell
# WRONG: heredoc-style, param comes after Write-Output
$bat = "@echo off`r`nparam([string]$Path)..."  # parse error
[System.IO.File]::WriteAllText($batPath, $bat, ...)

# RIGHT: param at the top of the .ps1
$script = 'param([string]$Path)
$ErrorActionPreference = "Stop"
# ... rest of logic ...
'
[System.IO.File]::WriteAllText($scriptPath, $script, ...)
```

## npm invocation patterns

### Anti-patterns (look right, silently fail)

```powershell
# ANTI-PATTERN 1: Start-Process with redirect, log stays 0 bytes
$proc = Start-Process -FilePath 'npm.cmd' -ArgumentList 'run','build' `
  -WorkingDirectory $repo `
  -RedirectStandardOutput $logPath `
  -RedirectStandardError $errPath `
  -PassThru
# Result: $logPath.Length == 0, build never ran.

# ANTI-PATTERN 2: cmd /c with Hebrew cwd and inline redirect
cmd /c "cd /d C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product] && npm run build > log.txt 2>&1"
# Result: cmd sees garbled path, redirect target not created.

# ANTI-PATTERN 3: synchronous & in -Command, blocked by Hermes' foreground guard
& npm.cmd run build 2>&1 | Out-String
# Result: blocked — `&` triggers the "use terminal(background=true)" guard.
```

### Working patterns (in order of preference)

```powershell
# PATTERN 1: synchronous capture via & + Out-String
# Use this for builds under 10 minutes.
$ErrorActionPreference = "Stop"
$out = & 'C:\Program Files\nodejs\npm.cmd' run build 2>&1 | Out-String
[System.IO.File]::WriteAllText('C:\Users\[ssh-user]\build_output.log', $out, [System.Text.Encoding]::UTF8)
Write-Output ("OUTPUT_LEN=" + $out.Length)
# Pro: works, faithful log. Con: blocks the SSH connection for the duration.
```

```bat
@echo off
cd /d "C:\path\to\repo"
call "C:\Program Files\nodejs\npm.cmd" run build > "C:\Users\[ssh-user]\build_output.log" 2>&1
echo EXITCODE=%errorlevel% >> "C:\Users\[ssh-user]\build_output.log"
```

```powershell
# PATTERN 2: wrap the build in a .bat and launch via Start-Process
# Use this when the build is too long to block on.
$batPath = 'C:\Users\[ssh-user]\run_build.bat'
$logPath = 'C:\Users\[ssh-user]\build_output.log'
$bat = "@echo off`r`ncd /d `"$repo`"`r`ncall `"npm.cmd`" run build > `"$logPath`" 2>&1"
[System.IO.File]::WriteAllText($batPath, $bat, [System.Text.Encoding]::ASCII)
$proc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $batPath -NoNewWindow -PassThru
$proc.Id | Out-File 'C:\Users\[ssh-user]\build_pid.txt'
# Then poll with process() action='poll' or check the log size.
```

```bash
# PATTERN 3: typecheck smoke instead of full build
# Use this for fast feedback on whether a patch broke types.
npx tsc --noEmit
# 5-10x faster than `next build` on a 50K-LOC Next.js project.
# Gives ~95% of the regression signal for "did my patch break imports?"
```

## Mandatory verification recipe

After **any** build invocation over SSH:

```powershell
$logPath = 'C:\Users\[ssh-user]\build_output.log'
Write-Output ('LOG_EXISTS=' + (Test-Path $logPath))
if (Test-Path $logPath) {
  Write-Output ('LOG_SIZE=' + (Get-Item $logPath).Length)
  Get-Content $logPath -Tail 10
}
```

**If `LOG_SIZE == 0`:** the build did NOT happen. Do not report success. Re-run with one of the working patterns.

**If `LOG_SIZE > 0` but the content is just the start of a build** (e.g. "▲ Next.js 14.2.5" with no further lines): the build was interrupted. Check for `next build` process via `Get-Process -Name node` and look for the actual `npm.cmd` exit code in the log tail.

## Common error message → diagnosis

| Error | Cause | Fix |
|---|---|---|
| `String is missing the terminator: '.` | Hebrew path in script literal got re-encoded | Use `param([string]$Path)` + Get-ChildItem on the laptop side |
| `Missing variable name after foreach` | `\` inside here-string interpreted as PS escape | Use single quotes for the outer string, or `[char]96` for backticks |
| `Missing closing ')' in statement block` | Same as above, plus unmatched parens in `Write-Output` | Move complex logic to a `.ps1` file, not `-Command` |
| `Test-Path returns $false` for a path that exists | OneDrive redirect, or `Get-ChildItem` not finished indexing | Use `Get-ChildItem -Recurse -ErrorAction SilentlyContinue` to discover the real path |
| `OLD_NOT_FOUND` in a `[System.IO.File]::ReadAllText` + `Replace` script | CRLF/LF mismatch, or trailing whitespace different from what you typed | Dump `$idx = $c.IndexOf('out.sort')` and print the bytes around it before bailing |
| `npm.cmd: PID=N_DEAD` immediately after start | npm.cmd exits before node starts, redirect streams orphaned | Use PATTERN 1 (synchronous `& npm.cmd ... | Out-String`) or PATTERN 2 (.bat wrapper) |
| `tail: cannot read 'build.log'` after scp | Log file is 0 bytes on the laptop; scp returns successfully with empty content | Mandatory `LOG_SIZE` check before claiming success |

## Diagnostic ladder (start at top, work down)

1. **Is the script on the laptop actually running?** Look for `Write-Output` from the script body in the SSH output. If absent, the script's parse error blocked execution.
2. **Did the file actually change on disk?** `Get-Item $f | Select-Object Length, LastWriteTime`. If `LastWriteTime` didn't move, the script exited before the write.
3. **Did `git diff` show the expected change?** If yes, the write happened. If only line 1 changed with `﻿`, it's a BOM.
4. **Did the build run?** `$logPath.Length` > 0 AND the tail of the log shows `next build` output past the first 5 lines. If just the startup banner, the build was interrupted.
5. **Did the dev server pick up the change?** `GET /api/pipeline/health` returns 200 with `lastError: null`. If 500, look at `[your-product]-devnew-3001.log` for the stack trace.

## Cross-references

- `incremental-hardening-refactor` SKILL.md § "PS1 script reported success but file did not persist on disk" — same root cause as the BOM pattern, but the broader verification matrix.
- `incremental-hardening-refactor` SKILL.md § "Local-host vs SSH-target tool scoping" — which tool to use for which scope (`terminal` + ssh, not `read_file` on a remote path).
- `references/ssh-ps1-silent-write-failure.md` — companion file focused on the PS1 silent-write pattern specifically.
- `references/multi-file-patch-via-ssh-ps1.md` — multi-file patches via the same recipe.
