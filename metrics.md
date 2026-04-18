# Autoloop Metrics

Definição completa de todas as métricas do sistema. Divididas em 3 categorias: produto (score), processo (eficiência do agente), e harness (qualidade dos controles).

**Fonte canônica:** Este documento é a referência autoritativa para todas as fórmulas de score. A implementação está em `theo-evaluate.sh`. Outros documentos devem referenciar este em vez de duplicar as fórmulas.

---

## 1. Métricas de Produto (Score Dual-Layer)

Ground truth. Calculadas por `theo-evaluate.sh`. Imutáveis.

### Layer 1 — Workspace Hygiene (0-100)

| Métrica | Peso | Fórmula | Alvo |
|---|---|---|---|
| Compile success rate | 40 pts | `40 × (crates_ok / 13)` | 13/13 |
| Test pass rate | 40 pts | `40 × (passed / total)` | 100% |
| Test count bonus | 10 pts | `10 × min(1, test_count / 2500)` | ≥2500 |
| Warning penalty | 10 pts | `10 × max(0, 1 - warnings / 100)` | 0 warnings |

### Layer 2 — Harness Maturity (0-100)

| Métrica | Peso | Fórmula | Cap | Alvo |
|---|---|---|---|---|
| Clippy cleanliness | 20 pts | `20 × max(0, 1 - clippy / 600)` | 600 | 0 warnings |
| Unwrap density | 20 pts | `20 × max(0, 1 - unwraps / 1500)` | 1500 | ≤300 |
| Structural tests | 15 pts | `15 × min(1, structural / 30)` | 30 | ≥30 |
| Doc artifacts | 15 pts | `3 × min(5, artifact_count)` | 5 | 5/5 |
| Dead code hygiene | 15 pts | `15 × max(0, 1 - dead_code / 20)` | 20 | 0 |
| Boundary tests | 15 pts | `15 × min(1, boundary / 15)` | 15 | ≥15 |

### Score Combinado
```
score = (L1 + L2) / 2
```

### Notas sobre Measurement Bias

**Unwrap count:** A contagem inclui `crates/*/src/` e `apps/theo-cli/src/` e `apps/theo-marklive/src/`. Exclui arquivos em `/tests/` e `_test.rs`. Pode incluir falsos positivos de `.unwrap()` dentro de módulos `#[cfg(test)]` inline em arquivos de produção e em comentários/doc-comments. O alvo de ≤300 considera essa margem.

**Clippy warnings:** O cap é 600 (acima do baseline de ~551). Isso garante que cada fix de clippy contribui para o score desde o início. O cap anterior de 200 criava uma zona morta onde fixes não geravam pontos.

**Structural/boundary tests:** Contam anotações `#[test]` nos arquivos específicos. Os testes devem ter assertions reais — stubs vazios violam o espírito da métrica.

---

## 2. Métricas de Processo

Medem a eficiência e eficácia do agente autônomo. Calculadas a partir de `results.tsv` e `experiment_traces.jsonl`.

### Score Velocity
**O que mede**: Velocidade de melhoria do score.
```
score_velocity = Δscore / Δhours
```
**Interpretação**: >1 pt/hora é bom na fase STABILIZE. >0.5 pt/hora é bom na fase FORTIFY. <0.1 pt/hora indica plateau.

### Experiment Success Rate
**O que mede**: Proporção de experimentos mantidos vs descartados.
```
success_rate = keeps / total_experiments
```
**Interpretação**: 30-50% é saudável. <20% indica que o agente está escolhendo mal. >70% pode indicar mudanças triviais demais.

### Phase Completion Time
**O que mede**: Quanto tempo cada fase levou para completar.
```
phase_time = timestamp_exit - timestamp_enter
```
**Baseline esperado**:
- STABILIZE: 1-2 horas
- SCAFFOLD: 1-2 horas
- FORTIFY: 4-8 horas
- POLISH: contínuo

### Failure Distribution
**O que mede**: Quais tipos de falha dominam.
```
failure_dist = count_by_category(failure_reason) / total_discards
```
**Interpretação**: Se >50% é `COMPILE_ERROR`, o agente precisa de melhor entendimento do código. Se >50% é `SCORE_PLATEAU`, as oportunidades fáceis acabaram.

### Lines Per Point
**O que mede**: Eficiência de código — quanto código é necessário para cada ponto de score.
```
lines_per_point = Σ lines_changed / Σ score_delta  (apenas keeps)
```
**Interpretação**: Valores baixos indicam mudanças de alto impacto (ex: criar doc artifacts). Valores altos indicam trabalho pesado (ex: unwrap removal).

### Revert Streak
**O que mede**: Maior sequência consecutiva de descarte.
```
revert_streak = max(consecutive_discards)
```
**Interpretação**: >5 indica problemas. Guardrail G11 deve ativar.

