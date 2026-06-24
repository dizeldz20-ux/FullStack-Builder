# Amrita Corrected Architecture Reference

Amrita must be implemented as a Hermes-native Kanban refinement workflow, not as a global system prompt replacement or a shadow task tracker.

## Correct split

- Global prompt: minimal Kanban isolation principles only, if ever needed.
- Skill: `amrita-architect` owns refinement behavior.
- Kanban tools: source of truth for task state, comments, block/complete lifecycle.
- Optional future tool: only after real usage proves structured Amrita state is needed.

## Rejected original choices

- Do not deploy “exactly 3 questions every turn” globally.
- Do not create `task_embedded_tracker` as a skill pretending to be a tool.
- Do not store state in `./.agentic_os/task_chats_context.json`.
- Do not mutate `./.agentic_os/active_kanban_board.json`.
- Do not swallow persistence errors with `except Exception: pass`.
- Do not auto-complete tasks when unresolved blockers remain.

## Preferred workflow

1. `kanban_show`
2. Mirror objective.
3. Track resolved specs, active gaps, and assumptions.
4. Ask up to 3 focused questions if needed.
5. `kanban_comment` + `kanban_block` when user input is required.
6. Generate final markdown spec when ready.
7. `kanban_complete` only when no critical blockers remain.

## Future plugin criteria

Only create Amrita-specific tools if Kanban comments/metadata become insufficient. Any future state tool must use Hermes profile-aware storage, schema versioning, explicit errors, locking/concurrency control, and Kanban task scoping.
