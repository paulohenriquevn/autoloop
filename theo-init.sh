#!/bin/bash
# =============================================================================
# theo-init.sh — One-time setup for theo-code autoresearch (dual-layer)
#
# Verifies toolchain, warms up build cache, runs baseline evaluation,
# and creates results.tsv header.
#
# Usage: bash theo-init.sh [/path/to/theo-code]
# =============================================================================

set -euo pipefail

THEO_DIR="${1:-/home/paulo/Projetos/usetheo/theo-code}"
THEO_DIR="$(cd "$THEO_DIR" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== theo-code evolution loop init ==="
echo ""

# 1. Verify Rust toolchain
echo "[init] Checking toolchain..."
rustc --version || { echo "ERROR: rustc not found. Install via rustup."; exit 1; }
cargo --version || { echo "ERROR: cargo not found."; exit 1; }
python3 --version || { echo "ERROR: python3 not found. Install Python 3.6+."; exit 1; }
echo ""

# 2. Verify theo-code workspace
echo "[init] Checking workspace at $THEO_DIR..."
[ -f "$THEO_DIR/Cargo.toml" ] || { echo "ERROR: $THEO_DIR is not a cargo workspace."; exit 1; }
grep -q "\[workspace\]" "$THEO_DIR/Cargo.toml" || { echo "ERROR: Cargo.toml has no [workspace] section."; exit 1; }
echo "  Workspace OK."
echo ""

# 3. Warm up incremental build cache
echo "[init] Warming up build cache..."
cd "$THEO_DIR"
cargo check 2>&1 | tail -3
echo ""

# 4. Ensure .theo directory exists
mkdir -p "$THEO_DIR/.theo"

# 5. Verify reference repos exist
REFS_DIR="$THEO_DIR/referencias"
if [ -d "$REFS_DIR" ]; then
    REF_COUNT=$(ls -d "$REFS_DIR"/*/ 2>/dev/null | wc -l)
    echo "[init] Reference repos found: $REF_COUNT in $REFS_DIR"
    if [ "$REF_COUNT" -lt 3 ]; then
        echo "WARNING: Only $REF_COUNT reference repos found. Recommend at least 3 for effective SOTA comparison."
    fi
    ls -d "$REFS_DIR"/*/ 2>/dev/null | while read -r d; do
        echo "  - $(basename "$d")"
    done
else
    echo ""
    echo "WARNING: referencias/ directory not found at $REFS_DIR"
    echo "  The agent needs reference repos to research SOTA patterns."
    echo "  Clone reference repos into $REFS_DIR before starting an evolution session."
    echo ""
fi

# 5b. Create evolution_prompt.md template if it doesn't exist
if [ ! -f "$THEO_DIR/.theo/evolution_prompt.md" ]; then
    cat > "$THEO_DIR/.theo/evolution_prompt.md" << 'EVOLUTION_EOF'
# Evolution Prompt

<!-- Replace this content with the evolution mission. Examples: -->
<!-- "Evolua o context manager para usar compaction em estágios como o OpenDev" -->
<!-- "Implemente hybrid search com BM25 + re-ranking no retrieval engine" -->
<!-- "Refatore o agent loop para suportar thinking/critique phases separadas" -->

(awaiting evolution prompt from operator)
EVOLUTION_EOF
    echo "  Created .theo/evolution_prompt.md template."
fi

# 6. Add untracked files to .gitignore if needed
if ! grep -q "^results.tsv$" "$THEO_DIR/.gitignore" 2>/dev/null; then
    echo "" >> "$THEO_DIR/.gitignore"
    echo "# Evolution loop logs (not committed)" >> "$THEO_DIR/.gitignore"
    echo "results.tsv" >> "$THEO_DIR/.gitignore"
    echo "eval.log" >> "$THEO_DIR/.gitignore"
    echo "eval_detail.json" >> "$THEO_DIR/.gitignore"
    echo "experiment_traces.jsonl" >> "$THEO_DIR/.gitignore"
    echo "progress.md" >> "$THEO_DIR/.gitignore"
    echo ".theo/evolution_log.jsonl" >> "$THEO_DIR/.gitignore"
    echo "  Added evolution loop logs to .gitignore"
fi

# 7. Create results.tsv with complete dual-layer header
if [ ! -f "$THEO_DIR/results.tsv" ]; then
    printf "commit\tscore\tl1_score\tl2_score\tcompile_crates\ttests_passed\ttests_failed\ttest_count\tcargo_warnings\tclippy_warnings\tunwrap_count\tstructural_tests\tboundary_tests\tdoc_artifacts\tdead_code_attrs\tstatus\tdescription\n" > "$THEO_DIR/results.tsv"
    echo "  Created results.tsv with dual-layer header."
fi

# 8. Initialize progress.md if it doesn't exist
if [ ! -f "$THEO_DIR/progress.md" ]; then
    cat > "$THEO_DIR/progress.md" << 'PROGRESS_EOF'
## Last Update: (not yet started)

**Phase**: (pending baseline)
**Score**: (pending baseline)
**Experiments**: 0 total, 0 kept, 0 discarded

### Recent
(no experiments yet)

### Next Steps
- Run baseline evaluation
- Determine initial phase
- Begin experiment loop
PROGRESS_EOF
    echo "  Created progress.md template."
fi

# 9. Generate SHA-256 checksum for eval harness integrity verification
sha256sum "$SCRIPT_DIR/theo-evaluate.sh" > "$SCRIPT_DIR/theo-evaluate.sha256"
echo "  Generated theo-evaluate.sha256 for integrity verification."

# 10. Run baseline evaluation
echo ""
# 9b. Initialize evolution_log.jsonl if it doesn't exist
if [ ! -f "$THEO_DIR/.theo/evolution_log.jsonl" ]; then
    touch "$THEO_DIR/.theo/evolution_log.jsonl"
    echo "  Created .theo/evolution_log.jsonl"
fi

# 10. Run baseline evaluation
echo ""
echo "[init] Running baseline evaluation (hygiene floor)..."
BASELINE_LOG=$(mktemp)
bash "$SCRIPT_DIR/theo-evaluate.sh" "$THEO_DIR" 2>&1 | tee "$BASELINE_LOG"

echo ""
baseline_score=$(grep "^score:" "$BASELINE_LOG" | awk '{print $2}')
l1=$(grep "^l1_score:" "$BASELINE_LOG" | awk '{print $2}')
l2=$(grep "^l2_score:" "$BASELINE_LOG" | awk '{print $2}')
rm -f "$BASELINE_LOG"

echo "[init] Baseline (hygiene floor): score=${baseline_score:-FAILED} (L1=${l1:-?}, L2=${l2:-?})"
echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. cd $THEO_DIR"
echo "  2. git switch -c evolution/<tag>"
echo "  3. Edit .theo/evolution_prompt.md with your evolution mission"
echo "  4. Open Claude Code and prompt:"
echo "     'Read $SCRIPT_DIR/theo-program.md and start the evolution loop'"
