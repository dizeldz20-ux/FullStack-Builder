# [your-product] — Verified Architecture (2026-06-14)

Ground-truth map of the [your-product] codebase, verified by reading the source code on 2026-06-14 after the previous session's `pipeline.ts` claims turned out to be fabricated. Use this whenever the user says "[your-product]" or refers to the app at `C:\Users\[your-username]\OneDrive\שולחן העבודה\[your-product]`.

## 1. The real subsystems (no "Pipeline")

The codebase does **not** contain `src/lib/pipeline.ts`, `src/app/api/pipeline/*`, or anything called "Pipeline". The earlier session's "buildArtifact", "designSpec", "Shape it", and "עצב את הרעיון" do not exist in the code.

The real subsystems are:

- **Missions** (`src/lib/missions/*`, `src/app/api/missions/*`, `src/app/missions/*`, `src/components/missions/*`) — the kanban + agent dispatch UI
- **Hermes** (`src/app/api/hermes/*`, `src/components/HermesPanel.tsx`, `src/lib/hermesBridge.ts`) — the LLM bridge client
- **Codex** (`src/app/api/codex/*`, `src/app/codex/*`, `src/components/CodexView.tsx`) — Codex CLI delegation UI
- **FreeClaude / FCC** (`src/app/api/freeclaude/*`, `src/app/freeclaude/*`, `src/lib/fcc.ts`, `src/lib/freeClaudeWorkspace.ts`) — the FCC CLI panel and scratch workspace
- **[VaultRunner]** (`src/app/api/[vault-runner]/*`, `src/app/[vault-runner]/*`, `src/lib/[vault-runner]Bridge.ts`) — cloud-agent panel
- **Antigravity (AGY)** (`src/app/api/antigravity/*`, `src/app/antigravity/*`, `src/lib/antigravityCli.ts`) — cloud + vault panel
- **Kanban** (`src/app/api/hermes/kanban/*`, `src/components/missions/KanbanBoard.tsx`) — cross-mission kanban
- **Goals** (`src/app/api/goals/*`, `src/app/goals/*`, `src/components/GoalsView.tsx`) — goals subsystem
- **Missions Stream** (`src/app/api/missions/stream/route.ts`) — SSE for live mission logs
- **Other**: seo, video (heygen/hyperframes), notebooklm, notebook, architecture, journal, memory, voice (separate from freeclaude), claude panel, missions-api

## 2. Missions lifecycle (the "shape it" question, answered)

The user asks "why doesn't Shape it show a preview?" The answer:

**There is no Shape it step. There is no design spec UI.** The Mission creation flow is:

1. `NewMissionDialog` opens → user fills title + prompt + delegate mode (single | fanout) + delegateTo (default `[vault-runner]`)
2. `onCreateAndStart` → POST `/api/missions` (creates mission in `backlog`) + starts the workflow
3. `hermesAdapter.runMissionWorkflow`:
   - `kickoff` = `startMission` → `dispatch(prompt)` → `bridgeCall` POST `{hermesBridgeUrl}/v1/message`
   - If workflow delegates, `callDelegateAgent(agent)` per agent in the workflow.delegates list
   - If `returnToHermes` is true (default), the delegate reports go back to Hermes for a "board update" pass
4. Live logs stream via SSE from `/api/missions/stream`

The `workflow.plan` is a string, max 8000 chars, sent to Hermes as part of the prompt. It is **not** a UI-rendered structured deliverable.

**If the user wants a "Shape it" step with a design-spec preview**, that UI has to be built. A reasonable plan:

- New server-side artifact type: `designSpec` (structured: { goals, audience, milestones, agentAssignments, risks })
- 3rd mode in NewMissionDialog between "form" and "running": "preview"
- New API route: `POST /api/missions/<id>/plan` that calls Hermes, parses the structured spec, returns it
- User sees preview, can edit, then clicks "start" → workflow runs

This is a 2-3 slice feature, not a 1-line fix.

## 3. The five delegate agents (who actually builds what)

| Agent | Implementation | Spawn | CWD isolation |
|---|---|---|---|
| `hermes` | `dispatch()` default | `bridgeCall` (POST to bridge) or `localCall` (spawn `hermes` CLI) | `ensureAgentWorkspace("hermes")` |
| `codex` | `callCodexDelegate` | `run("codex", codexExecArgs, { input: prompt })` | `ensureCodexWorkspaceRoot()` |
| `claude` | `callDelegateAgent` default branch | `run("claude", ["-p", prompt], { cwd })` | `ensureAgentWorkspace("claude")` |
| `fcc` | `callDelegateAgent` FCC branch | `run("claude", ["--bare", "-p", "--no-session-persistence", prompt], { env: fccClaudeEnv() })` | `ensureAgentWorkspace("fcc")` |
| `[vault-runner]` | `call[VaultRunner]Delegate` | `call[VaultRunner]Bridge` (cloud) or `run("[vault-runner]", [...])` (local fallback) | per-mode |
| `antigravity` | `callAntigravityDelegate` | `runAntigravityPrint(prompt, opts)` | `ensureAgentWorkspace("antigravity")` |

`runner.ts` is the shared spawn wrapper. It uses `process.spawn` with explicit `env` (no wholesale `process.env` inheritance), `cwd`, and `timeoutMs`.

