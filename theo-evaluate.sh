#!/bin/bash
# =============================================================================
# theo-evaluate.sh — Immutable evaluation harness for theo-code autoresearch
#
# This file is the ground truth metric. DO NOT MODIFY during experiment loops.
#
# Usage: bash theo-evaluate.sh /path/to/theo-code
# Output: Standardized metrics block (grep-friendly)
#
# Score = (L1 + L2) / 2  (0-100, higher is better)
#
# Layer 1 — Workspace Hygiene (100 raw pts):
#   40: compile success rate
#   40: test pass rate
#   10: test count bonus (capped at 2500)
#   10: cargo warning penalty
#
# Layer 2 — Harness Maturity (100 raw pts):
#   20: clippy cleanliness (1 - clippy_warnings/200)
#   20: unwrap density (1 - unwrap_count/1500)
#   15: structural test count (capped at 30)
#   15: doc artifacts presence (5 artifacts × 3 pts each)
#   15: dead code hygiene (1 - allow_dead_code/20)
#   15: boundary test count (capped at 15)
# =============================================================================

THEO_DIR="${1:?Usage: bash theo-evaluate.sh /path/to/theo-code}"
THEO_DIR="$(cd "$THEO_DIR" && pwd)"

CRATES="theo-domain theo-engine-graph theo-engine-retrieval theo-governance theo-engine-parser theo-tooling theo-infra-llm theo-agent-runtime theo-infra-auth theo-api-contracts theo-application theo theo-marklive"
TOTAL_CRATES=13
PER_CRATE_TIMEOUT=300

TMPDIR_EVAL=$(mktemp -d)
cd "$THEO_DIR"

# =============================================================================
# Phase 1: Compile check per crate
# =============================================================================

compile_ok=0
total_warnings=0
compile_start=$(date +%s%N)

for crate in $CRATES; do
    errlog="$TMPDIR_EVAL/cc_${crate}.err"
    timeout "$PER_CRATE_TIMEOUT" cargo test -p "$crate" --no-run 1>/dev/null 2>"$errlog"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        compile_ok=$((compile_ok + 1))
    fi
    cw=$(grep -c "^warning: " "$errlog" 2>/dev/null || true)
    summaries=$(grep -c "^warning: \`" "$errlog" 2>/dev/null || true)
    cw=$((cw - summaries))
    if [ "$cw" -gt 0 ] 2>/dev/null; then
        total_warnings=$((total_warnings + cw))
    fi
done

compile_end=$(date +%s%N)
compile_secs=$(python3 -c "print(f'{($compile_end - $compile_start) / 1e9:.1f}')")

# =============================================================================
# Phase 2: Run tests per crate
# =============================================================================

tests_passed=0
tests_failed=0
tests_ignored=0
test_start=$(date +%s%N)

for crate in $CRATES; do
    errlog="$TMPDIR_EVAL/cc_${crate}.err"
    if grep -q "^error" "$errlog" 2>/dev/null; then
        continue
    fi

    test_log="$TMPDIR_EVAL/test_${crate}.log"
    timeout "$PER_CRATE_TIMEOUT" cargo test -p "$crate" --no-fail-fast 2>&1 > "$test_log" || true

    while IFS= read -r line; do
        if [[ "$line" =~ ([0-9]+)\ passed ]]; then
            tests_passed=$((tests_passed + BASH_REMATCH[1]))
        fi
        if [[ "$line" =~ ([0-9]+)\ failed ]]; then
            tests_failed=$((tests_failed + BASH_REMATCH[1]))
        fi
        if [[ "$line" =~ ([0-9]+)\ ignored ]]; then
            tests_ignored=$((tests_ignored + BASH_REMATCH[1]))
        fi
    done < <(grep "^test result:" "$test_log" 2>/dev/null)
done

test_end=$(date +%s%N)
test_secs=$(python3 -c "print(f'{($test_end - $test_start) / 1e9:.1f}')")

# =============================================================================
# Phase 3: Layer 2 metrics collection
# =============================================================================

l2_start=$(date +%s%N)

# 3a. Clippy warnings (workspace-wide, exclude desktop)
clippy_log="$TMPDIR_EVAL/clippy.log"
timeout 300 cargo clippy --workspace --exclude theo-code-desktop 2>"$clippy_log" 1>/dev/null || true
clippy_warnings=$(grep -c "^warning: " "$clippy_log" 2>/dev/null || true)
clippy_summaries=$(grep -c "^warning: \`" "$clippy_log" 2>/dev/null || true)
clippy_warnings=$((clippy_warnings - clippy_summaries))
if [ "$clippy_warnings" -lt 0 ]; then clippy_warnings=0; fi

