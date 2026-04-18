#!/bin/bash

# Theocode Evolution Loop — Phase-Aware Stop Hook
# Implements the Ralph Wiggum loop + Autoresearch keep/discard pattern.
# Phases: RESEARCH → IMPLEMENT → HYGIENE_CHECK → EVALUATE → CONVERGED

set -euo pipefail

HOOK_INPUT=$(cat)

STATE_FILE=".claude/theocode-loop.local.md"

if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Parse state file frontmatter
# ---------------------------------------------------------------------------
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")

parse_field() {
  local field="$1"
  echo "$FRONTMATTER" | grep "^${field}:" | sed "s/${field}: *//" | sed 's/^"\(.*\)"$/\1/'
}

CURRENT_PHASE=$(parse_field "current_phase")
PHASE_NAME=$(parse_field "phase_name")
PHASE_ITERATION=$(parse_field "phase_iteration")
GLOBAL_ITERATION=$(parse_field "global_iteration")
MAX_GLOBAL_ITERATIONS=$(parse_field "max_global_iterations")
COMPLETION_PROMISE=$(parse_field "completion_promise")
PROMPT=$(parse_field "prompt")
OUTPUT_DIR=$(parse_field "output_dir")
CURRENT_SCORE=$(parse_field "current_score")
SOTA_AVERAGE=$(parse_field "sota_average")
ITERATION_CYCLE=$(parse_field "iteration_cycle")

# Phase configuration
declare -A PHASE_MAX_ITER
PHASE_MAX_ITER[1]=2   # RESEARCH
PHASE_MAX_ITER[2]=5   # IMPLEMENT
PHASE_MAX_ITER[3]=1   # HYGIENE_CHECK
PHASE_MAX_ITER[4]=1   # EVALUATE
PHASE_MAX_ITER[5]=1   # CONVERGED

declare -A PHASE_NAMES
PHASE_NAMES[1]="research"
PHASE_NAMES[2]="implement"
PHASE_NAMES[3]="hygiene_check"
PHASE_NAMES[4]="evaluate"
PHASE_NAMES[5]="converged"

# ---------------------------------------------------------------------------
# Validate numeric fields
# ---------------------------------------------------------------------------
validate_numeric() {
  local field_name="$1"
  local field_value="$2"
  if [[ ! "$field_value" =~ ^[0-9]+$ ]]; then
    echo "State file corrupted: '$field_name' is not numeric (got: '$field_value')" >&2
    rm "$STATE_FILE"
    exit 0
  fi
}

validate_numeric "current_phase" "$CURRENT_PHASE"
validate_numeric "phase_iteration" "$PHASE_ITERATION"
validate_numeric "global_iteration" "$GLOBAL_ITERATION"
validate_numeric "max_global_iterations" "$MAX_GLOBAL_ITERATIONS"
validate_numeric "iteration_cycle" "$ITERATION_CYCLE"

# ---------------------------------------------------------------------------
# Check global iteration limit
# ---------------------------------------------------------------------------
if [[ $MAX_GLOBAL_ITERATIONS -gt 0 ]] && [[ $GLOBAL_ITERATION -ge $MAX_GLOBAL_ITERATIONS ]]; then
  echo "Evolution loop: Max iterations ($MAX_GLOBAL_ITERATIONS) reached."
  echo "  Prompt: $PROMPT"
  echo "  Final phase: $CURRENT_PHASE/5 ($PHASE_NAME)"
  echo "  Hygiene score: $CURRENT_SCORE"
  echo "  SOTA average: $SOTA_AVERAGE"
  rm "$STATE_FILE"
  exit 0
fi

# ---------------------------------------------------------------------------
# Read transcript and extract last assistant output
# ---------------------------------------------------------------------------
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Transcript not found at $TRANSCRIPT_PATH" >&2
  rm "$STATE_FILE"
  exit 0
fi

if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "No assistant messages in transcript" >&2
  rm "$STATE_FILE"
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
if [[ -z "$LAST_LINE" ]]; then
  rm "$STATE_FILE"
  exit 0
fi

LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>&1)

