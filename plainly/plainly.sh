#!/usr/bin/env bash
# plainly.sh — rewrite text in plain English using a second model via the `llm` CLI.
#
# Usage:  plainly.sh <mode> <input-file> [model]
#   mode:  eli12 | colleague | manager | officespace | bluto
#   model: any model `llm models` lists. Picked in this order:
#            1. the third argument
#            2. $PLAINLY_MODEL
#            3. an llm alias named "plainly"  (llm aliases set plainly <model>)
#            4. a per-mode default: the joke modes use a smaller, faster model,
#               everything else uses $DEFAULT_MODEL below.
#
# The source text is piped in on stdin so shell quoting can never mangle it, and the
# style rules go in as a system prompt (-s) so the text being rewritten is never
# read as instructions.
set -euo pipefail

MODE="${1:-eli12}"
INPUT="${2:-}"
MODEL="${3:-${PLAINLY_MODEL:-}}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# gemini-3.5-flash over 3.7: measured 4-5s vs 3-32s for identical work, with the same
# quality on the rules that matter. The joke modes tolerate a smaller model because
# they need energy, not judgment — flash-lite drops eli12's "every number gets a
# verdict" rule, but reads fine as Lumbergh or Bluto.
DEFAULT_MODEL="gemini-3.5-flash"
JOKE_MODEL="gemini-3.5-flash-lite"

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

# Read the "plainly" alias straight out of llm's aliases.json rather than shelling out
# to `llm aliases list`. Starting llm costs ~0.45s; reading the file costs nothing, and
# that was a quarter of the total wait once the model itself got fast.
if [[ -z "$MODEL" ]]; then
  for CAND in "${LLM_USER_PATH:-}" \
              "$HOME/Library/Application Support/io.datasette.llm" \
              "${XDG_CONFIG_HOME:-$HOME/.config}/io.datasette.llm"; do
    [[ -n "$CAND" && -f "$CAND/aliases.json" ]] || continue
    MODEL="$(sed -n 's/.*"plainly"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
             "$CAND/aliases.json" | head -1)"
    break
  done
fi

if [[ -z "$MODEL" ]]; then
  case "$MODE" in
    officespace|bluto) MODEL="$JOKE_MODEL" ;;
    *)                 MODEL="$DEFAULT_MODEL" ;;
  esac
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
#
# There is deliberately no pre-flight `llm models` check: it cost ~0.45s on every
# single run to catch a rare mistake. Let llm fail, then explain the failure.
RC=0
llm -m "$MODEL" -R "${OPTS[@]}" -s "$SYSTEM" < "$INPUT" || RC=$?
if (( RC != 0 )); then
  echo >&2
  # Capture first, then match. NOT `llm models | grep -q`: grep -q closes the pipe
  # early, llm takes SIGPIPE, and pipefail turns that into a false "not installed".
  AVAILABLE="$(llm models 2>/dev/null || true)"
  if [[ "$AVAILABLE" != *"$MODEL"* ]]; then
    echo "plainly: model '$MODEL' is not available to llm." >&2
    echo "  See what is installed:   llm models" >&2
    echo "  For the default (Gemini): llm install llm-gemini && llm keys set gemini" >&2
    echo "  For another provider:     llm install llm-<provider> && llm keys set <provider>" >&2
    exit 3
  fi
  echo "plainly: '$MODEL' is installed, so the error above came from the provider" >&2
  echo "  (auth, quota, rate limit, or network). Retrying often works." >&2
  exit "$RC"
fi
