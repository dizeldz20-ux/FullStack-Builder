# Reference: Don't ask the user when search answers the question

Companion to the `plan` skill pitfall of the same name. This file holds the **decision checklist** and a **worked counter-example** for the "ask first, look second" failure mode.

## The 4-question decision checklist

Before calling `clarify()`, walk through this. If you reach question 4 with a question still pending, you haven't searched hard enough.

```
1. SEARCH — does the answer exist somewhere I have access to?
   ↓ NO
2. DEFAULT — can I pick a reasonable default and ask for confirmation?
   ↓ NO (irreversible consequence, multiple plausible answers)
3. RESIDUAL — is this the only question I have left after search + default?
   ↓ NO (you're bundling questions; bundle = wasted turn)
4. ASK — ask ONE focused question with a default, in short labels.
```

If the answer to (1) is "yes" — use the search result, don't ask.
If the answer to (1) is "no" but (2) is "yes" — ask "default X, confirm?"
If the answer to (1)+(2) is "no" but the user has explicitly opted-in to being asked about this category (in `USER.md` or `MEMORY.md`) — ask with a default.
Otherwise — pick a default and proceed, with a one-line note: "defaulted to X, push back if wrong."

## Search sources, in priority order

| Source | How to query | Use when |
|---|---|---|
| Built-in memory / `USER.md` | Read at session start | "What's the user's preference for X?" |
| Vault `~/[hermes-config-dir]/memories/Hermes/` | `ls Brain/`, `ls Project\ Contexts/`, `read_file` | "What did we decide about X in the past?" |
| Active repo `AGENTS.md` | `read_file` if exists | "What are the project rules?" |
| Active repo source code | `read_file`, `grep`, `git log` | "What does the code do today?" |
| Prior sessions | `session_search query="<keywords>"` | "What did we work on / decide before?" |
| Hermes skills | `skill_view`, `search_files pattern=SKILL.md` | "Is there a skill for this class of work?" |
| `package.json` / `requirements.txt` / `Cargo.toml` | `read_file` | "What's the stack?" |
| Project docs (`docs/`, `README.md`, ADR files) | `read_file`, `search_files` | "What's the architecture decision?" |
| `~/.hermes/config.yaml` | `read_file` | "What keys/endpoints are configured?" |

## Worked counter-example (2026-06-24, build-product kickoff)

This is the session that produced the pitfall. the user asked for a "super-skill" to build products end-to-end, in skillsmith's standards. The agent did this:

```python
# Turn 1 — agent asks
clarify(question="אתה בונה מוצרים בעיקר ב:",
        choices=["TS/Node", "Python", "Go", "Rust"])

# Turn 2 — agent asks again
clarify(question="כשאתה אומר 'מוצר', איזה קנה מידה?",
        choices=["MVP prototype", "production web", "production desktop", "research tool"])

# Turn 3 — agent asks again
clarify(question="לאן לשמור את הסקיל החדש?",
        choices=["Global Hermes skills", "User-local skills", "Repo-specific", "Other (type your answer)"])
```

All three answers were already in the system:

- The user's `USER.md` says "מעדיף תקשורת בעברית" and the active profile has TS/Node primary, Python secondary, in the user's stack defaults embedded in prior skills (`incremental-hardening-refactor`).
- The user's `MEMORY.md` and `Project Contexts.md` referenced [your-other-product] (Electron + FastAPI + Hebrew RTL), [your-voice-product] (ElevenLabs Liam v3 + Deepgram), Agentic OS v0.1 (Next.js), and Jarvis (Tauri-style). That is "production scale" by definition.
- The user explicitly said, in the same conversation: "אצלך בwiki בכספת של obsidian" — which is `~/[hermes-config-dir]/memories/Hermes/`.

the user's reaction (verbatim):

> "לא הבנתי מה אתה רוצה לוודא מולי... אני לא יודע לך אמור להיות את כל המידע הרלוונטי כדי לתכנן איזה שלב נכון יותר ממני... אתה יודע יותר טוב ממני זה בטוח"

After this correction, the agent built the skill in one pass using the search results, without any more `clarify()` calls. The result is the `build-product` skill shipped at `~/.hermes/skills/software-development/build-product/`.

## When `clarify()` IS the right call

Not all questions are search-answerable. These are the cases where asking is correct:

1. **Irreversible decisions with no good default** — "private or public repo?", "delete existing or preserve?"
2. **Multi-candidate ambiguity** — "I see 3 products in your workspace, which one is this build for?"
3. **Empty initial state** — "Repo is empty. Build from scratch, or pull from a template?"
4. **User-stated preference to be asked** — `MEMORY.md` says "user wants to be asked about deploy targets specifically" → ask about deploy, don't default
5. **Scope lock** — "Is X in or out of scope for this slice?" when the answer shapes the entire plan
6. **Approval gates** — "OK to push to private GitHub?" / "OK to run `npm install`?" (these are not "what to do" questions, they are "is it OK to do X" questions — different category)

## The litmus test

If your `clarify()` question can be answered by `read_file`, `session_search`, or reading `MEMORY.md`, it's the wrong question. Find the answer, don't ask.

If your `clarify()` question is "is it OK to do X?" and X is irreversible, it's the right question. Ask.