if [[ $? -ne 0 ]] || [[ -z "$LAST_OUTPUT" ]]; then
  rm "$STATE_FILE"
  exit 0
fi

# ---------------------------------------------------------------------------
# Check for completion promise
# ---------------------------------------------------------------------------
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "Evolution loop CONVERGED: <promise>$COMPLETION_PROMISE</promise>"
    echo "  Prompt: $PROMPT"
    echo "  Total iterations: $GLOBAL_ITERATION"
    echo "  Hygiene score: $CURRENT_SCORE"
    echo "  SOTA average: $SOTA_AVERAGE"
    echo "  Cycle count: $ITERATION_CYCLE"
    rm "$STATE_FILE"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Detect markers from agent output
# ---------------------------------------------------------------------------
PHASE_ADVANCED=false
FORCED_ADVANCE=false
QUALITY_FAILED=false
HYGIENE_FAILED=false

# Phase completion marker: <!-- PHASE_N_COMPLETE -->
if echo "$LAST_OUTPUT" | grep -qE "<!--\s*PHASE_${CURRENT_PHASE}_COMPLETE\s*-->"; then
  PHASE_ADVANCED=true
fi

# Hygiene markers: <!-- HYGIENE_PASSED:0|1 --> <!-- HYGIENE_SCORE:XX.XXX -->
NEW_HYGIENE_SCORE=$(echo "$LAST_OUTPUT" | grep -oP '<!--\s*HYGIENE_SCORE:([\d.]+)\s*-->' | grep -oP '[\d.]+' | tail -1 || echo "")
HYGIENE_PASSED=$(echo "$LAST_OUTPUT" | grep -oP '<!--\s*HYGIENE_PASSED:(\d)\s*-->' | grep -oP '\d' | tail -1 || echo "")

if [[ -n "$NEW_HYGIENE_SCORE" ]]; then
  CURRENT_SCORE="$NEW_HYGIENE_SCORE"
fi

if [[ -n "$HYGIENE_PASSED" ]] && [[ "$HYGIENE_PASSED" == "0" ]]; then
  HYGIENE_FAILED=true
  PHASE_ADVANCED=false
fi

# Quality markers: <!-- QUALITY_SCORE:X.X --> <!-- QUALITY_PASSED:0|1 -->
NEW_SOTA=$(echo "$LAST_OUTPUT" | grep -oP '<!--\s*QUALITY_SCORE:([\d.]+)\s*-->' | grep -oP '[\d.]+' | tail -1 || echo "")
QUALITY_PASSED=$(echo "$LAST_OUTPUT" | grep -oP '<!--\s*QUALITY_PASSED:(\d)\s*-->' | grep -oP '\d' | tail -1 || echo "")

if [[ -n "$NEW_SOTA" ]]; then
  SOTA_AVERAGE="$NEW_SOTA"
fi

if [[ -n "$QUALITY_PASSED" ]] && [[ "$QUALITY_PASSED" == "0" ]]; then
  QUALITY_FAILED=true
  PHASE_ADVANCED=false
fi

# ---------------------------------------------------------------------------
# Phase timeout (forced advancement)
# ---------------------------------------------------------------------------
CURRENT_PHASE_MAX=${PHASE_MAX_ITER[$CURRENT_PHASE]:-3}
if [[ "$PHASE_ADVANCED" != "true" ]] && [[ "$QUALITY_FAILED" != "true" ]] && [[ "$HYGIENE_FAILED" != "true" ]] && [[ $PHASE_ITERATION -ge $CURRENT_PHASE_MAX ]]; then
  PHASE_ADVANCED=true
  FORCED_ADVANCE=true
fi

# ---------------------------------------------------------------------------
# Handle phase transitions
# ---------------------------------------------------------------------------
if [[ "$HYGIENE_FAILED" == "true" ]]; then
  # Hygiene failed → revert to IMPLEMENT (phase 2)
  CURRENT_PHASE=2
  PHASE_NAME="implement"
  PHASE_ITERATION=0
fi

