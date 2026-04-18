# Autoloop Flows

Fluxos operacionais do agente de evolução. Cada fluxo define entradas, saídas, decisões e ações.

---

## 1. Session Bootstrap Flow

Executado uma vez no início de cada sessão. Estabelece contexto completo antes de qualquer ação.

```
SESSION START
  │
  ├─ 1. pwd + git branch (confirmar repo e branch evolution/*)
  │
  ├─ 2. git log --oneline -10 (entender estado recente)
  │
  ├─ 3. Read progress.md (onde parou a última sessão)
  │     └─ Se ausente ou corrompido → ignorar, recalcular do baseline
  │
  ├─ 4. Read results.tsv (tail — último score de hygiene)
  │
  ├─ 5. Read .theo/evolution_prompt.md (missão atual)
  │     └─ Se ausente → STOP: pedir ao operador para fornecer o prompt
  │
  ├─ 6. Run baseline eval (piso de hygiene)
  │     bash <AUTOLOOP_DIR>/theo-evaluate.sh <THEO_CODE_DIR> > eval.log 2>&1
  │     grep "^score:" eval.log
  │
  ├─ 7. Read reference-catalog.md + sota-rubric.md
  │     Identificar quais referências são relevantes para o prompt
  │
  ├─ 8. Read .theo/evolution_assessment.md (se existe — última avaliação SOTA)
  │
  ├─ 9. Determine phase
  │     ├─ Sem evolution_research.md → RESEARCH
  │     ├─ Com research mas sem assessment → IMPLEMENT
  │     ├─ Com assessment e média < 2.5 → ITERATE
  │     ├─ Com assessment e média ≥ 2.5 → CONVERGED (esperar novo prompt)
  │     └─ iteration_count ≥ 15 → EVOLUTION_TIMEOUT
  │
  └─ 10. Begin evolution loop (ou aguardar novo prompt se CONVERGED)
```

**Saída:** Fase atual, score de hygiene, score SOTA (se existe), próxima ação.

---

## 2. Research Flow

Executado na primeira iteração e quando o agente precisa buscar novos padrões para gaps específicos.

```
RESEARCH
  │
  ├─ 1. PARSE PROMPT
  │     Ler .theo/evolution_prompt.md
  │     Identificar: subsistema alvo, crates envolvidos, tipo de mudança
  │
  ├─ 2. LOOKUP REFERENCES
  │     Consultar reference-catalog.md
  │     Selecionar max 3 repos relevantes (primários > secundários)
  │
  ├─ 3. READ REFERENCES (por repo, max 5 arquivos cada)
  │     Para cada repo selecionado:
  │     ├─ Ler README.md / CLAUDE.md (arquitetura geral)
  │     ├─ Ler 2-3 source files relevantes ao subsistema
  │     └─ Extrair padrões concretos:
  │         ├─ Data structures usadas
  │         ├─ Algoritmos / control flow
  │         ├─ Error handling patterns
  │         └─ Testing patterns
  │
  ├─ 4. DOCUMENT FINDINGS
  │     Escrever .theo/evolution_research.md:
  │     ├─ Padrões extraídos (com citações de arquivo)
  │     ├─ Como cada padrão mapeia para theo-code
  │     └─ Notas de adaptação (TS/Python → Rust)
  │
  ├─ 5. DEFINE CRITERIA
  │     Escrever .theo/evolution_criteria.md:
  │     ├─ O que "SOTA" significa para este prompt específico
  │     ├─ Quais capacidades a referência tem que theo-code não tem
  │     ├─ Melhoria mínima viável
  │     └─ O que está explicitamente fora de escopo
  │
  └─ 6. TRANSITION → IMPLEMENT
```

**Saída:** `evolution_research.md` e `evolution_criteria.md` populados. Pronto para implementar.

**Re-entry:** Quando o agente está em ITERATE e precisa buscar padrões específicos para gaps, executa apenas os passos 2-4 focados nas dimensões com score baixo.

---

## 3. Evolution Loop Flow

O loop principal. Cada iteração é uma mudança atômica avaliada em duas camadas.

