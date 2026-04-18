---
description: "View current theocode evolution loop status"
allowed-tools: ["Bash", "Read", "Glob"]
hide-from-slash-command-tool: "true"
---

# Evolution Loop Status

Check and display the current evolution loop status:

1. Check if `.claude/theocode-loop.local.md` exists: `test -f .claude/theocode-loop.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active evolution loop."

3. **If EXISTS**:
   - Read `.claude/theocode-loop.local.md` to get all state fields
   - Check for `.theo/evolution_research.md`, `.theo/evolution_assessment.md`
   - Display a formatted status report:

```
Evolution Loop Status
---------------------
Prompt:           [prompt]
Phase:            [N]/5 — [phase_name]
Phase iteration:  [phase_iteration]/[phase_max]
Global iteration: [global_iteration]/[max_global_iterations]
Cycle:            [iteration_cycle]
Started:          [started_at]

Scores:
  Hygiene (floor): [current_score] (baseline: [baseline_score])
  SOTA average:    [sota_average]/3.0 (target: 2.5)

Artifacts:
  evolution_research.md:   [exists/missing]
  evolution_criteria.md:   [exists/missing]
  evolution_assessment.md: [exists/missing]
  evolution_log.jsonl:     [N entries]
```
