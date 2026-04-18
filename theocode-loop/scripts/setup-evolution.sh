#!/bin/bash
# =============================================================================
# setup-evolution.sh — Bootstrap for theocode-loop evolution session
#
# Creates the state file, output directory, and runs baseline evaluation.
#
# Usage: setup-evolution.sh PROMPT [--max-iterations N] [--theo-code-dir PATH]
# =============================================================================

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
PROMPT=""
MAX_ITERATIONS=15
THEO_CODE_DIR=""
COMPLETION_PROMISE="EVOLUTION COMPLETE"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations)
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --theo-code-dir)
      THEO_CODE_DIR="$2"
      shift 2
      ;;
    --completion-promise)
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      if [[ -z "$PROMPT" ]]; then
        PROMPT="$1"
      else
        PROMPT="$PROMPT $1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$PROMPT" ]]; then
  echo "Usage: setup-evolution.sh \"PROMPT\" [--max-iterations N] [--theo-code-dir PATH]"
  echo ""
  echo "Examples:"
  echo "  setup-evolution.sh \"Evolua o context manager\""
  echo "  setup-evolution.sh \"Implemente HyDE no retrieval\" --max-iterations 20"
  echo "  setup-evolution.sh \"Refatore o agent loop\" --theo-code-dir /path/to/theo-code"
  exit 1
fi

# ---------------------------------------------------------------------------
# Auto-detect theo-code directory
# ---------------------------------------------------------------------------
if [[ -z "$THEO_CODE_DIR" ]]; then
  if [[ -f "Cargo.toml" ]] && grep -q "\[workspace\]" Cargo.toml 2>/dev/null; then
    THEO_CODE_DIR="$(pwd)"
  else
    echo "ERROR: Not in theo-code workspace and --theo-code-dir not provided."
    echo "  Either cd into theo-code or pass --theo-code-dir /path/to/theo-code"
    exit 1
  fi
fi

THEO_CODE_DIR="$(cd "$THEO_CODE_DIR" && pwd)"

echo "=== theocode-loop: Setting up evolution session ==="
echo "  Prompt: $PROMPT"
echo "  theo-code: $THEO_CODE_DIR"
echo "  Max iterations: $MAX_ITERATIONS"
echo ""

# ---------------------------------------------------------------------------
# Verify toolchain
# ---------------------------------------------------------------------------
echo "[setup] Checking toolchain..."
command -v rustc >/dev/null 2>&1 || { echo "ERROR: rustc not found. Install via rustup."; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "ERROR: cargo not found."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found."; exit 1; }
echo "  Toolchain OK."

# ---------------------------------------------------------------------------
# Verify workspace
# ---------------------------------------------------------------------------
echo "[setup] Checking workspace..."
[[ -f "$THEO_CODE_DIR/Cargo.toml" ]] || { echo "ERROR: $THEO_CODE_DIR is not a cargo workspace."; exit 1; }
grep -q "\[workspace\]" "$THEO_CODE_DIR/Cargo.toml" || { echo "ERROR: Cargo.toml has no [workspace] section."; exit 1; }
echo "  Workspace OK."

# ---------------------------------------------------------------------------
# Verify reference repos
# ---------------------------------------------------------------------------
REFS_DIR="$THEO_CODE_DIR/referencias"
echo "[setup] Checking reference repos..."
if [[ -d "$REFS_DIR" ]]; then
  REF_COUNT=$(find "$REFS_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
  echo "  Found $REF_COUNT reference repos in $REFS_DIR"
  if [[ "$REF_COUNT" -lt 3 ]]; then
    echo "  WARNING: Only $REF_COUNT repos. Recommend at least 3 for effective SOTA comparison."
  fi
else
  echo "  WARNING: referencias/ not found at $REFS_DIR"
  echo "  The researcher agent needs reference repos to extract SOTA patterns."
fi

# ---------------------------------------------------------------------------
# Create output directory
# ---------------------------------------------------------------------------
OUTPUT_DIR="$THEO_CODE_DIR/evolution-output"
mkdir -p "$OUTPUT_DIR/state"
echo "[setup] Output directory: $OUTPUT_DIR"

# ---------------------------------------------------------------------------
# Ensure .theo directory
# ---------------------------------------------------------------------------
mkdir -p "$THEO_CODE_DIR/.theo"

# ---------------------------------------------------------------------------
# Create evolution branch if not on one
# ---------------------------------------------------------------------------
cd "$THEO_CODE_DIR"
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ ! "$CURRENT_BRANCH" =~ ^evolution/ ]]; then
  TAG=$(date +%b%d | tr '[:upper:]' '[:lower:]')
  BRANCH_NAME="evolution/$TAG"
  if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    BRANCH_NAME="evolution/${TAG}-$(date +%H%M)"
  fi
  echo "[setup] Creating branch: $BRANCH_NAME"
  git switch -c "$BRANCH_NAME"