```
EVOLUTION LOOP
  │
  ├─ 1. PLAN
  │     Ler .theo/evolution_research.md (padrões a aplicar)
  │     Ler .theo/evolution_assessment.md (gaps da iteração anterior, se existe)
  │     Decidir: qual padrão aplicar, em quais arquivos, escopo estimado
  │
  ├─ 2. IMPLEMENT
  │     Fazer mudança focada (1-50 linhas típico, max 200)
  │     Uma mudança lógica por iteração
  │
  ├─ 3. COMMIT (atômico)
  │     BEFORE_SHA=$(git rev-parse HEAD)
  │     git add <explicit paths only — NOT git add -A>
  │     git commit -m "evolution: <description>"
  │
  ├─ 4. HYGIENE CHECK (piso — pass/fail)
  │     bash <AUTOLOOP_DIR>/theo-evaluate.sh <THEO_CODE_DIR> > eval.log 2>&1
  │     Extract: score, l1_score, l2_score
  │     │
  │     ├─ Score dropped?
  │     │   └─ YES → REVERT
  │     │       git reset --hard "$BEFORE_SHA"
  │     │       Log: results.tsv (status=discard), evolution_log.jsonl
  │     │       Classify failure (COMPILE_ERROR, TEST_REGRESSION, etc.)
  │     │       Go to GUARDRAIL CHECK
  │     │
  │     └─ Score maintained or improved?
  │         └─ YES → continue to SOTA EVALUATE
  │         Log: results.tsv (status=keep)
  │
  ├─ 5. SOTA EVALUATE (teto — rubric scoring)
  │     Auto-avaliar nas 5 dimensões (0-3 cada):
  │     ├─ Pattern Fidelity (citar referência específica — G18)
  │     ├─ Architectural Fit (verificar fronteiras — theo-architecture.md)
  │     ├─ Completeness (edge cases, error handling)
  │     ├─ Testability (testes adicionados, cobertura)
  │     └─ Simplicity (YAGNI check, LOC proporcionais)
  │     │
  │     Calcular média
  │     Gravar .theo/evolution_assessment.md (template da rubrica)
  │     Log: evolution_log.jsonl
  │     │
  │     ├─ Média ≥ 2.5?
  │     │   └─ YES → CONVERGED
  │     │       Update progress.md: status=CONVERGED
  │     │       Signal success to user
  │     │       EXIT LOOP
  │     │
  │     └─ Média < 2.5?
  │         └─ Continue to ITERATE
  │
  ├─ 6. ITERATE
  │     Identificar dimensões com score mais baixo
  │     ├─ Testability baixa? → Adicionar testes na próxima iteração
  │     ├─ Completeness baixa? → Tratar edge cases
  │     ├─ Pattern Fidelity baixa? → Re-ler referências (partial Research re-entry)
  │     ├─ Architectural Fit baixa? → Refatorar integração
  │     └─ Simplicity baixa? → Simplificar, remover abstrações
  │     Update progress.md com gaps
  │
  ├─ 7. GUARDRAIL CHECK
  │     ├─ iteration_count ≥ 15? → EVOLUTION_TIMEOUT: stop, log gaps
  │     ├─ consecutive_discards ≥ 5? → G11: re-evaluate strategy entirely
  │     ├─ attempt_count ≥ 3 for same idea? → G6: try different approach
  │     ├─ experiment_count ≥ 200? → BUDGET_EXCEEDED: stop
  │     └─ OK → continue loop (back to step 1)
  │
  └─ 8. STOP_IMMEDIATELY CHECK
        ├─ Harness SHA mismatch? → STOP
        ├─ API key patterns in staged files? → STOP
        ├─ tests_passed dropped >50%? → STOP
        ├─ disk < 1GB? → STOP
        ├─ About to modify referencias/? → STOP
        └─ OK → continue
```

**Invariantes:**
- Cada iteração produz exatamente 1 commit (keep) ou 0 commits (discard hygiene) ou 1 commit avaliado por SOTA (keep + assessment)
- Hygiene score nunca regride entre iterações mantidas
- SOTA assessment é registrado apenas para iterações que passaram o hygiene check
- Todo descarte é classificado com failure code
- Reverts usam SHA capturado antes do commit
- SOTA assessment cita evidência de referências (G18)

