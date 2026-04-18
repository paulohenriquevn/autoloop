# Autoloop Roadmap

Roadmap baseado em evidências de 9 fontes de pesquisa (papers, artigos técnicos e docs internos). Cada fase tem fundamentação empírica.

---

## Estado Atual (Baseline 2026-04-17)

Veja `metrics.md` para definições completas das fórmulas e baseline.

```
score:           53.830
L1 (hygiene):    94.100 / 100
L2 (maturity):   13.560 / 100
headroom:        46.170 pts
```

---

## Fase 0: Infraestrutura do Autoloop

**Status**: Completa
**Evidência**: OpenAI — "encode golden principles directly into the repository"

### Deliverables
- [x] `guardrails.md` — 15 guardrails em 3 camadas
- [x] `metrics.md` — Métricas de produto, processo e harness
- [x] `flows.md` — 5 fluxos operacionais
- [x] `roadmap.md` — Este documento
- [x] `theo-program.md` — Refinado com bootstrap sequence, structured tracing, failure taxonomy
- [x] `CHANGELOG.md` — Registro de mudanças

---

## Fase 1: STABILIZE

**Condição de entrada**: L1 < 95 (atual: 94.1)
**Condição de saída**: L1 ≥ 95
**Score estimado ao final**: ~56 pts (+2)
**Evidência**: Böckeler — "keep quality left, find issues as early as possible"

### Tarefas

| # | Tarefa | Feature ID | Impacto L1 | Esforço |
|---|---|---|---|---|
| 1 | Fix 59 cargo warnings | `fix-cargo-warnings` | ~+4 pts | Fácil |
| 2 | Adicionar testes a api-contracts | `add-api-contracts-tests` | +0.04 pts | Fácil |
| 3 | Adicionar testes a governance | `add-governance-tests` | +0.08 pts | Fácil |
| 4 | Adicionar testes a engine-graph | `add-graph-engine-tests` | +0.04 pts | Fácil |

### Estratégia
- Warnings: agrupar por tipo (unused imports, unused variables, unused mut, dead code)
- Fazer batch por crate, leaf-first
- Cada commit = 1 crate's warnings fixed

---

## Fase 2: SCAFFOLD

**Condição de entrada**: doc_artifacts < 5/5
**Condição de saída**: doc_artifacts = 5/5
**Score estimado ao final**: ~63 pts (+7)
**Evidência**: OpenAI — "agents.md as table of contents, not encyclopedia"; "quality document grades each domain"

### Tarefas

| # | Artifact | Feature ID | Impacto L2 | Detalhes |
|---|---|---|---|---|
| 1 | `clippy.toml` | `create-clippy-toml` | +3.0 pts | Thresholds: too-many-arguments=10, type-complexity=300 |
| 2 | `.theo/AGENTS.md` | `create-agents-md` | +3.0 pts | Mapa ~100 linhas. Crate→responsabilidade, como testar, o que não tocar |
| 3 | `.theo/QUALITY_RULES.md` | `create-quality-rules-md` | +3.0 pts | Regras mecânicas: no unwrap, no dead_code, clippy clean |
| 4 | `.theo/QUALITY_SCORE.md` | `create-quality-score-md` | +3.0 pts | Dashboard per-crate com métricas atuais |
| 5 | `structural_hygiene.rs` | `create-structural-hygiene-tests` | +3.0 pts | 10+ testes: no println, file size, no circular deps |

### Design Guidelines (por artifact)

**AGENTS.md** — Mapa, não manual. Inspirado no artigo OpenAI:
- Listar todos os 13 crates com responsabilidade em 1 linha
- Indicar como testar cada um (`cargo test -p <name>`)
- Indicar quais crates não tocar (benchmark, desktop)
- Links para docs mais profundos

**QUALITY_RULES.md** — Golden principles codificadas. Inspirado no artigo OpenAI:
- Cada regra é mecânica e verificável
- Formato: Regra → Como verificar → O que fazer se violada
- Exemplos: "no unwrap() in production" → `grep -r '.unwrap()' crates/*/src/` → "use ? or match"

**QUALITY_SCORE.md** — Dashboard vivo. Inspirado no artigo OpenAI:
- Tabela per-crate: compiles, tests, warnings, clippy, unwraps
- Atualizado pelo agente a cada fase completa
- Grades: A (limpo), B (minor issues), C (needs work), D (failing)

**structural_hygiene.rs** — Testes computacionais. Inspirado em Böckeler:
- Cada teste é um "sensor" que detecta drift
- Testes devem ler o filesystem e verificar invariantes
- Exemplos: nenhum arquivo .rs > 1000 linhas, nenhum `println!` em libs

