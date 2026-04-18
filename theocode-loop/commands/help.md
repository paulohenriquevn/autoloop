---
description: "Explain theocode evolution loop and available commands"
---

# Theocode Evolution Loop Help

Please explain the following to the user:

## What is the Theocode Evolution Loop?

A Claude Code plugin that runs an autonomous evolution pipeline for theo-code. You give it an evolution prompt (e.g., "Evolua o context manager"), and it iterates through 5 phases — researching SOTA patterns from reference repos, implementing them, checking hygiene, evaluating quality against a rubric, and iterating until convergence.

**Inspired by:**
- **Ralph Wiggum** (Geoffrey Huntley) — self-referential AI loop mechanism
- **Autoresearch** (Andrej Karpathy) — autonomous AI experimentation pattern
- **Harness Engineering** (Anthropic, Fowler, OpenAI) — feedforward/feedback control systems

## The 5 Phases

| Phase | Name | What happens | Max iterations |
|-------|------|-------------|---------------|
| 1 | RESEARCH | Read reference repos, extract SOTA patterns | 2 |
| 2 | IMPLEMENT | Apply patterns incrementally (max 200 lines/iter) | 5 |
| 3 | HYGIENE_CHECK | Run theo-evaluate.sh, verify score didn't drop | 1 |
| 4 | EVALUATE | Score against 5-dimension SOTA rubric | 1 |
| 5 | CONVERGED | Signal completion | 1 |

Phases 2→3→4 cycle until SOTA average >= 2.5 or max iterations reached.

## SOTA Quality Rubric (5 dimensions, 0-3 each)

| Dimension | What it measures |
|---|---|
| Pattern Fidelity | Does the implementation reflect SOTA patterns from references? |
| Architectural Fit | Does it respect theo-code's architecture? |
| Completeness | Production-ready with edge cases and error handling? |
| Testability | Meaningful tests covering behavior? |
| Simplicity | Minimal and focused implementation? |

**Convergence:** average >= 2.5

## Available Commands

### /theocode-loop:evolution-loop PROMPT [OPTIONS]

Start an evolution loop.

```
/theocode-loop:evolution-loop "Evolua o context manager"
/theocode-loop:evolution-loop "Implemente HyDE no retrieval" --max-iterations 20
/theocode-loop:evolution-loop "Refatore o agent loop" --theo-code-dir /path/to/theo-code
```

**Options:**
- `--max-iterations <n>` — Max global iterations (default: 15)
- `--theo-code-dir <path>` — Path to theo-code (auto-detected if in workspace)

### /theocode-loop:evolution-status

View current evolution loop status: prompt, phase, iteration, hygiene score, SOTA scores.

### /theocode-loop:cancel-evolution

Cancel an active evolution loop. Output files are preserved.

## Reference Repos

The plugin uses 8 reference repos in `theo-code/referencias/` for SOTA comparison:

| Repo | Relevance |
|------|-----------|
| OpenDev | Agent loop, context compaction (Rust) |
| QMD | Hybrid search, ranking |
| Pi-Mono | LLM providers, compaction |
| Archon | Workflows, model routing |
| OpenCode | Plugin system, MCP |
| Rippletide | Context graph, governance |
| llm-wiki-compiler | Knowledge compilation |
| awesome-harness-engineering | Harness patterns |

## Agents

| Agent | Role |
|-------|------|
| chief-evolver | Orchestrates the full loop |
| researcher | Reads reference repos (read-only) |
| quality-gate | SOTA rubric evaluation (keep/discard) |
| hygiene-checker | Runs theo-evaluate.sh |