if [[ "$QUALITY_FAILED" == "true" ]]; then
  # Quality gate failed → back to IMPLEMENT (phase 2) for another cycle
  CURRENT_PHASE=2
  PHASE_NAME="implement"
  PHASE_ITERATION=0
  ITERATION_CYCLE=$((ITERATION_CYCLE + 1))
fi

if [[ "$PHASE_ADVANCED" == "true" ]]; then
  if [[ $CURRENT_PHASE -ge 5 ]]; then
    echo "All phases complete but no completion promise detected."
    echo "  Prompt: $PROMPT"
    rm "$STATE_FILE"
    exit 0
  fi

  CURRENT_PHASE=$((CURRENT_PHASE + 1))
  PHASE_NAME="${PHASE_NAMES[$CURRENT_PHASE]}"
  PHASE_ITERATION=0
fi

# ---------------------------------------------------------------------------
# Increment counters
# ---------------------------------------------------------------------------
NEXT_GLOBAL=$((GLOBAL_ITERATION + 1))
NEXT_PHASE_ITER=$((PHASE_ITERATION + 1))

# ---------------------------------------------------------------------------
# Extract prompt text (everything after second ---)
# ---------------------------------------------------------------------------
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "No prompt text found in state file" >&2
  rm "$STATE_FILE"
  exit 0
fi

# ---------------------------------------------------------------------------
# Update state file atomically
# ---------------------------------------------------------------------------
TEMP_FILE="${STATE_FILE}.tmp.$$"
cat > "$TEMP_FILE" <<EOF
---
active: true
prompt: "$PROMPT"
current_phase: $CURRENT_PHASE
phase_name: "$PHASE_NAME"
phase_iteration: $NEXT_PHASE_ITER
global_iteration: $NEXT_GLOBAL
max_global_iterations: $MAX_GLOBAL_ITERATIONS
completion_promise: "$(echo "$COMPLETION_PROMISE" | sed 's/"/\\"/g')"
started_at: "$(parse_field "started_at")"
theo_code_dir: "$(parse_field "theo_code_dir")"
output_dir: "$OUTPUT_DIR"
plugin_root: "$(parse_field "plugin_root")"
baseline_score: "$(parse_field "baseline_score")"
baseline_l1: "$(parse_field "baseline_l1")"
baseline_l2: "$(parse_field "baseline_l2")"
current_score: "$CURRENT_SCORE"
sota_average: "$SOTA_AVERAGE"
iteration_cycle: $ITERATION_CYCLE
---

$PROMPT_TEXT
EOF
mv "$TEMP_FILE" "$STATE_FILE"

# ---------------------------------------------------------------------------
# Build system message
# ---------------------------------------------------------------------------
PHASE_MAX_FOR_CURRENT=${PHASE_MAX_ITER[$CURRENT_PHASE]:-3}

SYSTEM_MSG="Evolution Loop | Phase $CURRENT_PHASE/5: $PHASE_NAME | Phase iter $NEXT_PHASE_ITER/$PHASE_MAX_FOR_CURRENT | Global iter $NEXT_GLOBAL/$MAX_GLOBAL_ITERATIONS"
SYSTEM_MSG="$SYSTEM_MSG | Cycle $ITERATION_CYCLE | Hygiene: $CURRENT_SCORE | SOTA: $SOTA_AVERAGE/3.0"

if [[ "$FORCED_ADVANCE" == "true" ]]; then
  SYSTEM_MSG="$SYSTEM_MSG | Previous phase timed out — forced to $PHASE_NAME"
fi

if [[ "$QUALITY_FAILED" == "true" ]]; then
  SYSTEM_MSG="$SYSTEM_MSG | QUALITY GATE FAILED (SOTA $SOTA_AVERAGE < 2.5) — back to implement. Cycle $ITERATION_CYCLE."
fi

if [[ "$HYGIENE_FAILED" == "true" ]]; then
  SYSTEM_MSG="$SYSTEM_MSG | HYGIENE FAILED — revert and retry implementation."
fi

if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="$SYSTEM_MSG | To finish: <promise>$COMPLETION_PROMISE</promise> (ONLY when CONVERGED)"
fi

# ---------------------------------------------------------------------------
# Block exit and re-inject prompt
# ---------------------------------------------------------------------------
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
