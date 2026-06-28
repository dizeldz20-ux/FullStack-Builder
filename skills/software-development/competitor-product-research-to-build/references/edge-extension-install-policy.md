# Edge / Chrome Extension Install via Group Policy (when Developer Mode UI is hidden)

**The trap**: As of Edge 134+ (mid-2025) and matching Chrome versions, the **Developer Mode toggle has been removed from `edge://extensions` UI**. The "Load unpacked" button only appears if Developer Mode is on. Without the toggle, the user cannot install a personal/unpacked extension through the UI.

**The trap within the trap**: Even when the UI shows a "Load unpacked" dialog, Edge now **requires a signing private key (`.pem`)** for the extension to be loaded — clicking "Install" with no key returns an error like "כלל מפתח פרטי ונעל" / "Include private key and try again". This blocks any personal build that doesn't go through the Chrome Web Store.

**The fix**: Install the extension **out-of-band via Group Policy** (HKLM, not HKCU — Edge policy keys live under `HKLM\SOFTWARE\Policies\Microsoft\Edge`). The policy install path bypasses the UI entirely. The recipe below was proven end-to-end in the Scrappy-Dood build (June 2026).

## The 6-step recipe

### 1. Generate a stable RSA key pair for the extension

Run on the Hermes host:

```bash
cd /tmp
openssl genrsa -out scrappy-key.pem 2048
openssl rsa -in scrappy-key.pem -pubout -outform DER 2>/dev/null | openssl base64 -A > scrappy-key.pub.b64
```

The public key (`scrappy-key.pub.b64`) is what gets baked into `manifest.json` as the `"key"` field. The private key (`scrappy-key.pem`) is what signs the CRX.

### 2. Add the `"key"` field to manifest.json

The key is the base64-encoded DER SPKI of the public key, single-line, no wrapping. After adding it, the manifest looks like:

```json
{
  "manifest_version": 3,
  "name": "Scrappy-Dood",
  "version": "0.1.0",
  "key": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...",
  ...
}
```

This makes the extension ID **deterministic** — same key on any machine produces the same ID. Without it, Edge/Chrome hash the install path, so the ID changes every time you move the extension.

### 3. Compute the extension ID from the public key

The ID is the first 16 bytes of `SHA-256(DER_of_public_key)`, nibble-by-nibble mapped to `a` + (nibble_value). 32 chars total. Python one-liner:

```python
import hashlib, subprocess
der = subprocess.check_output(['openssl', 'rsa', '-in', '/tmp/scrappy-key.pem', '-pubout', '-outform', 'DER'], stderr=subprocess.DEVNULL)
h = hashlib.sha256(der).digest()[:16]
print(''.join(chr(ord('a') + (b >> 4)) + chr(ord('a') + (b & 0xf)) for b in h))
```

Example output: `mphahnfobooebdfijheknmidjieihaic`. This is the ID you'll wire into the native messaging manifest's `allowed_origins` / `allowed_extensions`.

### 4. Pack the extension as a CRX3 file

