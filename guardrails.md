# Autoloop Guardrails

Proteção em 3 camadas para o agente autônomo. Baseado em defense-in-depth (OpenDev), feedforward/feedback (Böckeler/Fowler), e budget enforcement (VeRO).

**Enforcement status:** A Camada 1 tem enforcement parcial via filesystem permissions (chmod 444 no harness) e SHA-256 self-check. Camadas 2 e 3 dependem de compliance do agente com as instruções. `theo-init.sh` configura a verificação de integridade automaticamente.

---

## Camada 1 — Limites Imutáveis

Regras que protegem a integridade do ground truth. Enforcement via file permissions + SHA-256 check.

### G1: Harness Imutável
`theo-evaluate.sh` é o ground truth. O agente **nunca** modifica este arquivo.
**Enforcement:** `chmod 444` aplicado após setup. SHA-256 verificado automaticamente no início de cada eval run. Se o hash não bater, a avaliação aborta com erro.

### G2: Score Monotônico
Uma mudança só é mantida se `score_after > score_before`. Score igual ou menor = revert imediato via `git reset --hard "$BEFORE_SHA"` (SHA capturado antes do commit, não HEAD~1).

### G3: Scope de Arquivos

**Pode modificar:**
- `crates/*/src/**/*.rs`
- `crates/*/tests/**/*.rs` (criar novos, nunca deletar existentes)
- `apps/theo-cli/src/**/*.rs`
- `apps/theo-marklive/src/**/*.rs`
- `clippy.toml` (criar)
- `.theo/AGENTS.md`, `.theo/QUALITY_RULES.md`, `.theo/QUALITY_SCORE.md` (criar)
- `.theo/feature_list.json` (atualizar status)

**Não pode modificar:**
- `theo-evaluate.sh`
- `apps/theo-benchmark/**`
- `apps/theo-desktop/**`
- `.claude/CLAUDE.md`
- `Cargo.toml` (workspace dependencies)

**Enforcement:** `git add` no experiment loop usa lista explícita de paths permitidos (não `git add -A`).

### G4: Sem Dependências Novas
Proibido adicionar crates a `[workspace.dependencies]`. Proibido adicionar novos workspace members. O agente trabalha exclusivamente com o que já existe.

### G5: Sem Deletar Testes
Funções `#[test]` existentes são intocáveis. O agente pode adicionar testes, nunca remover.

---

## Camada 2 — Circuit Breakers

Regras dinâmicas que previnem loops destrutivos e desperdício de recursos. Enforcement via instruções no `theo-program.md`.

### G6: Max 3 Tentativas por Ideia
Se uma mudança falha 3 vezes consecutivas (compile error, test regression, ou score drop), o agente **deve** abandonar essa abordagem e pular para a próxima feature no `feature_list.json`.

### G7: Budget de Compilação
Se `cargo test -p <crate> --no-run` leva mais de 5 minutos (PER_CRATE_TIMEOUT=300 em `theo-evaluate.sh`), o crate é marcado como falha de compilação e pulado na fase de testes.
**Enforcement:** `timeout` command no eval harness.

### G8: Zero Tolerância a Regressão de Testes
Se `tests_failed > 0` no eval output, revert imediato. Sem exceção. Sem retry.

### G9: Detecção de Plateau
Se 3 experimentos consecutivos resultam no **mesmo score** (delta = 0), o agente deve:
1. Trocar de crate/módulo alvo
2. Se já trocou, trocar de fase (ex: de FORTIFY para POLISH)
3. Se já esgotou, re-ler `feature_list.json` e `theo-architecture.md`

**Exceção MAINTAIN:** Na fase MAINTAIN, plateau é esperado. G9 só ativa se há features pendentes em `feature_list.json`.

### G10: Limite de Escopo por Experimento
Cada experimento deve ser **focado**: tipicamente 1-50 linhas alteradas, máximo absoluto 200 linhas. Se a mudança é maior, deve ser quebrada em múltiplos experimentos sequenciais.

### G11: Detecção de Loop Infinito
Se o agente faz mais de 5 reverts consecutivos sem nenhum keep, deve pausar e:
1. Re-ler a arquitetura (`theo-architecture.md`)
2. Re-avaliar qual fase está
3. Escolher uma abordagem fundamentalmente diferente
4. Se o padrão persistir após a pausa, considerar parar o loop

---

## Camada 3 — Observabilidade

Mecanismos que tornam o comportamento do agente auditável e diagnosticável.

### G12: Logging Obrigatório
Todo experimento, sem exceção, deve ser logado em `results.tsv` com todos os campos do header (17 colunas).

### G13: Failure Taxonomy
Cada descarte deve ser classificado com exatamente um código de falha (ver tabela em `theo-program.md`).

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

### G15: Budget Enforcement
O agente deve parar após 200 experimentos por sessão ou quando o operador interrompe. Se o score não melhora por mais de 10 experimentos consecutivos na fase MAINTAIN, o agente deve logar um alerta no `progress.md` e considerar parar.

---

## Referências

- **Defense-in-depth**: OpenDev (Bui, 2026) — 5 camadas independentes de segurança
- **Feedforward/feedback**: Böckeler (2026) — guides antecipam, sensors corrigem
- **Budget enforcement**: VeRO (Ursekar et al., 2026) — tracking de evaluation calls
- **Failure taxonomy**: NLAHs (Pan et al., 2026) — named failure modes drive recovery
- **Circuit breakers**: theo-code PilotLoop — 3 loops sem progresso = circuit break