---

## Fase 3: FORTIFY

**Condição de entrada**: L2 < 60
**Condição de saída**: L2 ≥ 60
**Score estimado ao final**: ~75 pts (+12)
**Evidência**: OpenAI — "structural tests and custom linters"; Böckeler — "computational sensors cheap enough to run on every change"

### Tarefas (por prioridade)

| # | Tarefa | Feature ID | Impacto L2 | Estratégia |
|---|---|---|---|---|
| 1 | Boundary tests 5→15 | `expand-boundary-tests` | +10.0 pts | Adicionar: circular deps, benchmark isolation, engine boundaries |
| 2 | Structural tests 10→30 | `expand-structural-tests` | +10.0 pts | File size, unwrap-free zones, doc comments, no process::exit |
| 3 | Clippy leaf crates | `clippy-fix-leaf-crates` | +variável | theo-cli, theo-marklive, then inward |
| 4 | Clippy engines | `clippy-fix-engines` | +variável | parser, graph, retrieval |
| 5 | Clippy runtime/infra | `clippy-fix-runtime-infra` | +variável | agent-runtime, infra-llm, tooling |
| 6 | Unwrap leaf crates | `unwrap-removal-leaf-crates` | +variável | ? operator, match, explicit errors |
| 7 | Unwrap engines | `unwrap-removal-engines` | +variável | Hot paths first |
| 8 | Dead code removal | `dead-code-removal` | +6.0 pts | Remove #[allow(dead_code)], use or delete |

### Regras Críticas
- **Clippy**: Corrigir warnings reais. Nunca adicionar `#[allow(clippy::...)]` para suprimir.
- **Unwrap**: Trabalhar crate por crate. Cada experimento = 1 crate. Nunca tentar todos de uma vez.
- **Dead code**: Ou usar o código ou deletar. Não manter `#[allow(dead_code)]`.

---

## Fase 4: POLISH

**Condição de entrada**: L2 ≥ 60, score ainda melhorando
**Condição de saída**: 5+ experimentos sem melhoria
**Score estimado ao final**: ~85 pts (+10)
**Evidência**: VeRO — "optimization headroom inversely correlates with agent complexity"

### Tarefas
1. Unwrap removal nos crates mais complexos (agent-runtime, application, CLI)
2. Testes adicionais em crates com <50 testes
3. Clippy fixes nos crates com mais warnings
4. Refinamento dos doc artifacts baseado no estado real
5. Combinar ideias de experimentos que ficaram "near-miss"

---

## Fase 5: MAINTAIN

**Condição de entrada**: Score parou de melhorar
**Condição de saída**: Human interruption ou budget exceeded (200 experiments)
**Evidência**: OpenAI — "technical debt is like a high-interest loan"

### Tarefas Cíclicas
1. Garbage collection: atualizar QUALITY_SCORE.md, limpar progress.md
2. Scan por novos patterns problemáticos (novos unwraps, novos warnings)
3. Re-ler feature_list.json para features não completadas
4. Re-ler theo-architecture.md para novas oportunidades
5. Manter score estável — qualquer regressão é bug priority 0

---

## Score Projection

```
Fase        Score Est.  L1 Est.   L2 Est.   Headroom
─────────   ─────────  ────────  ────────   ────────
Baseline    53.8       94.1      13.6       46.2
STABILIZE   56.0       96.0      16.0       44.0
SCAFFOLD    63.0       96.0      30.0       37.0
FORTIFY     75.0       97.0      53.0       25.0
POLISH      85.0       98.0      72.0       15.0
MAINTAIN    88.0+      99.0+     77.0+      12.0
```

---

## Referências

| Fonte | O que fundamenta |
|---|---|
| Karpathy autoresearch | Keep/discard pattern, monotonic improvement |
| Anthropic (Young, 2025) | Feature list JSON, progress file, bootstrap sequence |
| Böckeler/Fowler (2026) | Feedforward guides, feedback sensors, keep quality left |
| OpenAI (Lopopolo, 2026) | agents.md as map, repo as system of record, garbage collection |
| VeRO (Ursekar et al., 2026) | Versioned eval, budget enforcement, structured tracing |
| OpenDev (Bui, 2026) | Defense-in-depth, context engineering, system reminders |
| NLAHs (Pan et al., 2026) | Contracts, failure taxonomy, stage structure |
| ProjDevBench (Lu et al., 2026) | Dual evaluation, specification compliance |
| llvm-autofix (Zheng et al., 2026) | Setup→Reason→Generate→Validate stages |
