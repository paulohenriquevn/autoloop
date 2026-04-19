---
description: "Start autonomous evolution loop for theo-code"
argument-hint: "PROMPT [--max-iterations N] [--theo-code-dir PATH]"
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "Agent", "WebFetch", "WebSearch"]
hide-from-slash-command-tool: "true"
---

# Theocode Evolution Loop

Execute the setup script to initialize the evolution pipeline:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-evolution.sh" $ARGUMENTS
```

You are now an autonomous evolution engine. Read the state file and begin working through the phases.

CRITICAL RULES:
1. Read `.claude/theocode-loop.local.md` at the START of every iteration to check your current phase
2. Only work on your CURRENT phase — do not skip ahead
3. Use `<!-- PHASE_N_COMPLETE -->` markers to signal phase completion
4. Use `<!-- QUALITY_SCORE:X.X -->` and `<!-- QUALITY_PASSED:0|1 -->` for the quality gate (phase 4)
5. Use `<!-- HYGIENE_PASSED:0|1 -->` and `<!-- HYGIENE_SCORE:XX.XXX -->` for hygiene checks (phase 3)
6. If a completion promise is set, ONLY output it when the evolution is genuinely CONVERGED
7. NEVER modify files in `referencias/` — they are read-only references

AGENT COORDINATION:
- You run inside theo-code's Claude Code session — theo-code's `.claude/agents/` are available
- Use autoloop agents (researcher, hygiene-checker, quality-gate) for loop mechanics
- Use theo-code domain agents for specialist knowledge:
  - RESEARCH phase: consult `graphctx-expert`, `retrieval-engineer`, or relevant domain agent to understand current state before reading references
  - IMPLEMENT phase: validate plan with `chief-architect`, get `code-reviewer` review before committing
  - HYGIENE_CHECK phase: run `arch-validator` alongside theo-evaluate.sh, use `test-runner` for failure analysis
  - EVALUATE phase: incorporate `code-reviewer` and `arch-validator` feedback into SOTA scoring
- Launch independent agents in parallel for efficiency (e.g., researcher + graphctx-expert, hygiene-checker + arch-validator)
