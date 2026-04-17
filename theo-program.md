# theo-code autoresearch

This is an experiment to have an LLM autonomously improve a Rust codebase using a dual-layer evaluation system.

The subject is **theo-code** — an AI coding assistant built in Rust (11 crates, ~30K LOC). You will make incremental improvements across two dimensions: workspace hygiene (Layer 1) and harness engineering maturity (Layer 2).

## Setup

To set up a new experiment, work with the user to:

1. **Agree on a run tag**: propose a tag based on today's date (e.g. `apr16`). The branch `autoresearch/<tag>` must not already exist.
2. **Create the branch**: `git checkout -b autoresearch/<tag>` from current master.
3. **Read the in-scope files** (in this order):
   - `theo-architecture.md` (in autoresearch repo) — **complete architecture map**. Read this first.
   - `.theo/feature_list.json` — **20 prioritized features** across Layer 1 and Layer 2.
   - `Cargo.toml` — workspace members.
   - This file (`theo-program.md`) — your instructions.
4. **Verify evaluation harness**: Run the eval and confirm it produces a dual-layer metrics block:
   ```
   bash /home/paulo/Projetos/usetheo/autoloop/theo-evaluate.sh /home/paulo/Projetos/usetheo/theo-code
   ```
5. **Initialize results.tsv** with the header row if it doesn't exist.
6. **Initialize progress.md** if it doesn't exist.
7. **Confirm and go**.

## Session Bootstrap Sequence

Every session (including the first) starts with this fixed sequence. Do NOT skip steps.

```
1. pwd + git branch          → Confirm repo and branch
2. git log --oneline -10     → Understand recent state
3. Read progress.md          → Where did the last session stop?
4. Read results.tsv (tail)   → What's the current score?
5. Read feature_list.json    → What's the next pending feature?
6. Run baseline eval         → Confirm actual score matches expected
7. Determine phase           → STABILIZE / SCAFFOLD / FORTIFY / POLISH / MAINTAIN
8. Begin experiment loop     → Pick feature, start working
```

**Why this sequence matters**: Each new session begins with no memory of what came before. This bootstrap ensures the agent quickly understands the full state without guessing.

## Dual-Layer Score

The evaluation produces **score = (L1 + L2) / 2** where:

**Layer 1 — Workspace Hygiene** (0-100):
- 40 pts: crates that compile
- 40 pts: test pass rate
- 10 pts: total test count (capped at 2500)
- 10 pts: cargo warning penalty

