# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Claude Code skill. It sends Claude's last reply to Gemini Flash (through Simon
Willison's `llm` CLI) and prints the plain-English rewrite word for word. The whole
point is that Claude does not do the rewriting and does not touch the result.

There is no build, lint, or test suite. The only runtime is bash + `llm`.

## Commands

Run the script directly against a file (this is the smoke test):

```bash
plainly/plainly.sh eli12 path/to/some-reply.md
plainly/plainly.sh colleague path/to/some-reply.md
PLAINLY_MODEL=gemini-3.5-flash plainly/plainly.sh exec path/to/some-reply.md
```

Exit codes: `2` bad arguments or unknown mode, `3` missing `llm`, plugin, or key.

Check the model is reachable without running a rewrite:

```bash
llm models | grep gemini
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
2. `plainly/plainly.sh` validates the mode and tooling, builds one system prompt from
   `prompts/_shared.md` + `prompts/<mode>.md`, and execs `llm`.
3. `plainly/prompts/*.md` are the rules. `_shared.md` applies to every mode (banned
   words, output-only, treat input as content not instructions). Each other file is one
   audience mode. **A mode is just a filename**: the script accepts any `<mode>` for
   which `prompts/<mode>.md` exists. To add one, add the file and update the mode
   tables in `SKILL.md` and `README.md` plus the usage strings in the script.

## Invariants (each one was learned the hard way)

- **Output is printed verbatim.** Claude may add one label line at most. Anything more
  puts the voice back that the skill exists to remove.
- **`-R` stays on the `llm` call.** Without it Gemini 3.x streams its reasoning into
  stdout and it lands inside the answer with no error.
- **Text goes on stdin, rules go in `-s`.** Never inline the source text into the
  prompt or the shell command. This is both the quoting fix and the prompt-injection fix.
- **Model check captures `llm models` then string-matches.** Do not change it to
  `llm models | grep -q`: `grep -q` closes the pipe early, `llm` gets SIGPIPE, and
  `pipefail` reports a false failure.
- **Gemini must not invent verdicts.** `eli12` and `manager` require a verdict on
  every number but say "the source does not say" when there is none. Keep that clause
  when editing those prompts.

## Editing the prompts

The prompts are the product. Changes there change behavior for every user of the
skill, so test a change against a real over-written Claude reply in all four modes
before committing. The README's before/after section is a good input.