---

## 4. Failure Recovery Flow

Ações específicas por tipo de falha.

```
FAILURE DETECTED
  │
  ├─ COMPILE_ERROR
  │   attempt < 3?
  │   ├─ YES → Read error message. Fix. Retry.
  │   └─ NO  → Revert. Try different approach or different pattern.
  │
  ├─ TEST_REGRESSION (tests_failed > 0)
  │   └─ Revert immediately. Do NOT retry same approach.
  │      Analyze: did the change break existing behavior?
  │
  ├─ CLIPPY_REGRESSION
  │   └─ Read clippy message. Fix and re-commit.
  │
  ├─ UNWRAP_REGRESSION
  │   └─ Revert. Check diff for accidental .unwrap() additions.
  │
  ├─ SCORE_PLATEAU (hygiene score didn't change)
  │   └─ Expected during evolution. This is NOT a problem.
  │      Focus on SOTA rubric improvement instead.
  │      Only action if ALL dimensions also plateaued.
  │
  ├─ SCORE_DROP (hygiene score decreased)
  │   └─ Revert. Analyze which metric dropped.
  │
  ├─ EVAL_CRASH (eval produced no output)
  │   └─ Read last 50 lines of eval.log.
  │      Wait 30s, retry once. If still crashes, revert.
  │
  ├─ SOTA_REGRESSION (SOTA rubric dropped vs previous)
  │   └─ Analyze: which dimension dropped and why?
  │      Re-read references for that specific dimension.
  │      The hygiene-kept commit stays — SOTA regression doesn't trigger revert.
  │      But the next iteration should specifically address the gap.
  │
  ├─ REFERENCE_MISMATCH (pattern doesn't translate to Rust/theo)
  │   └─ Document why in evolution_research.md.
  │      Try different pattern from different reference repo.
  │      If all references fail for this aspect, note it as a known gap.
  │
  ├─ SCOPE_CREEP (> 200 lines or wrong subsystem)
  │   └─ Revert. Decompose into smaller changes.
  │      Each iteration = one logical change.
  │
  ├─ EVOLUTION_TIMEOUT (15 iterations without convergence)
  │   └─ Stop loop. Log final assessment with remaining gaps.
  │      Update progress.md. Wait for human guidance.
  │
  ├─ CONTEXT_EXHAUSTION (context window full)
  │   └─ Commit all progress. Update progress.md and assessment.
  │      Signal for fresh session. Next session resumes from assessment.
  │
  └─ BUDGET_EXCEEDED (200 experiments)
      └─ Stop loop. Log final state. Update progress.md.
```

---

## 5. Crate Work Order Flow

Ordem de trabalho por crate, baseada no grafo de dependências.

```
DEPENDENCY GRAPH (leaf-first = fewest dependents first):

Level 8 (leaves): theo-cli, theo-marklive
Level 7:          theo-application
Level 6:          theo-agent-runtime
Level 5:          theo-tooling, theo-infra-llm, theo-infra-auth
Level 4:          theo-engine-retrieval
Level 3:          theo-engine-graph
Level 2:          theo-engine-parser
Level 1:          theo-governance, theo-api-contracts
Level 0 (root):   theo-domain (CAUTION: rebuilds everything)

RULE: For hygiene work, start with leaves.
EXCEPTION: For evolution, start with the crate targeted by the prompt.
           Be aware of rebuild costs for Level 0-2 crates.
```

---

## Referências

- **Bootstrap sequence**: Anthropic (Young, 2025) — fixed orientation sequence per session
- **Research-first**: Karpathy autoresearch — analyze results before proposing mutations
- **Dual evaluation**: ProjDevBench (Lu et al., 2026) — execution + code review scoring
- **Failure taxonomy**: NLAHs (Pan et al., 2026) — named failure modes drive recovery
- **Leaf-first**: theo-architecture.md — minimize rebuild cascading
- **Evidence-grounded assessment**: VeRO (Ursekar et al., 2026) — per-sample scores with traces
