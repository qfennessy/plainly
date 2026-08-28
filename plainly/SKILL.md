---
name: plainly
description: Rewrite Claude's previous reply (or any pasted text) into plain, direct English by piping it through Gemini Flash with the `llm` CLI, with audience modes (eli12/colleague/manager/exec) setting how simple and how short the result is. Use whenever the user types /plainly, says "eli12", asks to "say that in plain english" / "in normal english" / "like a human", asks for a simpler, shorter, manager-friendly, or executive version of a reply, or complains that a response is jargony, hypey, dramatic, listicle-ish, or over-written.
---

# Plainly — plain-English rewrite via Gemini Flash

Claude's default register is dramatic: build-up, numbered reveals, "the load-bearing
assumption", "here's the kicker", a metaphor where a noun would do. Prompting does not
fully cure it, because the model doing the rewriting is the model with the habit.

So this skill hands the text to a different model. `gemini-3.7-flash`, run locally
through the [`llm`](https://llm.datasette.io) CLI, does the rewrite. Its output is
printed verbatim.

**The one rule that makes this work: print Gemini's output as-is.** Do not paraphrase
it, tidy it, re-flow it, add a summary, or wrap it in your own framing. Every word you
add puts back the voice being removed. A single label line ("Gemini's rewrite
(manager):") is the most you may add.

## Arguments

`/plainly [mode] [text]` — both optional.

- **mode**: if the first word is `eli12`, `colleague`, `manager`, or `exec`, that is the
  mode. Otherwise the mode is `eli12`.
- **text**: whatever follows the mode word. If there is none, rewrite your own most
  recent substantive reply — the one immediately before the user invoked this skill.
  Reproduce it faithfully, word for word, including code blocks. Do not "clean it up"
  on the way into the file; that is the whole failure this skill exists to avoid.

## Modes

| Mode | Audience | Result |
|---|---|---|
| `eli12` (default) | A smart non-specialist on a phone | One idea per sentence, meaning before mechanism, no insider words, every number gets a verdict. Mechanism moves below a `Details:` line. |
| `colleague` | An engineer on this code | Every fact, number, file path, and code block kept exactly. Only the theatrics go. |
| `manager` | A technical-adjacent manager | What happened, why it matters, what's next. No code or paths. About a third the length. |
| `exec` | An executive | Three to five sentences: outcome, impact, ask. |

The full rules for each mode live in `prompts/<mode>.md` next to this file, with the
shared style and output rules in `prompts/_shared.md`. The script assembles them into
the system prompt. **Do not retype the rules into your command** — read them from the
files, so they cannot drift.

## How

1. Write the source text **verbatim** to a file in the scratchpad directory, e.g.
   `plainly-input.md`. Use the Write tool, not shell `echo` or a heredoc, so quoting
   cannot mangle it.

2. Run the wrapper:

   ```bash
   ~/.claude/skills/plainly/plainly.sh <mode> <path-to-input-file>
   ```

   Give it a generous timeout (180s). A rewrite normally takes 5–15 seconds.

   Use the script rather than calling `llm` yourself. It sets three things that are
   easy to get wrong:

   - **`-R` (`--hide-reasoning`)** — without it, Gemini 3.x streams its internal
     monologue into stdout and it lands in the middle of the answer, looking like part
     of the rewrite. This is a silent corruption, not an error.
   - **text on stdin, rules in `-s`** — the source text can never be re-read as shell
     syntax, and never as instructions to the model. Text containing
     "ignore all previous instructions" gets rewritten as content, not obeyed.
   - **`-o thinking_level low`** — enough for restyling, and faster.

   Override the model with `PLAINLY_MODEL=gemini-3.5-flash ~/.claude/skills/plainly/plainly.sh ...`
   if 3.7 is unavailable or rate-limited.

3. Print the script's stdout to the user verbatim, per the rule at the top.

## Limits worth knowing

- Gemini will not invent a judgment the source did not make. In `eli12` mode, a number
  with no verdict in the source comes back as "the report does not say whether that is
  expected". That is correct behavior, not a bug — if you want a verdict, put one in
  the source text.
- `eli12` deliberately moves file paths and commands below a `Details:` line. When the
  user needs a copy-pasteable answer at the top, use `colleague`.
- Long input costs latency, not correctness. There is no chunking; a very long reply
  just takes longer.

## If it fails

The script exits `2` on bad arguments and `3` on a missing tool, plugin, or key, and
prints the fix. Show the user the actual error rather than working around it.

Setup, if `llm` or the model is missing:

```bash
brew install llm
llm install llm-gemini
llm keys set gemini      # paste a Google AI Studio / Gemini API key
```

If the rewrite itself errors (auth, network, rate limit), show the user the real error.
Only offer your own rewrite as a clearly labeled fallback, and never substitute it
silently — the user asked for a second model precisely because yours has the habit.