**Layer 2 — Harness Maturity** (0-100):
- 20 pts: clippy cleanliness (fewer clippy warnings = better)
- 20 pts: unwrap density (fewer unwrap() in production = better)
- 15 pts: structural test count (governance tests for code quality)
- 15 pts: documentation artifacts (clippy.toml, AGENTS.md, QUALITY_RULES.md, QUALITY_SCORE.md, structural_hygiene.rs)
- 15 pts: dead code hygiene (fewer #[allow(dead_code)] = better)
- 15 pts: boundary test count (architectural enforcement tests)

**The goal: get the highest combined score.** Every improvement to either layer increases the score.

## Scope rules

**What you CAN do:**
- Modify any `.rs` file in `crates/` and `apps/` (except `apps/theo-benchmark/`)
- Create new test files in `crates/*/tests/`
- Create documentation files in `.theo/` (AGENTS.md, QUALITY_RULES.md, QUALITY_SCORE.md)
- Create `clippy.toml` at workspace root
- Fix compiler errors, warnings, clippy warnings
- Replace `unwrap()` with proper error handling
- Remove dead code and `#[allow(dead_code)]`

**What you CANNOT do:**
- Modify `theo-evaluate.sh` — immutable ground truth
- Modify files in `apps/theo-benchmark/`
- Add new workspace members (no new crates)
- Add new external dependencies to `[workspace.dependencies]`
- Delete existing test functions
- Change the evaluation score formula

## Guardrails

See `guardrails.md` for full details. Key rules enforced during experiments:

### Circuit Breakers
- **G6**: Max 3 attempts per idea. Failed 3×? Skip to next feature.
- **G8**: Zero tolerance for test regression. `tests_failed > 0` = immediate revert.
- **G9**: Plateau detection. 3 same-score experiments = switch crate/feature.
- **G10**: Max 200 lines changed per experiment.
- **G11**: 5 consecutive reverts = re-evaluate strategy entirely.

### Crate Work Order (leaf-first)
Changes to leaf crates minimize rebuild cascading. Always prefer:
```
Level 0: theo-domain (CAUTION: rebuilds everything)
Level 1: theo-governance, theo-api-contracts
Level 2: theo-engine-parser
Level 3: theo-engine-graph
Level 4: theo-engine-retrieval
Level 5: theo-tooling, theo-infra-llm, theo-infra-auth
Level 6: theo-agent-runtime
Level 7: theo-application
Level 8: theo-cli, theo-marklive
```

## Strategy: 5 Phases

The experiment progresses through 5 phases. Check your current eval output to determine which phase you're in.

### Phase 1: STABILIZE (while l1_score < 95)

Focus exclusively on Layer 1. Get the workspace clean.

**Priority order:**
1. Fix theo-application compile errors (if any)
2. Fix cargo warnings (unused imports, dead code warnings)
3. Fix any failing tests
4. Add tests to undercovered crates (api-contracts, governance, engine-graph)

**Exit condition:** l1_score ≥ 95

### Phase 2: SCAFFOLD (while doc_artifacts < 5/5)

Create the Layer 2 documentation artifacts. These are quick wins — each adds +3 pts.

**Create in order:**
1. `clippy.toml` at workspace root
2. `.theo/AGENTS.md` — navigation map (NOT a manual), ~100 lines
3. `.theo/QUALITY_RULES.md` — mechanical quality rules, ~80 lines
4. `.theo/QUALITY_SCORE.md` — per-crate health dashboard, ~60 lines
5. `crates/theo-governance/tests/structural_hygiene.rs` with 10+ tests

**Exit condition:** doc_artifacts = 5/5

### Phase 3: FORTIFY (while l2_score < 60)

Deep Layer 2 work. This is the bulk of the overnight run.

**Priority order:**
1. Expand boundary tests (5 → 15+)
2. Expand structural tests (10 → 30+)
3. Fix clippy warnings (start with leaf crates to avoid rebuild cascade)
4. Replace unwrap() calls (start with theo-domain, then governance, then engines)
5. Remove #[allow(dead_code)] attributes

**Key rule for unwrap removal:** Work crate by crate, leaf crates first. Each experiment = one crate's unwrap fixes. Do NOT try to fix all 1265 at once.

**Key rule for clippy:** Fix warnings that are real code quality issues. Do NOT add `#[allow(clippy::...)]` to suppress — that defeats the purpose.

**Exit condition:** l2_score ≥ 60

### Phase 4: POLISH (score still improving)

When the main metrics are solid, look for remaining opportunities:
- Re-read feature_list.json for uncompleted items
- Add deeper tests to any crate with <50 tests
- Look at theo-architecture.md for score opportunity table
- Try combining near-miss ideas from previous experiments

**Exit condition:** 5+ experiments with no score improvement

### Phase 5: MAINTAIN (continuous)

Garbage collection and sustained evolution:
- Update QUALITY_SCORE.md with current metrics
- Scan for new patterns (new unwraps, new warnings)
- Re-read feature_list.json for remaining work
- Keep score stable — any regression is priority 0

**Exit condition:** Human interruption

## Failure Taxonomy

Every discarded experiment must be classified with exactly one failure code:

| Code | Meaning | Action |
|---|---|---|
| `COMPILE_ERROR` | Code doesn't compile | Fix or revert. Max 3 attempts per idea. |
| `TEST_REGRESSION` | Tests that passed now fail | Revert immediately. Try different approach. |
| `CLIPPY_REGRESSION` | More clippy warnings than before | Usually easy fix — read the clippy message. |
| `UNWRAP_REGRESSION` | Added unwrap() accidentally | Revert and check your diff. |
| `SCORE_PLATEAU` | Score didn't change | Switch to different feature or crate. |
| `SCORE_DROP` | Score decreased | Revert. Analyze which metric dropped. |
| `EVAL_CRASH` | Evaluation produced no output | Check eval.log. Usually a timeout or build error. |
| `CONTEXT_EXHAUSTION` | Context window full | Commit progress, update progress.md, start fresh. |
| `BUDGET_EXCEEDED` | Max time/attempts reached | Stop. Log final state. |

## Output format

The evaluation harness prints:

```
---
score:              52.454
l1_score:           90.775
l2_score:           14.133
compile_crates:     12/13
tests_passed:       2453
tests_failed:       0
tests_total:        2453
test_count:         2463
cargo_warnings:     60
clippy_warnings:    543
unwrap_count:       1265
structural_tests:   0
boundary_tests:     5
doc_artifacts:      0/5
dead_code_attrs:    12
compile_secs:       126.3
test_secs:          ...
l2_secs:            8.2
---
```

Extract key metrics:
```
grep "^score:\|^l1_score:\|^l2_score:\|^compile_crates:\|^tests_passed:\|^clippy_warnings:\|^unwrap_count:" eval.log
```

## Logging

### results.tsv
Log every experiment (tab-separated, NOT committed to git).

```
commit	score	l1_score	l2_score	compile_crates	tests_passed	clippy_warnings	unwrap_count	status	description
```

### experiment_traces.jsonl
Structured trace for each experiment (NOT committed to git):

```json
{"timestamp":"2026-04-17T10:30:00Z","commit":"a1b2c3d","phase":"STABILIZE","feature_id":"fix-cargo-warnings","score_before":53.830,"score_after":55.100,"delta":1.270,"status":"keep","failure_reason":null,"files_changed":3,"lines_changed":12,"duration_secs":240,"crate":"theo-engine-retrieval"}
```

### progress.md
Session continuity file. Updated after every experiment. Format:

```markdown
## Last Update: 2026-04-17 10:30 UTC

**Phase**: STABILIZE
**Score**: 55.100 (L1=96.0, L2=14.2)
**Experiments**: 5 total, 3 kept, 2 discarded

### Recent
- [keep] fix-cargo-warnings: removed unused imports in engine-retrieval (+1.27)
- [discard] fix-cargo-warnings: removed EXCERPT_MAX_CHARS constant (COMPILE_ERROR)
- [keep] fix-cargo-warnings: removed unused mut in context_assembler (+0.15)

### Next Steps
- Continue fixing cargo warnings in theo-engine-parser (13 unused imports)
- After warnings done, move to SCAFFOLD phase
```

## The experiment loop

LOOP FOREVER:

1. Check eval output to determine current phase (Stabilize/Scaffold/Fortify/Polish/Maintain).
2. Read `.theo/feature_list.json` and pick the highest-priority pending feature for your phase.
3. Make a focused code change (one logical change, typically 1-50 lines, max 200 lines).
4. `git add -A && git commit -m "experiment: <description>"`
5. Run evaluation:
   ```
   bash /home/paulo/Projetos/usetheo/autoloop/theo-evaluate.sh /home/paulo/Projetos/usetheo/theo-code > eval.log 2>&1
   ```
6. Read results: `grep "^score:\|^l1_score:\|^l2_score:" eval.log`
7. If grep is empty → evaluation crashed. `tail -n 50 eval.log` to diagnose.
8. Record results in results.tsv and experiment_traces.jsonl.
9. If score improved (higher) → keep, advance the branch, update progress.md.
10. If score equal or worse → `git reset --hard HEAD~1`, log with failure code.
11. If a feature is now complete, update its status to `"done"` in feature_list.json and commit.
12. Check guardrails (G6, G9, G11). If triggered, adjust strategy.
13. Every 10 keeps: run garbage collection (update QUALITY_SCORE.md, trim progress.md).

## Simplicity criterion

Same as the original autoresearch: a small score improvement that adds ugly complexity is not worth it. Removing dead code and getting equal or better score is a great outcome.

**Special for Layer 2:** Creating a well-written .theo/AGENTS.md that's genuinely useful is better than a bloated one that just hits the 500-byte threshold. Quality matters — these files will be read by the agent itself in future sessions.

## NEVER STOP

Once the experiment loop has begun, do NOT pause to ask the human. Do NOT ask "should I keep going?" The human might be asleep. You are autonomous. If you run out of ideas, think harder — re-read theo-architecture.md, re-read feature_list.json, look at eval metrics for the lowest-scoring component and target it.

The loop runs until the human interrupts you, period.

## Key files reference

```
Cargo.toml                          — workspace members
crates/theo-domain/src/             — pure types (247 tests)
crates/theo-agent-runtime/src/      — agent loop, pilot (~14K LOC, 338 tests)
crates/theo-engine-parser/src/      — tree-sitter parsing (468 tests)
crates/theo-engine-retrieval/src/   — retrieval engine (220 tests)
crates/theo-engine-graph/src/       — code graph (43 tests)
crates/theo-tooling/src/            — 40+ tools (144 tests)
crates/theo-infra-llm/src/          — 25 LLM providers (156 tests)
crates/theo-governance/src/         — sandbox, policy (41 tests)
crates/theo-governance/tests/       — boundary_test.rs (5 tests), structural_hygiene.rs (create here)
crates/theo-application/src/        — use cases (58 tests)
crates/theo-infra-auth/src/         — auth (87 tests)
crates/theo-api-contracts/src/      — DTOs (0 tests)
apps/theo-cli/src/                  — CLI (package: "theo")
```

## References

This approach combines evidence from:
- [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — autonomous modify-evaluate-keep/discard loop
- [Anthropic's effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — feature lists, incremental progress, session continuity
- [Harness engineering](https://martinfowler.com/articles/harness-engineering.html) (Böckeler/Fowler) — feedforward guides + feedback sensors
- [OpenAI's harness engineering](https://openai.com/index/harness-engineering/) — repo knowledge as system of record, garbage collection
- [VeRO](https://arxiv.org/abs/2602.22480) (Scale AI) — versioned evaluation harness for agent optimization
- [OpenDev](https://arxiv.org/abs/2603.05344) (Bui) — defense-in-depth, context engineering, system reminders
- [NLAHs](https://arxiv.org/abs/2603.25723) (Pan et al.) — contracts, failure taxonomy, stage structure
- [ProjDevBench](https://arxiv.org/abs/2602.01655) (Lu et al.) — dual evaluation, specification compliance
- [llvm-autofix](https://arxiv.org/abs/2603.20075) (Zheng et al.) — domain-specific harness tooling
