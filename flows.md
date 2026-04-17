# Autoloop Flows

Fluxos operacionais do agente autônomo. Cada fluxo define entradas, saídas, decisões e ações.

---

## 1. Session Bootstrap Flow

Executado uma vez no início de cada sessão. Inspirado na bootstrap sequence da Anthropic.

```
SESSION START
  │
  ├─ 1. pwd + git branch (confirmar repo e branch)
  │
  ├─ 2. git log --oneline -10 (entender estado recente)
  │
  ├─ 3. Read progress.md (onde parou a última sessão)
  │
  ├─ 4. Read results.tsv (último score conhecido)
  │
  ├─ 5. Read feature_list.json (próxima feature pendente)
  │
  ├─ 6. Run baseline eval
  │     bash theo-evaluate.sh > eval.log 2>&1
  │     grep "^score:" eval.log
  │
  ├─ 7. Determine phase
  │     ├─ L1 < 95 → STABILIZE
  │     ├─ doc_artifacts < 5/5 → SCAFFOLD
  │     ├─ L2 < 60 → FORTIFY
  │     ├─ score improving → POLISH
  │     └─ score plateau → MAINTAIN
  │
  └─ 8. Begin experiment loop
```

**Saída**: Fase atual, score atual, próxima feature a trabalhar.

---

## 2. Experiment Loop Flow

O loop principal. Cada iteração é um experimento atômico.

```
EXPERIMENT LOOP
  │
  ├─ 1. SELECT
  │     Read feature_list.json
  │     Pick highest-priority pending feature for current phase
  │     Read target files listed in feature
  │
  ├─ 2. IMPLEMENT
  │     Make focused code change (1-50 lines, max 200)
  │     One logical change per experiment
  │
  ├─ 3. COMMIT
  │     git add -A
  │     git commit -m "experiment: <description>"
  │
  ├─ 4. EVALUATE
  │     bash theo-evaluate.sh > eval.log 2>&1
  │     Extract: score, l1_score, l2_score
  │     If grep empty → EVAL_CRASH → tail eval.log → diagnose
  │
  ├─ 5. DECIDE
  │     score_after > score_before?
  │     ├─ YES (keep)
  │     │   Log to results.tsv: status=keep
  │     │   Log to experiment_traces.jsonl
  │     │   Update progress.md
  │     │   If feature complete → update feature_list.json status="done"
  │     │   keeps_since_gc += 1
  │     │
  │     └─ NO (discard)
  │         git reset --hard HEAD~1
  │         Log to results.tsv: status=discard
  │         Log to experiment_traces.jsonl with failure_reason
  │         consecutive_discards += 1
  │
  ├─ 6. GUARDRAIL CHECK
  │     ├─ consecutive_discards ≥ 5? → G11: re-evaluate strategy
  │     ├─ same_score × 3? → G9: switch crate/feature
  │     ├─ attempt_count ≥ 3 for same idea? → G6: skip feature
  │     └─ OK → continue
  │
  └─ 7. GARBAGE COLLECTION (every 10 keeps)
        ├─ Update QUALITY_SCORE.md with current per-crate metrics
        ├─ Trim progress.md (keep last 20 entries)
        └─ Commit: "maintenance: update quality dashboard"
```

**Invariantes**:
- Cada iteração é exatamente 1 commit (keep) ou 0 commits (discard)
- O score nunca regride entre iterações mantidas
- Todo experimento é logado

---

## 3. Phase Transition Flow

Transição automática entre fases baseada em métricas.

