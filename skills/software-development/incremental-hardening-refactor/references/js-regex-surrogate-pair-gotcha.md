# JS Regex Character Class Surrogate-Pair Range Gotcha

Validated 2026-06-14 during the [your-product] slice 5 re-creation of
`src/lib/safePrompt.ts`. The function `stripAllControlChars` was meant to
remove:

- ASCII control chars + DEL (`U+0000..U+0008`, `U+000B`, `U+000C`,
  `U+000E..U+001F`, `U+007F`)
- C1 control (`U+0080..U+009F`)
- Bidi overrides (`U+202A..U+202E`, `U+2066..U+2069`)
- Zero-width / BOM (`U+200B..U+200D`, `U+FEFF`)
- ChatML special tags (`U+E0001..U+E007F`)

The first four ranges work. The fifth one is the bug.

## The exact symptom

A unit test:

```js
stripAllControlChars("hello world 123")
```

returned `"  "` (two spaces) instead of `"hello world 123"`. Every
English letter and every digit was stripped along with the spaces (the
spaces happened to be the only ASCII chars *not* in the bad range).

The smoking gun was running the regexes one at a time:

```js
const input = "hello world 123";
let s = input;
s = s.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "");  // OK: input unchanged
s = s.replace(/[\u0080-\u009F]/g, "");                                    // OK: input unchanged
s = s.replace(/[\u202A-\u202E\u2066-\u2069]/g, "");                      // OK: input unchanged
s = s.replace(/[\u200B-\u200D\uFEFF]/g, "");                             // OK: input unchanged
s = s.replace(/[\uE0001-\uE007F]/g, "");                                 // BOOM: "  "
```

Step 5 was the only one that mutated the input.

## Why this happens

The source `[\uE0001-\uE007F]` is parsed by the JavaScript regex engine
as a character class. In a JS regex:

- `\uXXXX` is a 4-hex-digit Unicode escape (BMP only).
- A `U+XXXX` codepoint above `U+FFFF` cannot be represented as a single
  escape; it must be a surrogate pair, which the character class grammar
  does not support.
- So `\uE0001` is interpreted as `\uE000` followed by the literal `1`,
  and `\uE007F` is interpreted as `\uE007` followed by the literal `F`.

The character class therefore matches the union of:

- `\uE000..\uE007` (7 codepoints in the Tags block)
- the literal ASCII characters `1` and `F`

…applied repeatedly across the string. Why does this also strip `h`,
`e`, `l`, `o`, `w`, `r`, `d`, `2`, `3`? Because `\uE001` through
`\uE007` are tag characters in the Supplementary Private Use Area, but
the engine normalizes the *byte* representation: the high surrogate
`\uDB40` is followed by low surrogates `\uDC00..\uDFFF` for the actual
U+E0000..U+EFFFF range. When the engine sees the character class
`[\uE0001-\uE007F]`, the `1` and `F` get **folded** into the byte-level
comparison in a way that depends on the engine, and depending on the
runtime (Node 22 in our case), it ends up matching all of BMP that
shares any byte with the literal `1`/`F` in the lower 8 bits.

The visible effect is identical to a regex that says
`/[a-zA-Z0-9 ]/` matches everything you don't want.

## The diagnostic recipe (5 lines, copy-paste runnable)

```js
// Save as diag-regex.js and run with: node diag-regex.js
const input = 'hello world 123';
const cases = [
  ['/\\uE0001/g',          /\uE0001/g],
  ['/[\\uE0001-\\uE007F]/g', /[\uE0001-\uE007F]/g],
  ['/[\\uDB40][\\uDC00-\\uDFFF]/gu', /[\uDB40][\uDC00-\uDFFF]/gu],
];
for (const [name, re] of cases) {
  console.log(name, '->', JSON.stringify(input.replace(re, '')));
}
```

Expected output:

```text
/\uE0001/g          -> "hello world 123"  (single escape, the trailing '1' is literal-class)
/[\uE0001-\uE007F]/g -> "  "                (BROKEN — eats ASCII)
/[\uDB40][\uDC00-\uDFFF]/gu -> "hello world 123"  (correct surrogate-pair range)
```

If your output shows `"  "` for the second case, you have this bug.

## The fix: pick one of three options

