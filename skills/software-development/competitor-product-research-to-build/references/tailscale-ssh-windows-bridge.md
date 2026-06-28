# Tailscale SSH Bridge to Windows — Known Quirks

Captured during the June 2026 "Scrappy-Dood" research → build cycle. Use this when a Mode-B (personal/Hermes-integrated) build plan needs to SSH into a Windows laptop over Tailscale.

## TL;DR

1. **SSH user is `[ssh-user]@`, not the human Tailscale account.** `tailscale status` shows `dizel.dz20@` because that's the human's Tailscale identity, but Windows SSH accepts the local Windows account, which on a single-user Win11 box is `[ssh-user]`.
2. **Use the FQDN, not the IP.** IPs in Tailscale can change if DERP relays rotate. The FQDN `laptop.tail<id>.ts.net` is stable. Get it with `tailscale status` on either side.
3. **SCP actually works fine on this Tailscale SSH config — earlier "SCP blocked" advice is stale.** `scp -i ~/.ssh/hermes-laptop/id_ed25519 file.ext [ssh-user]@laptop.tail<id>.ts.net:staging-name.ext` works every time. The thing that *fails* is `cat local.txt | ssh user@host "cmd /c copy /Y con C:\path\file"` (Windows doesn't read stdin like Unix). **Default to `scp` for file transfer**, then `powershell -NoProfile -Command "Move-Item staging-name.ext final\path\file.ext -Force"` to put the file in its final location. Use heredoc / `Set-Content` only for short config files (<2k chars) where scp feels heavy. The "base64-encode big payloads inline" pattern is **broken at ~6-10kB** because of Windows command-line length limits and bash + SSH + PowerShell triple-quote corruption.
4. **PowerShell escaping is hell.** `powershell -Command "...$var..."` from bash mangles `$` and quotes. Two clean options:
   - **Option A**: `cat /tmp/foo.ps1 | ssh user@host "powershell -NoProfile -Command -"`
   - **Option B**: `ssh user@host "powershell -NoProfile -Command \"[ScriptBlock]::Create((Get-Content -Raw 'C:\probe.ps1'))\""` after staging the file via heredoc
5. **Default SSH key is `~/.ssh/hermes-laptop/id_ed25519`.** If `Permission denied (publickey)`, the public key has not been added to the laptop's `authorized_keys` — ask the user to run a one-line `Add-Content` on their end.

## The standard probe sequence

Run on the Hermes host (the [VaultRunner] container, not the laptop):

```bash
# 1. Confirm Tailscale sees the peer
tailscale status

# 2. Confirm the SSH key exists locally
ls ~/.ssh/hermes-laptop/
# Expected: id_ed25519  id_ed25519.pub

# 3. Test the bridge (FIRST try [ssh-user]@<fqdn>)
ssh -i ~/.ssh/hermes-laptop/id_ed25519 -o StrictHostKeyChecking=no \
    -o ConnectTimeout=8 -o BatchMode=yes \
    [ssh-user]@laptop.tail<id>.ts.net "echo BRIDGE_OK"
# Expected: BRIDGE_OK
# If "Permission denied": public key not authorized. Ask user to add it.
# If "Connection timed out": Tailscale not running on the laptop.

# 4. Run the environment probe
ssh -i ~/.ssh/hermes-laptop/id_ed25519 -o StrictHostKeyChecking=no \
    [ssh-user]@laptop.tail<id>.ts.net \
    "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& { $(Get-Content -Raw /root/hermes-environment-probe.ps1) }\""
```

For the full probe script, see `../templates/hermes-environment-probe.ps1`.

## What the probe tells you

- **OS + build** — Win11 26200 means recent build, supports modern Chromium extensions
- **Browser** — if Edge is installed and Chrome is not, build for Edge. If both, build for Chrome (better dev tooling) and the Edge install is a free bonus.
- **Runtimes** — Node 24 + no Python means the bridge is Node.js, not Python. `pwsh` vs `powershell 5.1` matters for script capabilities.
- **Chrome profiles** — tells you whether to install the extension in `Default` only or scope to a specific profile
- **HKCU write** — confirms the registry path `HKCU\Software\<Vendor>\NativeMessagingHosts\...` is writable, which is required for Chrome's native messaging
- **Tailscale state** — confirms the laptop is reachable from outside the LAN (Tailscale SSH = inbound-ready)

## Building a personal Chrome/Edge extension on this bridge

Once the probe passes, the standard install pattern is:

```
Laptop %LOCALAPPDATA%\HermesBridge\
├── bridge.js              # Node.js native messaging host
├── com.daniel.<name>.json # Native messaging manifest
└── recipes\               # Saved extraction recipes (JSON)
```

Registry (HKCU, no admin needed):
```
HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\com.daniel.<name>
HKEY_CURRENT_USER\Software\Microsoft\Edge\NativeMessagingHosts\com.daniel.<name>
```
Both point to the path of the `.json` manifest.

The manifest must specify `"allowed_origins": ["chrome-extension://<extension-id>/"]` for Chrome and `"allowed_extensions": ["<extension-id>"]` for Edge — get the extension ID from `edge://extensions` / `chrome://extensions` after Developer Mode install.

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `Permission denied (publickey)` | Public key not on laptop | User runs: `Add-Content $env:USERPROFILE\.ssh\authorized_keys (Get-Content <pubkey>)` |
| `Connection timed out` | Tailscale down on laptop, or laptop asleep | Wake the laptop; check `tailscale status` on the laptop |
| `bash: powershell: command not found` | Wrong SSH user (got a bash shell somehow) | Re-check user is `[ssh-user]@`, not `dizel.dz20@` |
| `scp: Connection closed` | Rare — was a transient error in one earlier session. Default to scp; if it does fail once, retry, and if still fails fall back to heredoc | Retry once; if still fails, use the heredoc pattern from TL;DR #4 |
| Extension can't find native host | Wrong registry path, or wrong path in manifest JSON | `chrome://extensions` → Service Worker → console will print the actual error |