```
CHECK PHASE
  │
  ├─ L1 < 95?
  │   └─ YES → STABILIZE
  │       Priority: compile errors → warnings → failing tests → test count
  │       Exit: L1 ≥ 95
  │
  ├─ doc_artifacts < 5/5?
  │   └─ YES → SCAFFOLD
  │       Priority: clippy.toml → AGENTS.md → QUALITY_RULES.md
  │                 → QUALITY_SCORE.md → structural_hygiene.rs
  │       Exit: doc_artifacts = 5/5
  │
  ├─ L2 < 60?
  │   └─ YES → FORTIFY
  │       Priority: boundary tests → structural tests → clippy fixes
  │                 → unwrap removal → dead code removal
  │       Work order: leaf crates first (theo-domain, governance, api-contracts)
  │                   then engines, then runtime, then application, then CLI
  │       Exit: L2 ≥ 60
  │
  ├─ Score still improving?
  │   └─ YES → POLISH
  │       Focus: remaining unwraps, deeper tests, complex clippy fixes
  │       Exit: 5+ experiments with no improvement
  │
  └─ NO → MAINTAIN
      Focus: garbage collection, dashboard updates, opportunity scan
      Exit: never (runs until human interrupts)
```

---

## 4. Failure Recovery Flow

Ações específicas por tipo de falha. Baseado na failure taxonomy dos NLAHs.

```
FAILURE DETECTED
  │
  ├─ COMPILE_ERROR
  │   attempt < 3?
  │   ├─ YES → Read error message. Fix the specific error. Retry.
  │   └─ NO  → Revert. Skip this feature. Log "COMPILE_ERROR × 3".
  │
  ├─ TEST_REGRESSION (tests_failed > 0)
  │   └─ Revert immediately. Do NOT retry same approach.
  │      Try fundamentally different approach or different feature.
  │
  ├─ CLIPPY_REGRESSION (clippy_warnings increased)
  │   └─ Read clippy message. Usually a simple fix.
  │      Fix and re-commit. If can't fix, revert.
  │
  ├─ UNWRAP_REGRESSION (unwrap_count increased)
  │   └─ Revert. Check diff for accidental .unwrap() additions.
  │
  ├─ SCORE_PLATEAU (3+ experiments, delta ≈ 0)
  │   └─ Switch to different crate or feature.
  │      If all features in current phase tried → advance phase.
  │
  ├─ SCORE_DROP (score decreased)
  │   └─ Revert. Analyze which metric dropped.
  │      Use metric breakdown to understand what went wrong.
  │
  ├─ EVAL_CRASH (eval produced no output)
  │   └─ Read last 50 lines of eval.log.
  │      Usually: timeout, build OOM, or cargo lock.
  │      Wait 30s, retry once. If still crashes, revert.
  │
  ├─ CONTEXT_EXHAUSTION (context window full)
  │   └─ Commit all progress. Update progress.md with:
  │      - Current score and phase
  │      - What was being worked on
  │      - What to try next
  │      Signal for fresh session.
  │
  └─ BUDGET_EXCEEDED (max time/attempts reached)
      └─ Stop loop. Log final state. Update progress.md.
         Do NOT start new experiments.
```

---

## 5. Crate Work Order Flow

Ordem de trabalho por crate, baseada no grafo de dependências.

```
DEPENDENCY GRAPH (leaf → root):

Level 0 (leaves):  theo-domain
Level 1:           theo-governance, theo-api-contracts
Level 2:           theo-engine-parser
Level 3:           theo-engine-graph
Level 4:           theo-engine-retrieval
Level 5:           theo-tooling, theo-infra-llm, theo-infra-auth
Level 6:           theo-agent-runtime
Level 7:           theo-application
Level 8:           theo-cli, theo-marklive

RULE: Always work on the lowest-level (leaf-most) crate first.
REASON: Changes to leaf crates have minimal rebuild cascading.
        Changes to theo-domain rebuild EVERYTHING.
```

---

## Referências

- **Bootstrap sequence**: Anthropic (Young, 2025) — "run through a series of steps to get its bearings"
- **Incremental progress**: Anthropic (Young, 2025) — "work on only one feature at a time"
- **Garbage collection**: OpenAI (Lopopolo, 2026) — "recurring cleanup process on regular cadence"
- **Failure taxonomy**: NLAHs (Pan et al., 2026) — "named failure modes that drive recovery"
- **Leaf-first**: theo-architecture.md — "changes to theo-domain rebuild EVERYTHING"
- **Phase strategy**: Karpathy autoresearch — monotonic improvement with keep/discard
