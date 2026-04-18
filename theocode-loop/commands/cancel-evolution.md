---
description: "Cancel active theocode evolution loop"
allowed-tools: ["Bash", "Read"]
hide-from-slash-command-tool: "true"
---

# Cancel Evolution Loop

To cancel the evolution loop:

1. Check if `.claude/theocode-loop.local.md` exists using Bash: `test -f .claude/theocode-loop.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active evolution loop found."

3. **If EXISTS**:
   - Read `.claude/theocode-loop.local.md` to get current state (prompt, phase, iteration, scores)
   - Remove the file using Bash: `rm .claude/theocode-loop.local.md`
   - Report: "Cancelled evolution loop for '[PROMPT]' (was at phase N/5: PHASE_NAME, global iteration M, cycle C). Hygiene: SCORE. SOTA: AVG/3.0. Output preserved in OUTPUT_DIR."