The CRX3 format is: `Cr24` magic (4 bytes) + version (uint32 LE = 3) + signed-header length (uint32 LE) + protobuf-encoded signed-data header + ZIP payload. The signed data is signed with the private key (PKCS#1 v1.5 over SHA-256) over the inner signed-header (`{4: 2}` for CRX3 version 2).

A working Node.js packer is in `templates/pack-crx.js`. Key points:

- Build the inner ZIP **manually** (DOS local headers + central directory + EOCD), stored-no-compression. `archiver`/`yazl` aren't needed and the manifest is small.
- The signed-header payload to sign is **just** `pbFieldVarint(4, 2)` — NOT including the `Cr24` magic. Easy to get wrong.
- The DER public key in the CRX header is the **SPKI** (the one you exported in step 1), not the raw RSA modulus+exponent.

Output: a `.crx` file the browser can verify and install.

### 5. Upload the CRX to the laptop

`scp` works on this Tailscale SSH config (the old "SCP is blocked" lore is wrong). Drop the CRX in a stable path on the laptop:

```bash
scp -i ~/.ssh/hermes-laptop/id_ed25519 /tmp/scrappy-dood.crx \
    [ssh-user]@laptop.tail<id>.ts.net:staging.crx
ssh -i ... [ssh-user]@laptop.tail<id>.ts.net \
    "powershell -NoProfile -Command \"Move-Item staging.crx C:\Users\[your-username]\\AppData\\Local\\HermesBridge\\scrappy-dood.crx -Force\""
```

### 6. Register the policy on the laptop

Write a PowerShell script that creates / updates the policy keys. **HKLM is required for Edge policies — HKCU is silently ignored.** Run as [ssh-user] (which is exactly the user the SSH session lands on, so no elevation needed):

```powershell
$extId = "mphahnfobooebdfijheknmidjieihaic"   # the ID from step 3
$crxPath = "C:\Users\administrator\AppData\Local\HermesBridge\scrappy-dood.crx"
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

# ExtensionInstallForcelist — point at file:// URL of the local CRX
$crxUrl = "file:///" + ($crxPath -replace '\\','/')
New-Item -Path "$policyPath\ExtensionInstallForcelist" -Force | Out-Null
New-ItemProperty -Path "$policyPath\ExtensionInstallForcelist" -Name "1" `
    -Value "$extId;$crxUrl" -PropertyType String -Force | Out-Null

# ExtensionSettings — per-extension allow + force_install
New-Item -Path "$policyPath\ExtensionSettings" -Force | Out-Null
$config = @{
    "*" = @{ installation_mode = "allowed"; runtime_blocked_hosts = @(); blocked_permissions = @() }
    $extId = @{ installation_mode = "force_installed"; update_url = $crxUrl }
} | ConvertTo-Json -Depth 6 -Compress
New-ItemProperty -Path "$policyPath\ExtensionSettings" -Name $extId `
    -Value $config -PropertyType String -Force | Out-Null

# Optional: Defense in depth + dev tools
New-Item -Path "$policyPath\ExtensionInstallAllowlist" -Force | Out-Null
New-ItemProperty -Path "$policyPath\ExtensionInstallAllowlist" -Name $extId -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $policyPath -Name "DeveloperToolsAvailability" -Value 1 -PropertyType DWord -Force | Out-Null
```

When the user next opens Edge, the policy forces the CRX install. Edge may pop a one-time "External extension loaded" dialog — user clicks Install, the extension appears in `edge://extensions` with the predicted ID. Done.

## What still requires user-side action

- **The Edge window must be fully closed** before the next launch picks up the new policy. `msedgewebview2` background processes don't matter; only the main `msedge.exe` process. Killing just the browser is fine, those webview2 helpers will re-attach on next launch.
- **The first launch may show an "External extension loaded" prompt** that the user has to click through. This is a one-time Edge security UX, not a failure.
- **The user must accept the extension's permissions** on first run (host_permissions for `<all_urls>` triggers a per-site allowlist or full allow prompt).

## What this does NOT solve

- **Updates**: `ExtensionInstallForcelist` with `update_url` pointing to `file://` does NOT trigger automatic re-installs when the local CRX changes. You have to bump the extension's `version` in `manifest.json` and rebuild the CRX, then re-`Move-Item` to the laptop. The browser will pick up the new CRX on next launch because it sees a different file hash than the cached install.
- **Per-machine portability**: the policy is tied to the machine GUID and the CRX file path. Moving the laptop or the CRX requires re-running step 6.
- **Chrome Web Store listing**: if you want to share the extension with anyone else, this recipe does not help. You'd need a developer account and a Store upload flow.

## Why this beats "wait for Microsoft to re-add Developer Mode"

Developer Mode isn't coming back for Edge stable channel — Microsoft removed it deliberately to harden the extension install surface. The policy-based install is the **officially supported** path for "I have an internal-use extension and I don't want a Store listing". Every enterprise that deploys an internal Chrome/Edge extension uses exactly this flow.

## See also

- `templates/pack-crx.js` — Node.js CRX3 packer that signs with the private key and emits a valid CRX
- `templates/install-edge-extension-policy.ps1` — the full PowerShell registry script, parameterized for any extension ID/CRX path
- `templates/launch-edge-with-extension.ps1` — creates a desktop `.lnk` + `.bat` + Start Menu entry that launches Edge with `--load-extension` baked into Arguments. Use as a fallback when `ExtensionInstallForcelist` + `file://` is silently blocked.
- `references/tailscale-ssh-windows-bridge.md` — how to scp the CRX from Hermes to the laptop over Tailscale

## What breaks even AFTER the policy is registered

Three recurring failure modes from the Scrappy-Dood build (June 2026) that no recipe prevents — the fix has to happen *after* step 6.

### ❌ `AppData\Local\<subfolder>` doesn't grant `BUILTIN\Users` Read

When you `mkdir` (or PowerShell `New-Item -ItemType Directory -Force`) a new subfolder under `C:\Users\administrator\AppData\Local\`, the new folder inherits the parent's DACL — which on a clean Win11 install is **SYSTEM + [ssh-user]s + owner only**, NOT `BUILTIN\Users`. Edge on Win11 runs the extension host as a **Standard user** (Microsoft hardened this in 2024), so it cannot read the unpacked extension directory and the file picker / policy install errors with `Windows את אפשרות למצוא את '<path>' — בדוק נכון שוב` ("Windows cannot find the path, check the spelling").

The fix is one PowerShell block, run once after creating the extension directory:

```powershell
$ext = "C:\Users\administrator\AppData\Local\HermesBridge\extension"
$acl = Get-Acl $ext
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "BUILTIN\Users","ReadAndExecute",
    "ContainerInherit,ObjectInherit","None","Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path $ext -AclObject $acl
```

**Run this before telling the user to "load unpacked" or before relying on the policy path to read the extension directory.** Without it, the policy install path silently fails because Edge can't enumerate the CRX contents — and the user sees a misleading "path not found" error.

### ❌ VNC unavailable → can't visually verify "is it installed?"

On a headless Hermes session where the only contact is Tailscale SSH, you cannot see Edge's UI. The fallback verification chain, in order of reliability:

1. `Get-Process msedge | Where-Object MainWindowTitle -ne ''` — confirms Edge has a window (not just background webview2 helpers).
2. After Edge opens a window at least once: `$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Local State` is a JSON file you can read with `Get-Content -Raw`.
3. **`Local Extension Settings\<id>\` directory presence** — this **proves** an extension with that ID loaded. The directory is LevelDB (MANIFEST/LOG files), not human readable, but the folder's existence is a 100% signal. Without this folder, the extension is NOT installed, regardless of what `Local State` says.
4. `User Data\Default\Secure Preferences` — JSON, contains `extensions.settings.<id>` blocks. **Only appears after the first window opens.** Common bug: check for it too early, see "missing", conclude the policy failed, when Edge is still spinning up.

The `Local Extension Settings\<other_id>` folders you find on disk are NOT necessarily your extension — Edge creates these for **any** extension it has ever seen, including system extensions and Microsoft-bundled ones. Compare folder names to the deterministic ID you computed in step 3, not to a guess.

### ❌ `file://` URLs in `ExtensionInstallForcelist` are silently blocked on Edge 134+

This is a **second trap inside the Edge 134+ trap**. The recipe in steps 5–6 above uses `file:///` URLs as `update_url`. As of Edge 134+ (mid-2025), **`file://` update URLs are silently rejected** — no error, the policy value is just ignored, the extension never force-installs. If `gpupdate /force` succeeds, the registry keys are present, but the extension still doesn't show up after a fresh launch, **the `file://` URL is the problem**.

Three workarounds, in order of reliability for a single-user personal build:

1. **Drop the policy route and use `--load-extension` flag via a desktop shortcut.** The shortcut's `Arguments` field takes `--load-extension="<absolute path>"` and Edge 149 honors it on launch. The user double-clicks the shortcut instead of the regular Edge icon. Cumbersome, but works without any policy infrastructure.
2. **Use a localhost HTTP server as the `update_url`.** Run a small Python/Node server on the laptop that serves a static `updates.xml` and a copy of the CRX. Set the `update_url` policy to `http://localhost:8123/updates.xml`. Edge polls the manifest, sees the new version, installs. Requires the server to be running at Edge launch time. Brittle.
3. **Use a `chrome://` internal trigger via scheduled task or `HKCU\…\Run` registry entry.** Point a `.bat` wrapper at `msedge.exe --load-extension=<path> --no-first-run`, register it under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. Persists across reboots.

**Recommendation for a single-user personal extension on a single laptop**: **option 1 (desktop shortcut) is faster and more reliable than fighting the policy `file://` block**. Reserve the policy route for enterprise multi-user deployments, or for installs you want to survive the user deleting the shortcut.

## Reading user screenshots: don't guess

This is not a Windows-specific pitfall, but the Scrappy-Dood build hit it hard: I confidently misread the Edge "Load unpacked" dialog as a Microsoft Account sign-in prompt because the Hebrew layout put a password-masked field at the top. The result was a wrong, scary instruction ("don't enter your password there") and a confused user.

**The rule**: when the user pastes a screenshot of a UI you don't recognize, **never pattern-match to a known dialog from memory**. Instead:

- Quote the **exact text** you can see in the image (or use `vision_analyze` with a focused question — "read every Hebrew label and button literally") and use **that** to identify the dialog.
- If the dialog is in a non-English language you don't read, ask the user for the **page title** in the browser's address bar, or ask them to translate the **two largest buttons**. The page title is the most reliable signal.
- If after two reads you still can't identify the dialog, **say so explicitly** and ask for the user to translate — do not paper over uncertainty with a confident guess. A wrong confident answer wastes more user time than a transparent "I can't read this, what does it say?".

Specifically for the Edge 134+ "Load unpacked" / "חבילת הרחבה" dialog: the two buttons in the bottom-right are **"בסל"** (Cancel) and **"חבילה הרחבה"** (Install/Package). The dialog title bar reads "חבילת הרחבה" (Extension package). The "root directory" field is what the user must fill with the extension path; the "private key" field is OPTIONAL for first installs. This is *not* a sign-in dialog, *not* a credential prompt, *not* a Store listing. The right answer is "browse to the extension dir, leave the key field empty, click the rightmost button".
