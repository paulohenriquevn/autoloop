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

echo "=== theo-code autoresearch init (dual-layer) ==="
echo ""

# 1. Verify Rust toolchain
echo "[init] Checking toolchain..."
rustc --version || { echo "ERROR: rustc not found. Install via rustup."; exit 1; }
cargo --version || { echo "ERROR: cargo not found."; exit 1; }
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

# 5. Add untracked files to .gitignore if needed
if ! grep -q "^results.tsv$" "$THEO_DIR/.gitignore" 2>/dev/null; then
    echo "" >> "$THEO_DIR/.gitignore"
    echo "# Autoresearch experiment logs" >> "$THEO_DIR/.gitignore"
    echo "results.tsv" >> "$THEO_DIR/.gitignore"
    echo "eval.log" >> "$THEO_DIR/.gitignore"
    echo "eval_detail.json" >> "$THEO_DIR/.gitignore"
    echo "  Added autoresearch logs to .gitignore"
fi

# 6. Create results.tsv with dual-layer header
if [ ! -f "$THEO_DIR/results.tsv" ]; then
    printf "commit\tscore\tl1_score\tl2_score\tcompile_crates\ttests_passed\tclipy_warnings\tunwrap_count\tstatus\tdescription\n" > "$THEO_DIR/results.tsv"
    echo "  Created results.tsv with dual-layer header."
fi

# 7. Run baseline evaluation
echo ""
echo "[init] Running baseline evaluation (dual-layer)..."
bash "$SCRIPT_DIR/theo-evaluate.sh" "$THEO_DIR" 2>&1 | tee /tmp/theo-baseline.log

echo ""
baseline_score=$(grep "^score:" /tmp/theo-baseline.log | awk '{print $2}')
l1=$(grep "^l1_score:" /tmp/theo-baseline.log | awk '{print $2}')
l2=$(grep "^l2_score:" /tmp/theo-baseline.log | awk '{print $2}')

echo "[init] Baseline: score=${baseline_score:-FAILED} (L1=${l1:-?}, L2=${l2:-?})"
echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. cd $THEO_DIR"
echo "  2. git checkout -b autoresearch/<tag>"
echo "  3. Open Claude Code and prompt:"
echo "     'Read $SCRIPT_DIR/theo-program.md and kick off a new experiment'"