---

## 3. Métricas de Harness

Medem a qualidade e cobertura dos controles de qualidade do próprio theo-code.

### Structural Test Coverage
**O que mede**: Proporção de invariantes arquiteturais que têm testes.
```
structural_coverage = structural_tests / target_structural_tests (30)
```
**Invariantes a cobrir**:
- Sem `println!` em código de lib
- Limites de tamanho de arquivo (<1000 linhas)
- Sem dependências circulares
- Doc comments em tipos públicos
- Sem `std::process::exit` fora do main
- Sem `unsafe` sem justificativa

### Boundary Test Coverage
**O que mede**: Proporção de fronteiras entre crates com testes.
```
boundary_coverage = boundary_tests / target_boundary_tests (15)
```
**Fronteiras a cobrir**:
- theo-domain não depende de nenhum outro crate
- theo-governance não depende de engines
- apps/ não importam de apps/
- theo-benchmark é isolado
- Engines não importam de runtime

### Doc Artifact Freshness
**O que mede**: Se os 5 doc artifacts existem e estão atualizados.
```
freshness = artifacts_present / 5
```
**Artifacts**: clippy.toml, AGENTS.md, QUALITY_RULES.md, QUALITY_SCORE.md, structural_hygiene.rs

---

## Baseline (2026-04-17)

| Métrica | Valor |
|---|---|
| score | 53.830 |
| L1 | 94.100 |
| L2 | 13.560 |
| compile_crates | 13/13 |
| tests_passed | 2561 |
| tests_failed | 0 |
| cargo_warnings | 59 |
| clippy_warnings | 551 |
| unwrap_count | 1308 |
| structural_tests | 0 |
| boundary_tests | 5 |
| doc_artifacts | 0/5 |
| dead_code_attrs | 12 |

**Nota:** O baseline acima foi coletado com o cap de clippy antigo (200). Com o cap atualizado (600), o L2 baseline para clippy seria `20 × max(0, 1 - 551/600) = 1.63` em vez de 0.

---

## 4. SOTA Quality Rubric (Métrica Primária do Evolution Loop)

No evolution loop, o score dual-layer (L1+L2) funciona como **piso de hygiene**. A métrica principal é a SOTA Quality Rubric — uma auto-avaliação do agente em 5 dimensões.

Ver `sota-rubric.md` para a rubrica completa com exemplos e template.

### Dimensões

| Dimensão | O que mede | Score |
|---|---|:---:|
| Pattern Fidelity | Fidelidade ao padrão SOTA das referências | 0-3 |
| Architectural Fit | Encaixe na arquitetura do theo-code | 0-3 |
| Completeness | Completude para produção (edge cases, errors) | 0-3 |
| Testability | Qualidade e cobertura dos testes | 0-3 |
| Simplicity | Implementação mínima e focada | 0-3 |

### Convergência
```
sota_average = (pattern_fidelity + architectural_fit + completeness + testability + simplicity) / 5
converged = sota_average >= 2.5
```

### Relação com Hygiene Score
```
1. Agente implementa mudança
2. Run theo-evaluate.sh → hygiene score
3. Se score caiu → revert (G19 — piso absoluto)
4. Se score mantido/subiu → SOTA rubric assessment
5. Se SOTA média ≥ 2.5 → CONVERGED
6. Se SOTA média < 2.5 → ITERATE (max 15 iterações — G17)
```

O hygiene score e o SOTA rubric medem coisas diferentes e complementares:
- **Hygiene** = "o código compila, passa testes, está limpo?" (objetivo, calculado por script)
- **SOTA** = "a implementação segue padrões de ponta das referências?" (subjetivo mas evidence-grounded via G18)

### Notas sobre Reliability da Auto-Avaliação

A SOTA rubric é inerentemente subjetiva — o agente julga seu próprio trabalho. Mitigações:

1. **G18 (Evidence-Grounded):** Toda pontuação deve citar referência específica. Previne inflação sem base.
2. **Hygiene floor (G19):** Mesmo com SOTA=3 em tudo, se hygiene caiu, reverte. Previne "parece bom mas quebrou algo".
3. **Audit trail:** `evolution_assessment.md` e `evolution_log.jsonl` são auditáveis pelo humano após a sessão.
4. **Convergence threshold (2.5):** Exige pelo menos algumas dimensões em SOTA (3), não aceita tudo "Good" (2).

---

## Referências

- **Dual evaluation**: ProjDevBench (Lu et al., 2026) — execution + code review scoring
- **Structured tracing**: VeRO (Ursekar et al., 2026) — per-sample scores, errors, traces
- **Harness quality metrics**: Böckeler (2026) — "if sensors never fire, is that high quality or inadequate detection?"
- **Score formula**: theo-evaluate.sh — immutable ground truth
