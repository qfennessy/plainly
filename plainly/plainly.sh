#!/usr/bin/env bash
# plainly.sh — rewrite text in plain English using Gemini Flash via the `llm` CLI.
#
# Usage:  plainly.sh <mode> <input-file>
#   mode:  eli12 | colleague | manager | exec
#
# The source text is piped in on stdin so shell quoting can never mangle it, and the
# style rules go in as a system prompt (-s) so the text being rewritten is never
# read as instructions.
set -euo pipefail

MODE="${1:-eli12}"
INPUT="${2:-}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL="${PLAINLY_MODEL:-gemini-3.7-flash}"

if [[ -z "$INPUT" ]]; then
  echo "usage: plainly.sh <eli12|colleague|manager|exec> <input-file>" >&2
  exit 2
fi
if [[ ! -f "$INPUT" ]]; then
  echo "plainly: input file not found: $INPUT" >&2
  exit 2
fi
if [[ ! -f "$DIR/prompts/$MODE.md" ]]; then
  echo "plainly: unknown mode '$MODE' (expected eli12, colleague, manager, or exec)" >&2
  exit 2
fi
if ! command -v llm >/dev/null 2>&1; then
  echo "plainly: the 'llm' CLI is not installed. Install with: brew install llm" >&2
  exit 3
fi
# NB: not `llm models | grep -q` — grep -q closes the pipe early, llm takes SIGPIPE,
# and `pipefail` reports that as a failed check. Capture first, then match.
AVAILABLE="$(llm models 2>/dev/null || true)"
if [[ "$AVAILABLE" != *"gemini/$MODEL"* ]]; then
  echo "plainly: model '$MODEL' is unavailable." >&2
  echo "  Install the plugin:  llm install llm-gemini" >&2
  echo "  Set the API key:     llm keys set gemini" >&2
  exit 3
fi

SYSTEM="$(cat "$DIR/prompts/_shared.md")

$(cat "$DIR/prompts/$MODE.md")"

# -R hides the model's reasoning trace. WITHOUT IT, Gemini 3.x streams its internal
# monologue into stdout and it lands in the answer. Do not remove -R.
exec llm -m "$MODEL" -R -o thinking_level low -s "$SYSTEM" < "$INPUT"
