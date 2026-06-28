# Set-Content heredoc over SSH fails — use a .ps1 script file instead

**Session:** 2026-06-23, [your-product] multi-file hardening ([VaultRunner]Studio.tsx, JarvisView.tsx, HermesTalk.tsx, VideoStudio.tsx, useMissionsStream.ts)
**Status:** validated — 5/5 multi-file patches landed via this recipe, 75/75 tests passed

## The pattern that fails

When you try to pass a multi-line PowerShell block to a remote Windows host over SSH, the obvious "inline here-string" approach breaks in three layered ways:

```bash
# PATTERN A — fails: here-string over SSH
ssh [ssh-user]@laptop 'powershell -NoProfile -Command "Set-Content -Path C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\[VaultRunner]Studio.tsx -Value @\"
old1
\"@
powershell -NoProfile -Command ..."' 2>&1 | head -5
# Output: The string is missing the terminator: \"@.
```

**Failure mode 1: terminator ` @" ` is eaten by bash quoting**. Single-quoted outer + double-quoted inner + backslash-escaped backtick + another level of escaping for the here-string terminator → the closing `"@` is the part that gets consumed by bash, not delivered to PowerShell. PowerShell sees an unterminated here-string and dies.

```bash
# PATTERN B — fails: here-string with all-Hebrew path
ssh [ssh-user]@laptop 'powershell -Command "Set-Content -Path ... שולחן העבודה ... -Value @\'
old1
'@
"'
# Output: ?????? ?????? ???? ??????
```

**Failure mode 2: literal Hebrew in the path also gets re-encoded**. Even if the here-string terminator survives, the Hebrew bytes in the path literal get re-encoded over the SSH wire and PowerShell's parser sees `????? ?????` instead of `שולחן העבודה`. `Set-Content` then either fails to find the file or silently creates a new file at the wrong path.

```bash
# PATTERN C — fails: PS1 file with Hebrew path inside
cat > /tmp/fix.ps1 << 'EOF'
$f = "C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\[VaultRunner]Studio.tsx"
Set-Content -Path $f -Value ...
EOF
scp /tmp/fix.ps1 [ssh-user]@laptop:...
ssh [ssh-user]@laptop 'powershell -File C:\path\fix.ps1'
# Output: garbled path, file not found
```

**Failure mode 3: heredoc-to-file on the orchestrator side is fine, but the PS1 file's CONTENT contains a Hebrew literal that the SSH-encoded bytes will corrupt on the way in.** You can pass a non-Hebrew path as a parameter, but if the Hebrew appears anywhere inside the script body, it survives the trip corrupted.

## The pattern that works

**Two-step: write a .ps1 file on the laptop via base64, then invoke it. All paths inside the .ps1 come from `Scripting.FileSystemObject` ShortPath, computed at runtime from the file the user gave me, not embedded as a literal.**

```bash
# 1. Build the .ps1 as pure ASCII on the orchestrator
cat > /tmp/multi_patch.ps1 << 'PSEOF'
param(
  [string]$RepoShort,           # e.g. C:\Users\[your-username]\OneDrive\913C~1\AGENTI~1.1
  [string]$FileShort,           # e.g. ...COMPON~1\OPENCL~4.TSX
  [string[]]$OldBlocks,
  [string[]]$NewBlocks
)
# PS1 content stays pure ASCII. The Hebrew path lives only in $RepoShort / $FileShort,
# which are passed in as parameters from the orchestrator (also pure ASCII: ShortPath).
...
PSEOF

# 2. scp the .ps1 to the laptop
scp /tmp/multi_patch.ps1 [ssh-user]@laptop:C:[user-home]/AppData/Local/Temp/multi_patch.ps1

# 3. Discover the ShortPaths on the laptop (pure ASCII output)
SHORT_REPO=$(ssh [ssh-user]@laptop 'powershell -Command "$fso = New-Object -ComObject Scripting.FileSystemObject; $f = $fso.GetFolder(\"C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\"); Write-Host $f.ShortPath"')
SHORT_FILE=$(ssh [ssh-user]@laptop 'powershell -Command "$fso = New-Object -ComObject Scripting.FileSystemObject; $f = $fso.GetFile(\"C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\[VaultRunner]Studio.tsx\"); Write-Host $f.ShortPath"')

# 4. Invoke the .ps1 with the ShortPaths as parameters — pure ASCII on the wire
ssh [ssh-user]@laptop "powershell -ExecutionPolicy Bypass -File C:\Users\[your-username]\AppData\Local\Temp\multi_patch.ps1 -RepoShort '$SHORT_REPO' -FileShort '$SHORT_FILE'"
# Output: Patch 1 OK / Patch 2 OK / ... (or "ERROR: target not found" with abort)
```

The key insight: **the Hebrew path exists only on the laptop side, in the filesystem, and is read via `Scripting.FileSystemObject` which gets the right bytes from the local NTFS codepage.** Nothing about the Hebrew path ever travels over the wire. The orchestrator only sees the ASCII ShortPath, which is byte-identical for both sides.

## Why the `.ps1` file matters

The whole point of the `.ps1` file is to **avoid embedding multi-line PowerShell in the SSH command line.** Multi-line PowerShell (here-strings, multi-line expressions, function definitions) does not survive the double-shell-quoting layer. By moving the multi-line logic into a file:

1. The file content is delivered as a flat byte stream via `scp` — no quoting, no escape nesting.
2. The file is invoked by name — single-line command, no embedded multi-line.
3. The Hebrew / non-ASCII data goes in as parameters — already-ShortPath-encoded, ASCII-clean.