# 3b. Unwrap count in production code (exclude test files and test modules)
unwrap_count=$(grep -r "\.unwrap()" crates/*/src/ --include="*.rs" 2>/dev/null | grep -v "/tests/" | grep -v "_test\.rs" | wc -l || echo 0)

# 3c. Structural tests count (governance tests for code quality)
structural_tests=0
if [ -f "crates/theo-governance/tests/structural_hygiene.rs" ]; then
    structural_tests=$(grep -c "#\[test\]" "crates/theo-governance/tests/structural_hygiene.rs" 2>/dev/null || echo 0)
fi

# 3d. Boundary tests count
boundary_tests=0
if [ -f "crates/theo-governance/tests/boundary_test.rs" ]; then
    boundary_tests=$(grep -c "#\[test\]" "crates/theo-governance/tests/boundary_test.rs" 2>/dev/null || echo 0)
fi

# 3e. Doc artifacts presence (3 pts each, 5 artifacts = 15 pts max)
doc_artifacts=0
[ -f "clippy.toml" ] && doc_artifacts=$((doc_artifacts + 1))
[ -f ".theo/AGENTS.md" ] && [ "$(wc -c < .theo/AGENTS.md 2>/dev/null || echo 0)" -gt 500 ] && doc_artifacts=$((doc_artifacts + 1))
[ -f ".theo/QUALITY_RULES.md" ] && [ "$(wc -c < .theo/QUALITY_RULES.md 2>/dev/null || echo 0)" -gt 500 ] && doc_artifacts=$((doc_artifacts + 1))
[ -f ".theo/QUALITY_SCORE.md" ] && [ "$(wc -c < .theo/QUALITY_SCORE.md 2>/dev/null || echo 0)" -gt 500 ] && doc_artifacts=$((doc_artifacts + 1))
if [ -f "crates/theo-governance/tests/structural_hygiene.rs" ] && [ "$structural_tests" -ge 10 ]; then
    doc_artifacts=$((doc_artifacts + 1))
fi

# 3f. Dead code attributes
dead_code_attrs=$(grep -r '#\[allow(dead_code)\]' crates/*/src/ --include="*.rs" 2>/dev/null | wc -l || echo 0)

l2_end=$(date +%s%N)
l2_secs=$(python3 -c "print(f'{($l2_end - $l2_start) / 1e9:.1f}')")

# =============================================================================
# Phase 4: Compute dual-layer score
# =============================================================================

tests_total=$((tests_passed + tests_failed))
test_count=$((tests_passed + tests_failed + tests_ignored))

score=$(python3 -c "
# Layer 1 — Workspace Hygiene (100 raw pts)
co = $compile_ok; tc = $TOTAL_CRATES
tp = $tests_passed; tt = $tests_total; tn = $test_count; w = $total_warnings

l1_compile = 40.0 * co / tc if tc > 0 else 0.0
l1_tests   = 40.0 * tp / tt if tt > 0 else 0.0
l1_count   = 10.0 * min(1.0, tn / 2500.0)
l1_warn    = 10.0 * max(0.0, 1.0 - w / 100.0)
l1 = l1_compile + l1_tests + l1_count + l1_warn

# Layer 2 — Harness Maturity (100 raw pts)
cw = $clippy_warnings; uw = $unwrap_count; st = $structural_tests
da = $doc_artifacts; dc = $dead_code_attrs; bt = $boundary_tests

l2_clippy     = 20.0 * max(0.0, 1.0 - cw / 200.0)
l2_unwrap     = 20.0 * max(0.0, 1.0 - uw / 1500.0)
l2_structural = 15.0 * min(1.0, st / 30.0)
l2_docs       = 3.0 * da  # 5 artifacts × 3 pts = 15 max
l2_deadcode   = 15.0 * max(0.0, 1.0 - dc / 20.0)
l2_boundary   = 15.0 * min(1.0, bt / 15.0)
l2 = l2_clippy + l2_unwrap + l2_structural + l2_docs + l2_deadcode + l2_boundary

score = (l1 + l2) / 2.0
print(f'{score:.3f}')
print(f'{l1:.3f}')
print(f'{l2:.3f}')
")

# Parse the 3 lines from python
final_score=$(echo "$score" | sed -n '1p')
l1_score=$(echo "$score" | sed -n '2p')
l2_score=$(echo "$score" | sed -n '3p')

# =============================================================================
# Output (grep-friendly)
# =============================================================================

echo "---"
echo "score:              ${final_score}"
echo "l1_score:           ${l1_score}"
echo "l2_score:           ${l2_score}"
echo "compile_crates:     ${compile_ok}/${TOTAL_CRATES}"
echo "tests_passed:       ${tests_passed}"
echo "tests_failed:       ${tests_failed}"
echo "tests_total:        ${tests_total}"
echo "test_count:         ${test_count}"
echo "cargo_warnings:     ${total_warnings}"
echo "clippy_warnings:    ${clippy_warnings}"
echo "unwrap_count:       ${unwrap_count}"
echo "structural_tests:   ${structural_tests}"
echo "boundary_tests:     ${boundary_tests}"
echo "doc_artifacts:      ${doc_artifacts}/5"
echo "dead_code_attrs:    ${dead_code_attrs}"
echo "compile_secs:       ${compile_secs}"
echo "test_secs:          ${test_secs}"
echo "l2_secs:            ${l2_secs}"
echo "---"

# Cleanup
rm -rf "$TMPDIR_EVAL"
