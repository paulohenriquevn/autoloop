# theocode-loop

Claude Code plugin that runs an autonomous evolution loop for [theo-code](https://github.com/usetheodev/theo-code). Give it an evolution prompt, walk away, come back to a SOTA implementation.

## How it works

```
/theocode-loop:evolution-loop "Evolua o context manager"
```

The plugin enters an autonomous loop:

1. **RESEARCH** — Reads reference repos (`referencias/`), extracts SOTA patterns
2. **IMPLEMENT** — Makes focused code changes (max 200 lines/iteration)
3. **HYGIENE CHECK** — Runs `theo-evaluate.sh`, ensures score didn't drop
4. **EVALUATE** — Self-assesses against a 5-dimension SOTA rubric
5. **ITERATE** — If quality < 2.5/3.0, loops back to IMPLEMENT

The loop converges when the average rubric score reaches 2.5 or max iterations are exhausted.

## Install

```bash
# From GitHub marketplace
claude plugin marketplace add paulohenriquevn/theocode-loop
claude plugin install theocode-loop --scope project

# Or locally for development
claude --plugin-dir /path/to/theocode-loop
```

## Commands

| Command | Description |
|---------|-------------|
| `/theocode-loop:evolution-loop PROMPT` | Start evolution loop |
| `/theocode-loop:evolution-status` | View current status |
| `/theocode-loop:cancel-evolution` | Cancel active loop |
| `/theocode-loop:help` | Show documentation |

## SOTA Quality Rubric

| Dimension | What it measures |
|---|---|
| Pattern Fidelity | Does it reflect patterns from reference repos? |
| Architectural Fit | Does it respect theo-code boundaries? |
| Completeness | Production-ready with error handling? |
| Testability | Meaningful tests added? |
| Simplicity | Minimal and focused? |

Each dimension scored 0-3. Convergence at average >= 2.5.

## Agents

| Agent | Role |
|-------|------|
| chief-evolver | Orchestrates the full cycle |
| researcher | Reads reference repos (read-only) |
| quality-gate | SOTA rubric evaluation |
| hygiene-checker | Runs evaluation harness |

## Prerequisites

- Rust toolchain (rustc + cargo)
- Python 3.6+
- Git
- theo-code repo with `referencias/` containing reference repos

## License

MIT
