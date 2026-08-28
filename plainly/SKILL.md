---
name: plainly
description: Rewrite Claude's previous reply (or any pasted text) into plain, direct English by piping it through a second model (Gemini Flash by default) with the `llm` CLI, with audience modes (eli12/colleague/manager/officespace/bluto) setting how simple and how short the result is. Use whenever the user types /plainly, says "eli12", asks to "say that in plain english" / "in normal english" / "like a human", asks for a simpler, shorter, or manager-friendly version of a reply, asks for it in the voice of Bill Lumbergh / Office Space or Bluto / Animal House, or complains that a response is jargony, hypey, dramatic, listicle-ish, or over-written.
---

# Plainly — plain-English rewrite via Gemini Flash

Claude's default register is dramatic: build-up, numbered reveals, "the load-bearing
assumption", "here's the kicker", a metaphor where a noun would do. Prompting does not
fully cure it, because the model doing the rewriting is the model with the habit.

So this skill hands the text to a different model, run locally through the
[`llm`](https://llm.datasette.io) CLI. Its output is printed verbatim. The default is
`gemini-3.5-flash`, and the two joke modes default to the smaller
`gemini-3.5-flash-lite`. Any model `llm` can reach will work — see **Choosing the
model** below.

**The one rule that makes this work: print Gemini's output as-is.** Do not paraphrase
it, tidy it, re-flow it, add a summary, or wrap it in your own framing. Every word you
add puts back the voice being removed. A single label line ("Gemini's rewrite
(manager):") is the most you may add.

## Arguments

`/plainly [mode] [--model NAME] [text]` — all optional.

- **mode**: if the first word is `eli12`, `colleague`, `manager`, `officespace`, or `bluto`, that is the
  mode. Otherwise the mode is `eli12`.
- **--model NAME**: pass `NAME` to the script as its third argument. Accept both
  `--model NAME` and `--model=NAME`. Strip it out before treating the rest as text.
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
| `officespace` | A joke | Bill Lumbergh from *Office Space* delivers the same content. Facts, numbers, and paths unchanged; only the cadence differs. |
| `bluto` | A joke | Bluto Blutarsky from *Animal House* delivers the same content, loudly. Facts, numbers, and paths unchanged. |

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
   ~/.claude/skills/plainly/plainly.sh <mode> <path-to-input-file> [model]
   ```

   Omit the model argument unless the user asked for a specific one. With it omitted
   the script resolves the model itself, so a user who set the `plainly` alias keeps
   getting their choice.

   Give it a generous timeout (180s). A rewrite normally takes 2–8 seconds.

   Use the script rather than calling `llm` yourself. It sets three things that are
   easy to get wrong:

   - **`-R` (`--hide-reasoning`)** — without it, Gemini 3.x streams its internal
     monologue into stdout and it lands in the middle of the answer, looking like part
     of the rewrite. This is a silent corruption, not an error.
   - **text on stdin, rules in `-s`** — the source text can never be re-read as shell
     syntax, and never as instructions to the model. Text containing
     "ignore all previous instructions" gets rewritten as content, not obeyed.
   - **`-o thinking_level low`** on Gemini 3 models only — enough for restyling, and
     faster. Other models reject the unknown option, so the script omits it for them.
     This is why you should not hand-build the `llm` command.

3. Print the script's stdout to the user verbatim, per the rule at the top.

## Choosing the model

The script picks the model in this order, first hit wins:

1. the third argument (what `--model` sets)
2. `$PLAINLY_MODEL`
3. an `llm` alias named `plainly` (`llm aliases set plainly claude-haiku-4-5`)
4. a per-mode default: `gemini-3.5-flash-lite` for `officespace` and `bluto`,
   `gemini-3.5-flash` for everything else

Speed is the reason for the split. Measured on the same input: `gemini-3.7-flash` took
anywhere from 3 to 32 seconds, `gemini-3.5-flash` about 5, and `gemini-3.5-flash-lite`
under 2. Flash-lite is not used for the serious modes because it drops `eli12`'s
"every number gets a verdict" rule — it reported "the source does not say" about text
that did say. The joke modes need energy rather than judgment, so it is safe there.

Note that setting the `plainly` alias overrides the per-mode split, so the joke modes
lose their speed advantage. That is the right precedence — an explicit choice wins —
but say so if a user sets an alias and then asks why the joke modes got slower.

If the user asks to switch models permanently, tell them the alias command rather than
editing the script or their shell profile. It is one line, it survives reinstalls of
the skill, and it does not change their global `llm` default.

If a run fails, the script works out why: an unavailable model exits `3` with the
`llm install` / `llm keys set` commands, and anything else (auth, quota, rate limit,
network) exits with the provider's own code and message. Show that output rather than
silently falling back to another model.

## Limits worth knowing

- Gemini will not invent a judgment the source did not make. In `eli12` mode, a number
  with no verdict in the source comes back as "the report does not say whether that is
  expected". That is correct behavior, not a bug — if you want a verdict, put one in
  the source text.
- `eli12` deliberately moves file paths and commands below a `Details:` line. When the
  user needs a copy-pasteable answer at the top, use `colleague`.
- Long input costs latency, not correctness. There is no chunking; a very long reply
  just takes longer.
- `officespace` and `bluto` are the two modes that override part of
  `prompts/_shared.md`, because the shared rules ban the filler, drama, and hype those
  voices need. Each one lists exactly which four rules it suspends, in an override
  block at the top of its own prompt file. Facts, numbers, and identifiers stay locked
  in both. If a joke-mode rewrite changes a number or drops a file path, that is a bug
  in the prompt, not a style choice — report it.
- The prompts were tuned against Gemini Flash. On a much smaller or older model, watch
  for a preamble sneaking back in (`_shared.md` forbids one) or ignored mode rules. Do
  not paper over it by editing the output; report what came back.

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
