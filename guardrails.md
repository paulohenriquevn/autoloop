# Autoloop Guardrails

Proteção em 3 camadas para o agente autônomo. Baseado em defense-in-depth (OpenDev), feedforward/feedback (Böckeler/Fowler), e budget enforcement (VeRO).

---

## Camada 1 — Limites Imutáveis

Regras hardcoded no harness e no program. Nunca são alteradas durante experimentos.

### G1: Harness Imutável
`theo-evaluate.sh` é o ground truth. O agente **nunca** modifica este arquivo. Qualquer mudança no score vem exclusivamente de mudanças no código do theo-code.

### G2: Score Monotônico
Uma mudança só é mantida se `score_after > score_before`. Score igual ou menor = revert imediato via `git reset --hard HEAD~1`.

### G3: Scope de Arquivos

**Pode modificar:**
- `crates/*/src/**/*.rs`
- `crates/*/tests/**/*.rs` (criar novos, nunca deletar existentes)
- `apps/theo-cli/src/**/*.rs`
- `apps/theo-marklive/src/**/*.rs`
- `clippy.toml` (criar)
- `.theo/AGENTS.md`, `.theo/QUALITY_RULES.md`, `.theo/QUALITY_SCORE.md` (criar)

**Não pode modificar:**
- `theo-evaluate.sh`
- `apps/theo-benchmark/**`
- `apps/theo-desktop/**`
- `.claude/CLAUDE.md`
- `Cargo.toml` (workspace dependencies)

### G4: Sem Dependências Novas
Proibido adicionar crates a `[workspace.dependencies]`. Proibido adicionar novos workspace members. O agente trabalha exclusivamente com o que já existe.

### G5: Sem Deletar Testes
Funções `#[test]` existentes são intocáveis. O agente pode adicionar testes, nunca remover.

---

## Camada 2 — Circuit Breakers

Regras dinâmicas que previnem loops destrutivos e desperdício de recursos.

### G6: Max 3 Tentativas por Ideia
Se uma mudança falha 3 vezes consecutivas (compile error, test regression, ou score drop), o agente **deve** abandonar essa abordagem e pular para a próxima feature no `feature_list.json`.

### G7: Budget de Compilação
Se `cargo test -p <crate> --no-run` leva mais de 5 minutos para um crate individual ou mais de 10 minutos para o workspace completo, o experimento é abortado e revertido.

### G8: Zero Tolerância a Regressão de Testes
Se `tests_failed > 0` no eval output, revert imediato. Sem exceção. Sem retry.

### G9: Detecção de Plateau
Se 3 experimentos consecutivos resultam no **mesmo score** (delta = 0), o agente deve:
1. Trocar de crate/módulo alvo
2. Se já trocou, trocar de fase (ex: de FORTIFY para POLISH)
3. Se já esgotou, re-ler `feature_list.json` e `theo-architecture.md`

### G10: Limite de Escopo por Experimento
Cada experimento deve ser **focado**: tipicamente 1-50 linhas alteradas, máximo absoluto 200 linhas. Se a mudança é maior, deve ser quebrada em múltiplos experimentos sequenciais.

### G11: Detecção de Loop Infinito
Se o agente faz mais de 5 reverts consecutivos sem nenhum keep, deve pausar e:
1. Re-ler a arquitetura (`theo-architecture.md`)
2. Re-avaliar qual fase está
3. Escolher uma abordagem fundamentalmente diferente

---

## Camada 3 — Observabilidade

Mecanismos que tornam o comportamento do agente auditável e diagnosticável.

### G12: Logging Obrigatório
Todo experimento, sem exceção, deve ser logado em `results.tsv` com:
- commit hash
- score antes/depois
- status (keep/discard)
- descrição do que foi tentado

### G13: Failure Taxonomy
Cada descarte deve ser classificado com exatamente uma das categorias:

| Código | Significado | Ação |
|---|---|---|
| `COMPILE_ERROR` | Código não compila | Fix ou revert. Max 3 tentativas. |
| `TEST_REGRESSION` | Testes passavam, agora falham | Revert imediato. Abordagem diferente. |
| `CLIPPY_REGRESSION` | Mais clippy warnings que antes | Geralmente fix fácil. Ler mensagem. |
| `UNWRAP_REGRESSION` | Adicionou unwrap() acidentalmente | Revert. Verificar mudança. |
| `SCORE_PLATEAU` | Score não mudou | Trocar feature ou crate. |
| `SCORE_DROP` | Score caiu | Revert. Analisar o que piorou. |
| `EVAL_CRASH` | Avaliação crashou | Ler `eval.log`. Geralmente timeout. |
| `CONTEXT_EXHAUSTION` | Context window esgotado | Commitar progresso, nova sessão. |
| `BUDGET_EXCEEDED` | Tempo ou tentativas esgotados | Parar. Logar estado final. |

### G14: Structured Tracing
Cada experimento gera uma entrada JSONL em `experiment_traces.jsonl`:
```json
{
  "timestamp": "2026-04-17T10:30:00Z",
  "commit": "a1b2c3d",
  "phase": "STABILIZE",
  "feature_id": "fix-cargo-warnings",
  "score_before": 53.830,
  "score_after": 55.100,
  "delta": 1.270,
  "status": "keep",
  "failure_reason": null,
  "files_changed": 3,
  "lines_changed": 12,
  "duration_secs": 240,
  "crate": "theo-engine-retrieval"
}
```

### G15: Alertas de Plateau
Se o score não melhora por mais de 5 experimentos consecutivos (incluindo keeps com delta ≈ 0), o agente deve:
1. Loggar um alerta explícito no `progress.md`
2. Re-avaliar a estratégia de fase
3. Considerar features de maior impacto

---

## Referências

- **Defense-in-depth**: OpenDev (Bui, 2026) — 5 camadas independentes de segurança
- **Feedforward/feedback**: Böckeler (2026) — guides antecipam, sensors corrigem
- **Budget enforcement**: VeRO (Ursekar et al., 2026) — tracking de evaluation calls
- **Failure taxonomy**: NLAHs (Pan et al., 2026) — named failure modes drive recovery
- **Circuit breakers**: theo-code PilotLoop — 3 loops sem progresso = circuit break