`fccClaudeEnv()` returns `{ ...process.env, ANTHROPIC_BASE_URL: fccBaseUrl(), ANTHROPIC_API_KEY: fccApiKey(), ANTHROPIC_AUTH_TOKEN: fccApiKey(), CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY: "1", CLAUDE_CODE_AUTO_COMPACT_WINDOW: "190000" }`. This routes the spawned `claude` CLI at FCC's local gateway (`http://127.0.0.1:8082` by default), so FCC's Claude calls are isolated from the user's own Claude subscription.

## 4. FreeClaude's scratch dir (the "where did the file go" question)

The user sees files at `C:\Users\[your-username]\freeclaude-scratch\<project>\<file>.html` and asks "who built this and where?" The answer:

- `src/lib/freeClaudeWorkspace.ts` → `FCC_SCRATCH_ROOT = process.env.AGENTIC_OS_FCC_SCRATCH ?? path.join(os.homedir(), "freeclaude-scratch")`
- Project name is regex-validated: `^[A-Za-z0-9_.-]+$`
- Files land there because the spawned `claude --bare -p ...` CLI process, run with `cwd = <project>`, uses its own `Write`/`Edit`/`Bash` tools to create them
- Agentic OS does **not** write the file itself. The FCC CLI writes the file, Agentic OS only knows about it via the workspace API
- `src/app/api/freeclaude/preview/[...path]/route.ts` is the read-only viewer; the file comes from disk via `freeClaudeWorkspace.readProjectFile(project, relPath)`

## 5. The shared-fist memory protocol

From `AGENTS.md`:

> Agentic OS uses a strict `Shared-First` memory model.
>
> - Treat the configured vault path `Agentic OS/Shared Memory/` as the single source of truth for cross-agent operational knowledge.
> - At the start of every agent task, read Shared Memory first: `README.md`, `Protocol.md`, recent `Ledger.md` / `ledger.jsonl` entries, and any relevant shared notes.
> - At the end of every meaningful task, append one structured update through Agentic OS memory logging (`/api/memory/log` or `appendMemory`) with `timestamp`, `agent`, `fact`, `action`, and `status`.
> - Agent-specific `Agents/<Agent>/Sessions/` and `Agents/<Agent>/Workspace/` are cache only. Do not leave durable decisions, facts, or handoffs only in private memory.
> - Shared writes are append-only and lock-protected.

If a sub-agent (in `delegate_task` or any of the delegate systems) needs to write a fact that other agents will see, it goes to `Agentic OS/Shared Memory/`, not to its own private `MEMORY.md`.

## 6. Branches and where to look first

```
origin/main                     # db0a218, 4 commits, the lean version
origin/pack-merge-2026-05       # 728f634, 21+ commits, the rich version with missions/kanban/notebooklm/seo/video
local-pack (tracking origin/pack-merge-2026-05)
```

**`pack-merge-2026-05` is where Missions + the 5-agent system live.** Don't waste time on `main` looking for these subsystems.

The local copy at `/root/.hermes/workspaces/[your-product]` may be a few days behind the laptop's HEAD. Verify freshness with `git fetch origin && git log HEAD..origin/pack-merge-2026-05 --oneline`. If non-empty, the laptop is ahead.

## 7. The 4 bugs the previous session missed (and the smoke to catch them)

Each of these is a real bug in the current `pack-merge-2026-05` branch, identifiable from the code, that the previous session's fabricated "build succeeded" report glossed over:

1. **`buildArtifact` returning 200 with garbage content** — if/when a build route exists, the bridge-backed model can return a chat-style apology on a continuation turn. Output-side validation (DOCTYPE, `</html>`, length > 5000) is the only reliable guard.
2. **`classifyIdea` stuck on `route: "escalate", confidence: 0.5`** — the JSON parse fallback always returns this. Tighten the planner system prompt to demand fenced JSON output, parse the first JSON block.
3. **`localeCompare` on non-string `created`** — `listItems` sort crashes if `created` is `Date` or `number`. Hardened by `String(b.created || "").localeCompare(String(a.created || ""))` in similar list-sort code.
4. **`maxTokens: 1400` for a 9-section Design Spec prompt** — under-sized token budget, output truncates to ~1.2K tokens, user sees "the plan was vague". Real fix: 3500+ with fallback threshold > 600.

For each, the smoke is: don't trust the API response. Read the actual file back from disk / the actual JSON back from the LLM, assert the content you expected.

## 8. The 5 files that would be touched in any "shape it" / "preview" feature

If you build a design-spec preview feature, these are the surfaces to touch (rough sketch — not a plan):

1. `src/lib/missions/types.ts` — add `designSpec?: DesignSpec` to `Mission` interface, add `DesignSpec` type with { goals, audience, milestones, agentAssignments, risks }
2. `src/lib/missions/hermesAdapter.ts` — add `draftDesignSpec(mission)` that calls `dispatch` with a structured-output prompt and parses the JSON
3. `src/lib/missions/store.ts` — `update` already handles arbitrary patches, but add validation for the `designSpec` field
4. `src/app/api/missions/route.ts` (POST) — optionally accept a "draftOnly" flag that runs `draftDesignSpec` and returns it without dispatching delegates
5. `src/components/missions/NewMissionDialog.tsx` — add the 3rd "preview" mode, render the spec, gate the "start" button on user approval

This is a 1-2 day build, not a 1-hour patch. Don't promise otherwise.
