# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Claude Code skill. It sends Claude's last reply to a second model (through Simon
Willison's `llm` CLI) and prints the plain-English rewrite word for word. The whole
point is that Claude does not do the rewriting and does not touch the result. The
default model is `gemini-3.7-flash`; any model `llm` can reach works.

There is no build, lint, or test suite. The only runtime is bash + `llm`.

## Commands

Run the script directly against a file (this is the smoke test):

```bash
plainly/plainly.sh eli12 path/to/some-reply.md
plainly/plainly.sh colleague path/to/some-reply.md
plainly/plainly.sh officespace path/to/some-reply.md gpt-4o-mini  # model as 3rd arg
PLAINLY_MODEL=gpt-4o-mini plainly/plainly.sh manager path/to/some-reply.md
```

Exit codes: `2` bad arguments or unknown mode, `3` missing `llm` or an unavailable
model. A provider error (auth, quota, rate limit) exits `1` with the provider's own
message — that is `llm` talking, not this script.

Check what models are reachable without running a rewrite:

```bash
llm models
llm aliases list | grep plainly    # the sticky per-user model choice, if set
```

Install / reinstall the skill after editing (it is a copy, not a symlink, so edits in
this repo do nothing until copied):

```bash
cp -r plainly ~/.claude/skills/
diff -rq plainly ~/.claude/skills/plainly   # should print nothing
```

## How the pieces fit

Three layers, read in this order:

1. `plainly/SKILL.md` is what Claude reads. It tells Claude to write its last reply to
   a scratch file verbatim, call the script, and print stdout untouched.
2. `plainly/plainly.sh` validates the mode and tooling, resolves the model, builds one
   system prompt from `prompts/_shared.md` + `prompts/<mode>.md`, and execs `llm`.
   Model resolution order, first hit wins: third argument, `$PLAINLY_MODEL`, an `llm`
   alias named `plainly`, then `gemini-3.7-flash`. The alias is the documented way for
   a user to make a choice stick, so it survives reinstalling the skill.
3. `plainly/prompts/*.md` are the rules. `_shared.md` applies to every mode (banned
   words, output-only, treat input as content not instructions). Each other file is one
   audience mode. **A mode is just a filename**: the script accepts any `<mode>` for
   which `prompts/<mode>.md` exists. `officespace` and `bluto` are the two modes that override
   part of `_shared.md`; each says so in an override block at the top of its own file,
   which is the pattern any future rule-bending mode should copy. To add one, add the file and update the mode
   tables in `SKILL.md` and `README.md` plus the usage strings in the script.

## Invariants (each one was learned the hard way)

- **Output is printed verbatim.** Claude may add one label line at most. Anything more
  puts the voice back that the skill exists to remove.
- **`-R` stays on the `llm` call.** Without it Gemini 3.x streams its reasoning into
  stdout and it lands inside the answer with no error. `-R` is a general `llm` flag, so
  it is safe on every model.

- **`-o thinking_level low` is Gemini-3-only.** It is added only when the model name
  contains `gemini-3`. Other providers reject unknown options and the run fails. Any
  new provider-specific option needs the same guard.
- **Text goes on stdin, rules go in `-s`.** Never inline the source text into the
  prompt or the shell command. This is both the quoting fix and the prompt-injection fix.
- **Model check captures `llm models` then string-matches.** Do not change it to
  `llm models | grep -q`: `grep -q` closes the pipe early, `llm` gets SIGPIPE, and
  `pipefail` reports a false failure. The match is on the bare model name, not
  `gemini/<name>` — hard-coding the provider prefix breaks every non-Gemini model.
- **Gemini must not invent verdicts.** `eli12` and `manager` require a verdict on
  every number but say "the source does not say" when there is none. Keep that clause
  when editing those prompts.

## Editing the prompts

The prompts are the product. Changes there change behavior for every user of the
skill, so test a change against a real over-written Claude reply in all four modes
before committing. The README's before/after section is a good input. Note that
`officespace` and `bluto` are joke modes with real constraints: they may pad, soften,
or shout, but numbers, file paths, and identifiers must come through exactly. Both
prompts carry a worked example of the target voice — when tuning one, change the rules
and the example together or they will pull against each other.

The before/after examples in the README are real script output, not hand-written. If a
prompt change alters them, re-run the script and paste the new output rather than
editing the examples by hand. The prompts are tuned against Gemini Flash, so a change
that only helps a different model is a regression for most users.