else
  echo "[setup] Already on evolution branch: $CURRENT_BRANCH"
fi

# ---------------------------------------------------------------------------
# Run baseline evaluation
# ---------------------------------------------------------------------------
echo "[setup] Running baseline evaluation..."
EVAL_SCRIPT="$PLUGIN_ROOT/scripts/theo-evaluate.sh"
if [[ ! -f "$EVAL_SCRIPT" ]]; then
  echo "  WARNING: theo-evaluate.sh not found at $EVAL_SCRIPT"
  echo "  Hygiene checks will be skipped."
  BASELINE_SCORE="N/A"
  BASELINE_L1="N/A"
  BASELINE_L2="N/A"
else
  BASELINE_LOG=$(mktemp)
  bash "$EVAL_SCRIPT" "$THEO_CODE_DIR" > "$BASELINE_LOG" 2>&1 || true
  BASELINE_SCORE=$(grep "^score:" "$BASELINE_LOG" | awk '{print $2}' || echo "N/A")
  BASELINE_L1=$(grep "^l1_score:" "$BASELINE_LOG" | awk '{print $2}' || echo "N/A")
  BASELINE_L2=$(grep "^l2_score:" "$BASELINE_LOG" | awk '{print $2}' || echo "N/A")
  rm -f "$BASELINE_LOG"
  echo "  Baseline: score=$BASELINE_SCORE (L1=$BASELINE_L1, L2=$BASELINE_L2)"
fi

# ---------------------------------------------------------------------------
# Add evolution-output to .gitignore
# ---------------------------------------------------------------------------
if ! grep -q "^evolution-output" "$THEO_CODE_DIR/.gitignore" 2>/dev/null; then
  echo "" >> "$THEO_CODE_DIR/.gitignore"
  echo "# Evolution loop output" >> "$THEO_CODE_DIR/.gitignore"
  echo "evolution-output/" >> "$THEO_CODE_DIR/.gitignore"
  echo ".theo/evolution_log.jsonl" >> "$THEO_CODE_DIR/.gitignore"
fi

# ---------------------------------------------------------------------------
# Read and prepare evolution prompt template
# ---------------------------------------------------------------------------
TEMPLATE_FILE="$PLUGIN_ROOT/templates/evolution-prompt.md"
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "ERROR: Evolution prompt template not found at $TEMPLATE_FILE"
  exit 1
fi

PROMPT_TEXT=$(cat "$TEMPLATE_FILE")
PROMPT_TEXT="${PROMPT_TEXT//\{\{PROMPT\}\}/$PROMPT}"
PROMPT_TEXT="${PROMPT_TEXT//\{\{THEO_CODE_DIR\}\}/$THEO_CODE_DIR}"
PROMPT_TEXT="${PROMPT_TEXT//\{\{PLUGIN_ROOT\}\}/$PLUGIN_ROOT}"
PROMPT_TEXT="${PROMPT_TEXT//\{\{OUTPUT_DIR\}\}/$OUTPUT_DIR}"
PROMPT_TEXT="${PROMPT_TEXT//\{\{BASELINE_SCORE\}\}/$BASELINE_SCORE}"
PROMPT_TEXT="${PROMPT_TEXT//\{\{BASELINE_L1\}\}/$BASELINE_L1}"
PROMPT_TEXT="${PROMPT_TEXT//\{\{BASELINE_L2\}\}/$BASELINE_L2}"
PROMPT_TEXT="${PROMPT_TEXT//\{\{COMPLETION_PROMISE\}\}/$COMPLETION_PROMISE}"

# ---------------------------------------------------------------------------
# Create state file
# ---------------------------------------------------------------------------
STATE_FILE=".claude/theocode-loop.local.md"
mkdir -p .claude

cat > "$STATE_FILE" <<STATEEOF
---
active: true
prompt: "$PROMPT"
current_phase: 1
phase_name: "research"
phase_iteration: 1
global_iteration: 1
max_global_iterations: $MAX_ITERATIONS
completion_promise: "$COMPLETION_PROMISE"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
theo_code_dir: "$THEO_CODE_DIR"
output_dir: "$OUTPUT_DIR"
plugin_root: "$PLUGIN_ROOT"
baseline_score: "$BASELINE_SCORE"
baseline_l1: "$BASELINE_L1"
baseline_l2: "$BASELINE_L2"
current_score: "$BASELINE_SCORE"
sota_average: "0.0"
iteration_cycle: 0
---

$PROMPT_TEXT
STATEEOF

echo ""
echo "=== Setup complete ==="
echo "  State file: $STATE_FILE"
echo "  Output dir: $OUTPUT_DIR"
echo "  Baseline: score=$BASELINE_SCORE"
echo ""
echo "The evolution loop will now begin. Read the state file for instructions."
