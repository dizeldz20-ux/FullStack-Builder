# LLM Multi-Section Prompt Sizing — Worked Example

**Session:** 2026-06-14, [your-product] `/api/pipeline/shape` audit
**Author:** Hermes Agent
**Status:** validated end-to-end on live dev server (port 3001)

## Symptom in the user's words

> "אני לוחץ על עצב ותכנן את הרעיות זה רק מעביר את זה לאישור אנושי ללא תוכנית עבודה מפורטת מאוד שיכולה לעזור לך לבנות את זה"

Translation: when the user clicks "Shape it" on a new idea, the system moves the item to "review" with a vague plan instead of a detailed, multi-section design spec that could actually drive the build.

## Diagnosis in 4 steps

### 1. Count the sections required by the prompt

`src/lib/pipeline.ts:267-318` defines `draftDesignSpec` with a system prompt asking for **9 sections**:

```
# Design Spec — <title>
## 1. Concept
## 2. Information Architecture
## 3. Visual System
## 4. Core Components
## 5. UX Flow
## 6. Motion & Micro-interactions
## 7. Content Skeleton
## 8. Implementation Notes
## 9. First Milestones
```

### 2. Estimate expected output tokens

Each section needs real, opinionated content (not just a heading):
- Concept: 80-150 tokens
- IA: 150-300 tokens
- Visual System: 250-400 tokens
- Core Components: 300-500 tokens
- UX Flow: 150-250 tokens
- Motion: 150-300 tokens
- Content Skeleton: 150-250 tokens
- Implementation: 100-200 tokens
- First Milestones: 80-150 tokens

**Total expected: ~1,500-2,500 tokens** of useful content.

### 3. Compare to the actual budget

The original call was:

```ts
const out = await chat(sys, `Project: ${title}\nIdea: ${idea.slice(0, 1500)}\nTags: ${tags.join(", ")}`, 1400, signal);
if (out && out.length > 200) return out;  // 200 chars ≈ 60 tokens
```

**`max_tokens: 1400` truncates a 2,500-token expected output to ~56% of the spec.** The result is sections 1-5 with shallow bullets, then the rest is cut off. The fallback threshold (`out.length > 200`) checks for ~60 tokens — which any half-finished reply will pass — so the fallback template never kicks in either.

### 4. Confirm with a live smoke

A real `capture → shape` cycle on the live dev server produced a 696-byte HTML file for an unrelated test, but the design spec test below failed because the LLM had no `route === "project"` path triggered — separate issue (classifier threshold) — see the companion file.

What we did confirm end-to-end:

- After the fix, the 6/6 smoke matrix passed (status codes + payload sizes).
- The `decide` route, which now calls `breakIntoTasks` on `designSpec || plan`, ran and produced tasks.

## The fix commits

### Commit `b95513a` — `fix(pipeline): give "Shape it" room to produce a real Design Spec`

Three coordinated changes in `src/lib/pipeline.ts` and `src/app/api/pipeline/decide/route.ts`:

```diff
# src/lib/pipeline.ts:312
-  const out = await chat(sys, `Project: ${title}\nIdea: ${idea.slice(0, 1500)}\nTags: ${tags.join(", ")}`, 1400, signal);
-  if (out && out.length > 200) return out;
+  const out = await chat(sys, `Project: ${title}\nIdea: ${idea.slice(0, 1500)}\nTags: ${tags.join(", ")}`, 3500, signal);
+  if (out && out.length > 600) return out;
```

```diff
# src/lib/pipeline.ts:400
-    `Project: ${title}\n\nPlan:\n${plan.slice(0, 2000)}\n\nOutput the checklist now:`, 600, signal,
+    `Project: ${title}\n\nPlan:\n${plan.slice(0, 2000)}\n\nOutput the checklist now:`, 1500, signal,
```

```diff
# src/app/api/pipeline/decide/route.ts:24
-    if (item.plan && !item.tasks) item.tasks = await breakIntoTasks(item.title, item.plan, req.signal);
+    if ((item.plan || item.designSpec) && !item.tasks) item.tasks = await breakIntoTasks(item.title, item.designSpec || item.plan, req.signal);
```

### Diff verification

```bash
$ git diff --no-color -- src/lib/pipeline.ts src/app/api/pipeline/decide/route.ts
diff --git a/src/app/api/pipeline/decide/route.ts b/src/app/api/pipeline/decide/route.ts
@@ -21,7 +21,7 @@ export async function POST(req: Request) {
   try {
-    if (item.plan && !item.tasks) item.tasks = await breakIntoTasks(item.title, item.plan, req.signal);
+    if ((item.plan || item.designSpec) && !item.tasks) item.tasks = await breakIntoTasks(item.title, item.designSpec || item.plan, req.signal);
   } catch { /* tasks are best-effort */ }
diff --git a/src/lib/pipeline.ts b/src/lib/pipeline.ts
@@ -309,8 +309,8 @@
-  const out = await chat(sys, `Project: ${title}\nIdea: ${idea.slice(0, 1500)}\nTags: ${tags.join(", ")}`, 1400, signal);
-  if (out && out.length > 200) return out;
+  const out = await chat(sys, `Project: ${title}\nIdea: ${idea.slice(0, 1500)}\nTags: ${tags.join(", ")}`, 3500, signal);
+  if (out && out.length > 600) return out;
@@ -397,7 +397,7 @@
-    `Project: ${title}\n\nPlan:\n${plan.slice(0, 2000)}\n\nOutput the checklist now:`, 600, signal,
+    `Project: ${title}\n\nPlan:\n${plan.slice(0, 2000)}\n\nOutput the checklist now:`, 1500, signal,
```

Clean 4-line diff across 2 files. No BOM, no encoding noise.

## Smoke test results

Live test on port 3001 (after the fix):

```text
[PASS] health        status=200 expect=200
[PASS] list          status=200 expect=200
[PASS] capture-bad   status=400 expect=400
[PASS] shape-missing status=404 expect=404
[PASS] decide-missing status=404 expect=404
[PASS] build-missing  status=404 expect=404
---SUMMARY pass=6 fail=0
```

## Adjacent issues discovered (NOT fixed in this commit)

1. **`buildArtifact` returns 200 with garbage** — see SKILL.md pitfall `buildArtifact` returning 200 with garbage content. The HTML saved to `FCC_SCRATCH_ROOT` was a "please share the existing HTML" apology reply, not a build.
2. **Classifier returns `escalate` 100% of the time** — the LLM classifier prompt may be misaligned with the model picked by the bridge. Out of scope for the spec-sizing commit; needs a separate fix on the classifier system prompt or a model pin.
3. **`localeCompare` crash on non-string `created`** — caught live during the smoke and fixed in a follow-up commit `a7dec6f` (one-line `String()` wrap).

## Rule of thumb to reuse

When patching a `chat()` / `chatOnce()` call that asks for a multi-section deliverable, count the sections and budget **at least 350-500 tokens per section** of `max_tokens`. The fallback threshold (e.g. `out.length > N`) should be **at least 100-200 tokens per section** to require real content rather than partial bullets. If the threshold is lower, the fallback template never fires and the user sees a truncated-but-accepted reply.

| Sections | `max_tokens` min | Fallback threshold min (chars) |
|---|---|---|
| 1-2 | 600 | 200 |
| 3-4 | 1500 | 500 |
| 5-7 | 2500 | 800 |
| 8-10 | 3500 | 1200 |
| 10+ checklist | 2000-3000 | 600-1000 |