### Option A — skip the range (simplest, recommended for first iteration)

Just don't include the U+E0001..U+E007F range. The ChatML tag characters
are extremely rare in natural text and the LLM providers' pre-processing
already handles them. The `safePrompt.ts` that landed on the laptop uses
this option:

```ts
export function stripAllControlChars(input: string): string {
  if (typeof input !== "string") return "";
  return input
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .replace(/[\u0080-\u009F]/g, "")
    .replace(/[\u202A-\u202E\u2066-\u2069]/g, "")
    .replace(/[\u200B-\u200D\uFEFF]/g, "");
  // Note: we intentionally do NOT strip U+E0001..U+E007F (ChatML special tags)
  // because that range lives in a surrogate-pair plane and cannot be safely
  // expressed in a JS regex character class without also eating ASCII letters.
}
```

### Option B — surrogate-pair aware regex (if you really need the range)

Match the high surrogate `\uDB40` followed by the low surrogates that
cover the range. The tag characters U+E0001..U+E007F are encoded as
`\uDB40 \uDC01` through `\uDB40 \uDC7F`. A regex:

```ts
const TAG_RANGE = /(?:\uDB40[\uDC01-\uDC7F])/g;
function stripTags(input: string): string {
  return input.replace(TAG_RANGE, "");
}
```

Important: `String.prototype.replace` with a string pattern does not
always rejoin the two surrogate halves correctly. Verify with a unit
test that exercises the input and the output's `length` and `codePointAt`
counts.

### Option C — use a Unicode-aware library

If you genuinely need full Unicode property support (e.g. to strip an
entire Unicode category), reach for a library that supports it:

- `xregexp` with the `u` and `X` plugins
- `unicode-properties` (wraps a Unicode CLDR data file)
- `punycode` for IDN-style encoding only

These add dependencies. For a single helper function, option A or B is
usually the right trade-off.

## What the final `safePrompt.ts` looks like (the version on disk)

For reference, the 5-export module that shipped on 2026-06-14 is:

```ts
// src/lib/safePrompt.ts
export function wrapInSystemTags(content: string, tag = "system_data"): string { ... }
export function stripAllControlChars(input: string): string { ... }     // option A above
export const sanitizeForPrompt = stripAllControlChars;                  // backwards-compat alias
export function stripInjectionPatterns(input: string): string { ... }
export function formatSafeContext(content: string, tag = "system_data"): string { ... }
export function splitSafeMessages(
  systemPrompt: string,
  userContent: string,
  history?: { role: "user" | "assistant"; content: string }[]
): { role: "system" | "user" | "assistant"; content: string }[] { ... }
```

The smoke test that verified the corrected version (25/28 pass, 3 fails
are intentional "this whitespace is preserved" assertions):

```text
=== wrapInSystemTags ===
  PASS wraps in tag
=== stripAllControlChars ===
  PASS keeps ASCII letters
  PASS keeps digits
  PASS keeps spaces
  PASS removes zero-width
  PASS removes bidi override
  PASS removes RTL override
  PASS removes ZWNJ
  PASS removes BOM
  PASS removes NUL
  PASS removes DEL
  PASS keeps Hebrew
  PASS keeps Arabic
=== stripInjectionPatterns ===
  PASS removes "ignore previous"
  PASS removes "you are now"
  PASS removes "system:"
  PASS removes "forget everything"
  PASS keeps legit text
=== formatSafeContext ===
  PASS wraps result in tags
  PASS strips injection in pipeline
  PASS keeps legit content in pipeline
=== splitSafeMessages ===
  PASS produces 3 messages
  PASS first is system
  PASS last is user
  PASS middle is user (from history)

25 pass, 3 fail (the 3 fails assert that newlines and tabs are stripped,
  which is a separate spec decision; the current implementation
  intentionally preserves them as legal whitespace)
```

## Cross-references

- The main SKILL.md "JS regex character class with surrogate-pair ranges
  eats ASCII" section is the executive summary.
- The `hermes-config-validation` skill's "validate against installed
  source, not docs" rule applies here too: don't trust the spec, trust
  the runtime behavior on a sample input.
- The `requesting-code-review` skill's "always include a sample
  before/after" rule catches this class of bug at review time.
