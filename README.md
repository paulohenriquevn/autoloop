# autoloop

Autonomous evolution loop for [theo-code](https://github.com/usetheodev/theo-code), an AI coding assistant built in Rust. Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) pattern: an AI agent researches SOTA patterns from reference implementations, implements them incrementally, self-evaluates against a quality rubric, and iterates until convergence.

## How it works

An AI agent (Claude Code) receives an evolution prompt (e.g., "Evolua o context manager"), researches patterns from reference repos, implements changes in theo-code, checks hygiene (must not regress), self-evaluates against a 5-dimension SOTA rubric, and iterates until quality converges.

The system evaluates a **Rust workspace with 11 library crates + 2 app binaries** and maintains a **dual-layer hygiene score** as an inviolable floor, while pursuing **SOTA quality** as the primary metric.

```
LOOP:
  1. RESEARCH — read reference repos, extract applicable patterns
  2. IMPLEMENT — focused code change (max 200 lines)
  3. HYGIENE CHECK — run theo-evaluate.sh, score must not drop
  4. SOTA EVALUATE — self-assess across 5 dimensions (0-3 each)
  5. ITERATE — if average < 2.5, address gaps and loop back
  6. CONVERGED — average ≥ 2.5, signal success
```

## Prerequisites

- **Rust toolchain** (rustc + cargo) — install via [rustup](https://rustup.rs/)
- **Python 3.6+** — used for score computation inside the eval harness
- **Git** — for experiment versioning
- **theo-code repo** — cloned locally with `referencias/` containing reference repos

## Files that matter

| File | Purpose | Who edits |
|------|---------|-----------|
| `theo-evaluate.sh` | Immutable evaluation harness. Hygiene score 0-100. | **Nobody** (ground truth, chmod 444) |
| `theo-program.md` | Agent instructions. Evolution loop, research protocol, SOTA rubric usage. | **Human** (iterate on strategy) |
| `theo-architecture.md` | Complete architecture map of theo-code. | **Human** (update when architecture changes) |
| `reference-catalog.md` | Catalog of reference repos indexed by theo-code subsystem. | **Human** (update when repos change) |
| `sota-rubric.md` | SOTA quality rubric. 5 dimensions × 4 levels with examples. | **Human** (refine criteria) |
| `guardrails.md` | 20 guardrails in 4 layers. | **Human** |
| `metrics.md` | Hygiene metrics + SOTA rubric definition. | **Human** |
| `flows.md` | 5 operational flows. | **Human** |
| `roadmap.md` | Prompt-driven operational model. | **Human** |
| `CHANGELOG.md` | All notable changes to autoloop. | **Human** |
| `.theo/evolution_prompt.md` | Current evolution mission. Lives in theo-code. | **Human** (write the prompt) |
| `.theo/evolution_research.md` | Extracted patterns from references. Lives in theo-code. | **Agent** |
| `.theo/evolution_criteria.md` | SOTA criteria for current prompt. Lives in theo-code. | **Agent** |
| `.theo/evolution_assessment.md` | Latest self-assessment. Lives in theo-code. | **Agent** |
| `.theo/evolution_log.jsonl` | History of all evolution iterations. Lives in theo-code. Untracked. | **Agent** |
| `results.tsv` | Hygiene score log. Lives in theo-code. Untracked. | **Agent** |
| `progress.md` | Session continuity. Lives in theo-code. Untracked. | **Agent** |

## Dual-layer hygiene score (floor)

**Score = (L1 + L2) / 2** — used as an inviolable floor. See `metrics.md` for formulas.

**Layer 1 — Workspace Hygiene** (100 pts): compile success, test pass rate, test count, warning penalty.

**Layer 2 — Harness Maturity** (100 pts): clippy, unwrap density, structural tests, doc artifacts, dead code, boundary tests.

## SOTA quality rubric (primary metric)

The agent self-evaluates across 5 dimensions after each iteration. See `sota-rubric.md` for the full rubric.

| Dimension | What it measures | Score |
|---|---|:---:|
| Pattern Fidelity | Does it reflect SOTA patterns from references? | 0-3 |
| Architectural Fit | Does it respect theo-code's architecture? | 0-3 |
| Completeness | Production-ready with edge cases and error handling? | 0-3 |
| Testability | Meaningful tests covering behavior and invariants? | 0-3 |
| Simplicity | Minimal and focused implementation? | 0-3 |

**Convergence:** average ≥ 2.5

## Reference repos

The `referencias/` directory in theo-code contains 8 cloned repos that serve as SOTA references:

| Repo | What it teaches |
|------|----------------|
| Archon | YAML workflows, git worktree isolation, model routing |
| OpenDev | Rust agent fleet, ReAct loop, context compaction |
| OpenCode | Plugin system, MCP, Access Control Plane |
| Rippletide | Context graph, agent evaluation, governance rules |
| Pi-Mono | Multi-provider LLM, transport abstraction, compaction |
| QMD | Hybrid search (BM25 + vector + LLM re-ranking) |
| llm-wiki-compiler | Two-phase knowledge compilation, incremental hashing |
| awesome-harness-engineering | Curated harness patterns and topologies |

## Quick start

```bash
# 1. Run init (verifies toolchain, checks references, shows baseline)
bash theo-init.sh /path/to/theo-code

# 2. Create evolution branch in theo-code
cd /path/to/theo-code
git switch -c evolution/apr18

# 3. Write your evolution prompt
echo "Evolua o context manager para usar compaction em estágios" > .theo/evolution_prompt.md

# 4. Start Claude Code and point it to the instructions
# Prompt: "Read /path/to/autoloop/theo-program.md and start the evolution loop"
```

## Operator guide — reading results

After an evolution session:

### progress.md
Quick summary of what happened:
```bash
cat progress.md
# Shows: mission, phase, hygiene score, SOTA scores, recent iterations, gaps
```

### .theo/evolution_assessment.md
Latest self-assessment with evidence citations:
```bash
cat .theo/evolution_assessment.md
# Shows: 5-dimension scores, cited references, gaps, status
```

### .theo/evolution_log.jsonl
Full iteration history:
```bash
# Last 3 iterations
tail -3 .theo/evolution_log.jsonl | python3 -m json.tool

# Convergence trajectory
grep -o '"sota_average":[0-9.]*' .theo/evolution_log.jsonl
```

## Recovery procedures

### Branch in unknown state after crash
```bash
bash /path/to/autoloop/theo-evaluate.sh /path/to/theo-code
git log --oneline -20
sha256sum -c /path/to/autoloop/theo-evaluate.sha256
```

### Want to start a new evolution
```bash
git switch -c evolution/new-tag
rm -f results.tsv progress.md .theo/evolution_log.jsonl
# Edit .theo/evolution_prompt.md with new mission
bash /path/to/autoloop/theo-init.sh /path/to/theo-code
```

## Design principles

- **Immutable harness**: `theo-evaluate.sh` is never modified. Protected by chmod 444 and SHA-256.
- **Research-first**: Agent reads reference repos before implementing. No blind coding.
- **Dual evaluation**: Hygiene score (objective, scripted) + SOTA rubric (evidence-grounded self-assessment).
- **Hygiene floor**: Score must never decrease. SOTA with regression = revert.
- **Evidence-grounded**: SOTA assessment must cite specific reference patterns (G18).
- **Bounded iteration**: Max 15 iterations per prompt, 200 experiments per session.
- **Explicit staging**: Only allowed paths are staged (no `git add -A`).

## Background

This approach combines:
- [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — autonomous modify-evaluate-keep/discard loop
- [Anthropic's effective harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — incremental progress, session continuity
- [Harness engineering](https://martinfowler.com/articles/harness-engineering.html) (Böckeler/Fowler) — feedforward guides + feedback sensors
- [OpenAI's harness engineering](https://openai.com/index/harness-engineering/) — repo as system of record
- [VeRO](https://arxiv.org/abs/2602.22480) (Scale AI) — versioned evaluation, budget enforcement
- [ProjDevBench](https://arxiv.org/abs/2602.01655) (Lu et al.) — dual evaluation (execution + code review)

## License

MIT