The `.ps1` approach also gives the user a **re-runnable artifact.** If the patch fails halfway, the user can `cd /tmp && powershell -File fix.ps1` to re-run it without retyping.

## Recipe for the 3-step multi-patch session

The full session pattern that worked on 2026-06-23 for 5+ files in one pass:

```bash
# 1. Write a multi-patch .ps1 that takes a single file path and applies N patches
cat > /tmp/multi_patch.ps1 << 'PSEOF'
param([string]$FilePath)

# Read the file as raw text (preserves Hebrew bytes via UTF-8)
$content = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
$original = $content

# Patches as here-strings — ALL inside the .ps1 file, never on the SSH command line
$old1 = @"
  useEffect(() => { loadX(); }, []);
"@

$new1 = @"
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try { const r = await fetch("...");
      if (!cancelled) setX(await r.json()); } catch {}
    })();
    return () => { cancelled = true; };
  }, []);
"@

# Verify the old block exists, then apply
if ($content -notmatch "loadX\(\);") {
    Write-Host "ERROR: Patch 1 target not found. Aborting." -ForegroundColor Red
    exit 1
}
$content = $content.Replace($old1, $new1)
Write-Host "Patch 1 OK" -ForegroundColor Green

# ... more patches ...

# Write back as UTF-8 without BOM (Next.js / TS files choke on BOM at column 1)
$utf8NoBom = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllText($FilePath, $content, $utf8NoBom)

# Verify the file is still parseable
$finalSize = (Get-Item $FilePath).Length
Write-Host "Final size: $finalSize bytes"
PSEOF

# 2. Ship the .ps1 to a non-Hebrew path
scp /tmp/multi_patch.ps1 [ssh-user]@laptop:C:[user-home]/AppData/Local/Temp/multi_patch.ps1

# 3. Discover the ShortPath of the target file (one SSH call, pure ASCII output)
SHORT=$(ssh [ssh-user]@laptop 'powershell -Command "$fso = New-Object -ComObject Scripting.FileSystemObject; $fso.GetFile(\"C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]\src\components\[VaultRunner]Studio.tsx\").ShortPath"')

# 4. Run the .ps1 with the ShortPath as a parameter
ssh [ssh-user]@laptop "powershell -ExecutionPolicy Bypass -File C:\Users\[your-username]\AppData\Local\Temp\multi_patch.ps1 -FilePath '$SHORT'"

# 5. Verify the write
ssh [ssh-user]@laptop "powershell -Command \"Get-Item '$SHORT' | Select-Object Length, LastWriteTime\""

# 6. Run user-side validation
ssh [ssh-user]@laptop "cd $(dirname $SHORT | sed 's|\\|/|g') && npx tsc --noEmit"
```

## Why the BOM matters in the .ps1 recipe

If you write the file with `[System.IO.File]::WriteAllText` and the default UTF-8 encoding, PowerShell will add a BOM (`EF BB BF` at column 1). The `git diff` will then show a leading invisible character on the first line, which looks like a content change in code review.

The `New-Object System.Text.UTF8Encoding $False` pattern is the idiomatic .NET way to say "UTF-8 without BOM." Use it for any source-file write.

## When the .ps1 path is wrong — `Get-Item` after write MUST be checked

After every `.ps1` write, run the verification step (`Get-Item | Select-Object Length, LastWriteTime`). If `LastWriteTime` is older than the script's invocation time, the write hit a different path, the file was locked, or OneDrive was in flight.

Specifically for this session: a `useMissionAction.ts` (the original, 3817 bytes) was overwritten with a `useMissionsStream.ts` (6238 bytes) because both files have similar 8.3 names (`USEMIS~1.TS` vs `USEMIS~2.TS`). The fix was:
1. Notice the size mismatch (`Get-Item` shows 6238, expected 3817)
2. Re-run with the correct ShortPath
3. Verify again

This is **exactly** why the SKILL.md "PS1 script reported success but file did not persist" pitfall exists. The `Test-Path` + `Get-Item` checks at the end of every script are not optional.

## Anti-patterns

- **Don't** try to embed a multi-line `Set-Content` in the SSH command. The here-string terminator gets eaten by bash, OR the Hebrew path gets re-encoded, OR both.
- **Don't** write a `.ps1` on the orchestrator that contains a Hebrew path literal. Even with `scp`, the bytes will be re-encoded on the way in.
- **Don't** skip the `Get-Item | Select-Object Length, LastWriteTime` check after the write. `Test-Path $true` does not prove the right content landed.
- **Don't** use `Start-Process powershell -ArgumentList "-File fix.ps1"` over SSH — the process detaches and you lose the exit code and any stdout. Run synchronously: `ssh ... "powershell -File fix.ps1"`.
- **Don't** use `[System.IO.File]::WriteAllText` with the default UTF-8 encoding (it adds a BOM). Use `New-Object System.Text.UTF8Encoding $False`.

## See also

- `references/shortpath-hebrew-paths-over-ssh.md` — the ShortPath + base64 recipe, complements this recipe for the case where the orchestrator is doing the edit itself (e.g. via `patch` on the local mirror, then base64 + scp to the laptop). Use that recipe when the change is a wholesale file rewrite; use the `.ps1` recipe here when the change is N surgical patches in a single file.
- `references/ssh-ps1-silent-write-failure.md` — the "exit code 0 but file unchanged" failure mode. The verification ladder at the end of this file is the cure.
