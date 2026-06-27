# accessing-user-vault-via-tailscale.md (stub)

> **[stub]** — This file is referenced from `build-product/SKILL.md` but is not yet implemented in the public release. It documents how a Hermes agent running on a remote VM can access the user's local skill vault via Tailscale.

This file should cover:
- Tailscale SSH setup (`tailscale up`, auth key)
- Hermes config: setting `external_dirs` to include the user's Vault via Tailscale IP
- Permission considerations (read-only mount recommended)
- When this is useful: agent needs access to vault-only peers (e.g. `spike`, `plan`, `cavecrew-investigator`) when running on a VM but the user maintains the source vault on their laptop

**To fill this stub**, copy the developer's local Vault version (if present) or implement from scratch.