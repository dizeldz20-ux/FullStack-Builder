<purpose>
Refine a vague product idea, Kanban card, or feature request into an execution-ready specification by asking up to 3 high-value clarification questions, then producing a final markdown spec.
</purpose>

<user-story>
As a product owner with a messy idea, I want the agent to ask 1-3 focused questions, then deliver a complete specification, so that downstream skills (`prd-generator`, `plan`, `build-feature`) can execute without further clarification.
</user-story>

<when-to-use>
- "I have an idea for X but it's vague" — turn it into a spec
- A Kanban card has a 1-line description that needs expansion
- A feature request needs scope/non-scope, users, and acceptance criteria before `prd-generator` can run
- User explicitly invokes `/amrita-architect refine`
</when-to-use>

<context>
- The original idea (1-3 sentences from the user)
- The target product or codebase (if any)
- Existing Kanban card or task (if applicable)
</context>

<references>
@../references/corrected-architecture.md (when the original idea touches Hermes Kanban architecture decisions)
@~/.config/hermes/skills/software-development/build-product/frameworks/user-defaults.md (when the spec needs stack/security defaults)
@~/.config/hermes/skills/software-development/prd-generator/SKILL.md (the next step after the spec is ready)
</references>

<steps>

<step name="read_idea" priority="first">
Read the user's original idea verbatim. If the idea is a Kanban card, load the full card context. Confirm: "Working from: [idea text]. Continue?"
</step>

<step name="classify_gaps">
Internally classify information into 3 buckets:
- **Resolved** — what is already clear
- **Active gaps** — decisions that materially affect UX, architecture, security, cost, or scope
- **Assumptions** — defaults that can be safely assumed to keep progress moving

Do not share this internal classification with the user. Use it to decide which questions are worth asking.
</step>

<step name="ask_questions" priority="block">
If active gaps exist, ask up to 3 focused questions, one at a time. Stop asking as soon as the remaining gaps would not change the spec materially.

Each question must:
- Be concrete and answerable in 1-2 sentences
- Not be compound (no "and" in the question)
- Offer sensible defaults if the user is unsure

If no active gaps exist, skip this step and proceed directly to deliver the spec.
</step>

<step name="verify_threshold">
Before finalizing, ensure these 9 areas are clear OR explicitly assumed:
1. Objective and success criteria
2. User / persona / operator
3. Primary workflow
4. In scope / out of scope
5. Data, privacy, security, permission constraints
6. Interfaces and integrations
7. Edge cases and failure modes
8. Acceptance criteria and QA checks
9. Implementation slices or follow-up tasks

If any are unclear and would change the spec, ask one more question. Otherwise mark as an explicit assumption in the spec.
</step>

<step name="deliver_spec">
Produce the final spec using the format in `amrita-architect` SKILL.md §"Final deliverable template". Save it to:
- Kanban: as a card comment via `kanban_complete`
- Local: as `specs/{idea-slug}.md` in the project root

If running as a Kanban worker, call `kanban_complete` with the markdown deliverable.
If not running inside a Kanban worker, just write the file and tell the user the path.
</step>

</steps>

<output>
A markdown spec at `specs/{idea-slug}.md` (or as a Kanban card comment) containing:
- Objective
- Scope (in/out)
- Users / actors
- Core workflows
- Functional + non-functional requirements
- Data, privacy, security
- Integrations / interfaces
- Edge cases + failure modes
- Acceptance criteria
- Implementation slices

Format: plain markdown, no frontmatter.
</output>

<acceptance-criteria>
- [ ] Up to 3 questions asked, only when material to the spec
- [ ] All 9 areas in the threshold are either resolved or explicitly assumed
- [ ] Spec follows the canonical template from SKILL.md
- [ ] Spec is saved to the right location (Kanban comment or local file)
- [ ] If assumptions were made, they are listed in the spec
- [ ] No filler questions to reach 3
</acceptance-criteria>
