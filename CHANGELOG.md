# Changelog

Todas as mudanças notáveis no autoloop são documentadas aqui.
Formato: [Keep a Changelog](https://keepachangelog.com/) + [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Agentes autoloop integrados com agentes domain do theo-code — o evolution loop agora coordena duas frotas de agentes trabalhando em conjunto (#28)
- `chief-evolver.md` — Reescrito para delegar a agentes theo-code em cada fase: `graphctx-expert`/`retrieval-engineer` na pesquisa, `chief-architect` para validar plano, `code-reviewer` antes de commit, `arch-validator`+`test-runner` na higiene. Inclui subsystem-to-agent mapping table e protocolo de coordenação paralela (#29)
- `researcher.md` — Modelo de pesquisa de duas fontes: consulta agente domain primeiro (estado atual) + referências externas depois. Delta analysis (current vs SOTA) como output principal (#30)
- `hygiene-checker.md` — Verificação em 3 camadas: score (theo-evaluate.sh) + boundaries (`arch-validator`) + failure analysis (`test-runner`). Root cause analysis combinada de múltiplos agentes (#31)
- `quality-gate.md` — Avaliação multi-agente: incorpora feedback de `code-reviewer`, `arch-validator` e domain agents como evidência nas 5 dimensões. Novas anti-inflation rules baseadas em output de agentes (#32)
- `evolution-loop.md` — Adicionada seção AGENT COORDINATION com instruções de quando usar cada agente theo-code por fase (#33)
- `help.md` — Tabela de fases atualizada com agentes envolvidos. Nova seção "Theo-code Domain Agents" listando 9 agentes consultados e quando (#34)

### Added
- `reference-catalog.md` — Catálogo dos 8 repos de referência indexados por subsistema do theo-code, com key files e lookup table (#14)
- `sota-rubric.md` — Rubrica SOTA de 5 dimensões × 4 níveis (Pattern Fidelity, Architectural Fit, Completeness, Testability, Simplicity) com exemplos concretos e template de assessment (#15)
- Guardrails G16-G20: referências read-only, cap de 15 iterações por prompt, evidence-grounded assessment, hygiene floor absoluto, anti-astronautics (#16)
- Seção "SOTA Quality Rubric" em `metrics.md` definindo a relação entre hygiene score (piso) e SOTA rubric (métrica primária) (#17)
- Verificação de `referencias/` no `theo-init.sh` com contagem e listagem de repos (#18)
- Template de `evolution_prompt.md` criado automaticamente pelo `theo-init.sh` (#19)
- `evolution_log.jsonl` no `.gitignore` e inicializado pelo `theo-init.sh` (#20)

### Changed
- `theo-program.md` — Reescrito completamente: de hygiene loop (feature_list.json + score ratchet) para evolution loop (prompt → research referências → implement → hygiene check → SOTA evaluate → iterate até convergência). Novo bootstrap sequence com 10 passos. Reference Integration Protocol com lookup table. Evolution loop de 6 passos. SOTA rubric como métrica primária. 4 novos failure codes (SOTA_REGRESSION, REFERENCE_MISMATCH, SCOPE_CREEP, EVOLUTION_TIMEOUT). Branch naming de `autoresearch/*` para `evolution/*` (#21)
- `flows.md` — Reescrito: 5 fluxos antigos (Bootstrap, Experiment Loop, Phase Transition, Failure Recovery, Crate Work Order) substituídos por 5 novos fluxos (Session Bootstrap com evolution_prompt.md, Research Flow com protocolo de referências, Evolution Loop com dual evaluation, Failure Recovery expandido com novos failure codes, Crate Work Order mantido com exceção para evolution) (#22)
- `guardrails.md` — Adicionada Camada 4 (Evolution-Specific) com 5 novos guardrails mantendo todas as 3 camadas anteriores intactas (#23)
- `metrics.md` — Adicionada seção 4 "SOTA Quality Rubric" com definição das 5 dimensões, fórmula de convergência, relação com hygiene score, e notas sobre reliability da auto-avaliação (#24)
- `theo-init.sh` — Adicionada verificação de `referencias/`, criação de `evolution_prompt.md` template, `evolution_log.jsonl`, atualizado `.gitignore` com novos artifacts, messaging atualizado de "autoresearch" para "evolution loop" (#25)
- `roadmap.md` — Reescrito: de 6 fases fixas (STABILIZE→MAINTAIN) para modelo prompt-driven com ciclo de vida de prompts, tipos de prompt suportados, comparação hygiene vs evolution loop (#26)
- `README.md` — Reescrito: reflete o novo sistema de evolução com seções sobre SOTA rubric, reference repos, operator guide para evolution assessment, quick start atualizado (#27)

## [1.0.0] - 2026-04-17

### Added
- `guardrails.md` — 15 guardrails em 3 camadas: limites imutáveis, circuit breakers, observabilidade (#1)
- `metrics.md` — Métricas de produto (score dual-layer), processo (velocity, success rate) e harness (coverage) (#2)
- `flows.md` — 5 fluxos operacionais: bootstrap, experiment loop, phase transition, failure recovery, crate work order (#3)
- `roadmap.md` — Roadmap de 6 fases baseado em 9 fontes de pesquisa (#4)
- `CHANGELOG.md` — Registro de mudanças do projeto (#5)

### Changed
- `theo-evaluate.sh` — Adicionado `set -euo pipefail`, check de python3/cargo, trap para cleanup de tmpdir, SHA-256 self-check de integridade, tracking de crates que falharam na compilação para evitar testes em crates não compilados, validação de inputs antes do cálculo Python, cap de clippy ajustado de 200 para 600 (acima do baseline de 551), cap de doc_artifacts com min(5), grep de unwrap/dead_code expandido para incluir apps/, proteção contra contagem negativa de warnings (#6)
- `theo-init.sh` — Corrigido typo `clipy_warnings` → `clippy_warnings` no header do results.tsv, expandido header de 10 para 17 colunas, adicionado check de python3, adicionado experiment_traces.jsonl e progress.md ao .gitignore, adicionado inicialização de progress.md, adicionado geração de SHA-256 do eval harness, adicionado check de feature_list.json com warning, substituído `git checkout -b` por `git switch -c`, baseline log em mktemp em vez de /tmp fixo (#7)
- `theo-program.md` — Removidos paths absolutos hardcoded (/home/paulo/...), substituídos por variáveis `<AUTOLOOP_DIR>` e `<THEO_CODE_DIR>`. Substituído `git add -A` por staging explícito de paths permitidos. Substituído `git reset --hard HEAD~1` por SHA-anchored revert (`$BEFORE_SHA`). Adicionada seção STOP IMMEDIATELY com 7 exceções de segurança. Adicionado budget limit de 200 experimentos por sessão. Feature_list.json updates incluídos no mesmo commit do experimento (elimina invariante violado). Adicionada seção de trust boundary sobre source files. Corrigida contagem de crates (11 library + 2 app = 13 packages). Adicionada nota sobre clippy scoring e zona morta. Corrigido crate work order (Level 8 = leaves com menos dependentes). Referência a metrics.md como fonte canônica em vez de duplicar fórmulas (#8)
- `guardrails.md` — Adicionado status de enforcement honesto (parcial via chmod/SHA-256 em vez de "hardcoded"). Corrigido G2 para usar SHA-anchored revert. Corrigido G3 para incluir lista explícita de paths e exclusões completas. Corrigido G7 para refletir implementação real (timeout no eval harness). Adicionada exceção MAINTAIN para G9. Corrigido G11 com ação mais concreta. Corrigido G15 com budget numérico (200 experiments). Adicionado enforcement note por guardrail (#9)
- `roadmap.md` — Corrigido case mismatch CRÍTICO: `.theo/agents.md` → `.theo/AGENTS.md`, `.theo/rules.md` → `.theo/QUALITY_RULES.md`, `.theo/quality_score.md` → `.theo/QUALITY_SCORE.md` (9 pontos L2 perdidos silenciosamente). Corrigido impacto estimado de warnings (5.9 → ~4). Removida duplicação de baseline data (referencia metrics.md). Marcados items de Fase 0 como completos. Adicionado budget ao MAINTAIN (#10)
- `metrics.md` — Atualizado cap de clippy de 200 para 600 (elimina zona morta no baseline). Adicionado cap explícito min(5) em doc_artifacts. Adicionada seção "Notas sobre Measurement Bias" documentando viés em unwrap_count e structural tests. Designado como fonte canônica de fórmulas. Adicionada nota sobre mudança de baseline com novo cap (#11)
- `flows.md` — Corrigido crate work order: Level 0 é "root/most depended-on" (theo-domain), Level 8 é "leaf/no dependents" (theo-cli). Corrigido experiment loop para usar SHA-anchored reverts e staging explícito. Adicionada STOP_IMMEDIATELY check no loop. Adicionada POLISH exit condition no bootstrap flow. Corrigida invariante de single-commit. Adicionado budget check. Adicionada recovery para progress.md corrompido. Adicionada exceção MAINTAIN no G9. Adicionado budget exceeded no failure recovery (#12)
- `README.md` — Adicionada seção Prerequisites (Rust, Python 3.6+, Git, feature_list.json). Adicionado Operator Guide com exemplos de como ler results.tsv, experiment_traces.jsonl, progress.md. Adicionada seção Recovery Procedures (branch unknown state, corrupt progress.md, fresh start). Corrigida contagem de crates. Atualizado design principles com SHA-256 verification, explicit staging, budget enforcement. Adicionada referência a theo-evaluate.sha256 (#13)
