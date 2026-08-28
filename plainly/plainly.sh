#!/usr/bin/env bash
# plainly.sh — rewrite text in plain English using a second model via the `llm` CLI.
#
# Usage:  plainly.sh <mode> <input-file> [model]
#   mode:  eli12 | colleague | manager | officespace | bluto
#   model: any model `llm models` lists. Picked in this order:
#            1. the third argument
#            2. $PLAINLY_MODEL
#            3. an llm alias named "plainly"  (llm aliases set plainly <model>)
#            4. gemini-3.7-flash
#
# The source text is piped in on stdin so shell quoting can never mangle it, and the
# style rules go in as a system prompt (-s) so the text being rewritten is never
# read as instructions.
set -euo pipefail

MODE="${1:-eli12}"
INPUT="${2:-}"
MODEL="${3:-${PLAINLY_MODEL:-}}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_MODEL="gemini-3.7-flash"

if [[ -z "$INPUT" ]]; then
  echo "usage: plainly.sh <eli12|colleague|manager|officespace|bluto> <input-file> [model]" >&2
  exit 2
fi
if [[ ! -f "$INPUT" ]]; then
  echo "plainly: input file not found: $INPUT" >&2
  exit 2
fi
if [[ ! -f "$DIR/prompts/$MODE.md" ]]; then
  echo "plainly: unknown mode '$MODE' (expected eli12, colleague, manager, officespace, or bluto)" >&2
  exit 2
fi
if ! command -v llm >/dev/null 2>&1; then
  echo "plainly: the 'llm' CLI is not installed. Install with: brew install llm" >&2
  exit 3
fi

# NB: capture first, then match. Not `llm ... | grep -q`: grep -q closes the pipe
# early, llm takes SIGPIPE, and `pipefail` reports that as a failed check.
if [[ -z "$MODEL" ]]; then
  # `llm aliases list` prints "name : target", padded. Pick the "plainly" alias if set.
  ALIASES="$(llm aliases list 2>/dev/null || true)"
  MODEL="$(printf '%s\n' "$ALIASES" | awk '$1 == "plainly" && $2 == ":" { print $3; exit }')"
fi
MODEL="${MODEL:-$DEFAULT_MODEL}"

# `llm models` prints "Provider: model-id (aliases: a, b)". Accept the id or an alias.
AVAILABLE="$(llm models 2>/dev/null || true)"
if [[ "$AVAILABLE" != *"$MODEL"* ]]; then
  echo "plainly: model '$MODEL' is not available to llm." >&2
  echo "  See what is installed:   llm models" >&2
  echo "  For the default (Gemini): llm install llm-gemini && llm keys set gemini" >&2
  echo "  For another provider:     llm install llm-<provider> && llm keys set <provider>" >&2
  exit 3
fi

SYSTEM="$(cat "$DIR/prompts/_shared.md")

$(cat "$DIR/prompts/$MODE.md")"

# Gemini 3.x accepts a thinking_level option. Other models reject unknown options, so
# only pass it when the model is a Gemini 3 model.
OPTS=()
if [[ "$MODEL" == *gemini-3* ]]; then
  OPTS=(-o thinking_level low)
fi

# -R hides the model's reasoning trace. WITHOUT IT, Gemini 3.x streams its internal
# monologue into stdout and it lands in the answer. Do not remove -R.
exec llm -m "$MODEL" -R "${OPTS[@]}" -s "$SYSTEM" < "$INPUT"
