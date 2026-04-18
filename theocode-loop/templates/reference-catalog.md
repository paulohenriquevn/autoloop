# Reference Catalog

Catálogo dos repos de referência em `<THEO_CODE_DIR>/referencias/`. Usado pelo agente para pesquisar padrões SOTA durante o evolution loop.

**Regra:** Referências são **read-only**. O agente lê para extrair padrões, nunca modifica.

---

## Lookup por Subsistema

Dado um prompt de evolução, o agente identifica o subsistema alvo e consulta os repos relevantes:

| Subsistema do theo-code | Referências Primárias | Referências Secundárias |
|---|---|---|
| Context manager, assembly, budget | opendev, qmd | llm-wiki-compiler, pi-mono |
| Retrieval, search, ranking, HyDE | qmd, rippletide | opendev |
| Agent loop, pilot, convergence | opendev, Archon | pi-mono |
| Tool system, registry, MCP | opencode, rippletide | opendev |
| LLM providers, streaming, routing | pi-mono, opendev | Archon, llm-wiki-compiler |
| Governance, sandbox, safety | rippletide, opendev | opencode, Archon |
| Code graph, parsing, analysis | rippletide, llm-wiki-compiler | qmd |
| Padrões gerais de harness | awesome-harness-engineering | — |

**Protocolo de consulta:**
1. Identificar subsistema alvo no prompt de evolução
2. Consultar no máximo 3 repos (primários primeiro)
3. Ler no máximo 5 arquivos por repo (key files listados abaixo)
4. Extrair 3-5 padrões concretos aplicáveis

---

## Repos de Referência

### 1. Archon

**O que faz:** Workflow engine para AI coding — define processos de desenvolvimento como YAML workflows executados deterministicamente.

**Stack:** TypeScript (Bun), monorepo

**Padrões-chave para theo-code:**
- YAML-defined workflows (plan → implement → validate → review)
- Isolamento via git worktrees por workflow
- Context freshness: contexto limpo por fase, evita drift
- Model routing: diferentes modelos por estágio do workflow
- Env leak scanner: prevenção de vazamento de credenciais

**Arquivos-chave:**
- `packages/core/src/orchestrator/orchestrator.ts` — Loop de orquestração principal
- `packages/core/src/orchestrator/prompt-builder.ts` — Composição de contexto e prompts
- `packages/core/src/clients/claude.ts` — Integração com LLM provider
- `packages/core/src/utils/env-leak-scanner.ts` — Segurança: scan de credenciais
- `packages/isolation/` — Sandboxing e isolamento de processos

**Quando consultar:** Prompts sobre agent loop, workflows estruturados, model routing, isolamento.

---

### 2. OpenDev

**O que faz:** Sistema compound AI em Rust com fleet de agentes. Cada workflow slot (Normal, Thinking, Compact, Self-Critique, VLM) independente.

**Stack:** Rust (edition 2024), workspace com 21 crates

**Padrões-chave para theo-code:**
- ReAct loop com fases de thinking/critique separadas
- Context compaction em estágios progressivos
- Attachments system (memory, git status, plan mode como contexto modular)
- Agent fleet: múltiplos sub-agentes concorrentes com isolamento
- Compound AI: modelos diferentes para execução, raciocínio, crítica, visão

**Arquivos-chave:**
- `crates/opendev-agents/src/react_loop/mod.rs` — ReAct loop com thinking/critique
- `crates/opendev-agents/src/attachments/mod.rs` — Sistema de attachments modulares
- `crates/opendev-context/src/lib.rs` — Compaction em estágios e validação de mensagens
- `crates/opendev-sandbox/src/lib.rs` — Sandbox runtime com governance
- `crates/opendev-tools-core/src/lib.rs` — Registry e dispatch de tools

**Quando consultar:** Prompts sobre agent loop, context management, compaction, sandbox, tool system. **Referência primária para padrões Rust** (mesma linguagem que theo-code).

---

### 3. OpenCode

**O que faz:** Agente de código open-source com suporte multi-plataforma (CLI, desktop, web). Expõe SDK para integração.

**Stack:** TypeScript (Bun), monorepo com 20+ packages

**Padrões-chave para theo-code:**
- Access Control Plane (ACP): governance no nível do agente
- LSP integration para code intelligence
- MCP integration para exposição de tools
- Plugin/extension system para comportamento domain-specific
- Workspace e session management

**Arquivos-chave:**
- `packages/opencode/src/agent/agent.ts` — Orquestração do agente
- `packages/opencode/src/acp/agent.ts` — Access Control Plane (governance)
- `packages/opencode/src/control-plane/workspace.ts` — Workspace e session management
- `packages/opencode/src/lsp/server.ts` — LSP integration para code understanding
- `packages/opencode/src/mcp/index.ts` — MCP integration

**Quando consultar:** Prompts sobre tool system, MCP, governance, plugin system, LSP.

---

### 4. Rippletide

**O que faz:** Authority layer para agentes AI — valida, restringe e bloqueia ações antes de impactar sistemas. Context graph persistente entre sessões.

**Stack:** Rust + TypeScript, design dual-module

**Padrões-chave para theo-code:**
- Context graph persistente: grafo de conhecimento entre sessões
- Agent evaluation CLI: auto-geração de casos de teste
- Hallucination detection: fact-checking como camada de harness
- Corpus rules: regras de governança declarativas
- Planner: decomposição de tarefas e planejamento

**Arquivos-chave:**
- `context-graph/src/main.rs` — Construção de context graph, AST analysis, indexação
- `context-graph/src/planner.rs` — Planejamento e decomposição de tarefas
- `context-graph/src/corpus_rules.json` — Regras de governança declarativas
- `agent-evaluation/src/api/evaluation.ts` — Framework de avaliação de agentes
- `agent-evaluation/src/api/llm.ts` — Bridging com LLM providers

**Quando consultar:** Prompts sobre code graph, governance, avaliação, retrieval, context persistente.

---

### 5. Pi-Mono

**O que faz:** Monorepo de ferramentas para agentes AI — API multi-provider, agent runtime, coding agent CLI, integração Slack.

**Stack:** TypeScript (Node.js), monorepo com 7 packages

**Padrões-chave para theo-code:**
- Context compaction e sumarização
- Transport abstraction: mesma lógica do agente sobre CLI, HTTP, Slack
- Multi-provider LLM API unificada
- State management integrado ao core do agente
- System prompt composition dinâmica

**Arquivos-chave:**
- `packages/coding-agent/src/core/agent-session.ts` — Lifecycle e state do agente
- `packages/coding-agent/src/core/compaction/index.ts` — Compaction e sumarização de contexto
- `packages/coding-agent/src/core/tools/index.ts` — Sistema de tools e dispatch
- `packages/coding-agent/src/core/system-prompt.ts` — Composição de system prompt
- `packages/coding-agent/src/core/extensions/index.ts` — Sistema de plugins/extensões

**Quando consultar:** Prompts sobre LLM providers, context compaction, system prompt, state management.

---

### 6. QMD (Query Markup Documents)

**O que faz:** Search engine on-device combinando BM25 (keyword), busca semântica vetorial e LLM re-ranking.

**Stack:** TypeScript (Bun), CLI tool

**Padrões-chave para theo-code:**
- Hybrid search: BM25 + vector + LLM re-ranking
- Hierarchical context: metadata que flui para cima melhora seleção
- MCP server: tools expostas via protocolo padrão
- SQLite + vector database para persistência
- Collection management com indexação incremental

**Arquivos-chave:**
- `src/index.ts` — Lógica principal de indexação, busca e retrieval
- `src/collections.ts` — Gerenciamento de coleções (BM25 + vector search)
- `src/store.ts` — Persistência SQLite + vector database
- `src/llm.ts` — Integração LLM para reranking e busca semântica
- `src/mcp/` — Implementação de MCP server

**Quando consultar:** Prompts sobre retrieval, search, ranking, hybrid search, MCP.

---

### 7. llm-wiki-compiler

**O que faz:** Compila fontes (artigos, docs, notas) em wiki interlinked. Extração de conceitos + geração de páginas em duas fases.

**Stack:** TypeScript (Node.js), CLI tool

**Padrões-chave para theo-code:**
- Two-phase pipeline: extração de conceitos → geração de páginas (elimina dependência de ordem)
- Incremental compilation via SHA-256 hash change detection
- Multi-provider LLM support
- Document parsing e intake estruturado
- Output validation e quality checks (linter)

**Arquivos-chave:**
- `src/compiler/` — Lógica de compilação de wiki (conceitos → páginas)
- `src/providers/` — Suporte multi-LLM (Anthropic, OpenAI)
- `src/ingest/` — Parsing e intake de documentos
- `src/linter/` — Validação de output e quality checks
- `src/cli.ts` — CLI bootstrapping

**Quando consultar:** Prompts sobre code graph, knowledge compilation, caching incremental, parsing.

---

### 8. awesome-harness-engineering

**O que faz:** Coleção curada de padrões, pesquisas e implementações de referência para harness engineering.

**Stack:** Documentação (Markdown + YAML templates)

**Padrões-chave para theo-code:**
- Context delivery e compaction patterns
- Tool design patterns
- Planning artifacts
- Permissions e sandboxing patterns
- Memory management patterns
- Verification e evals patterns
- Agent loop structure patterns
- Multi-agent topologies e trade-offs (67%+ diferença de token efficiency)
- Middleware hooks para enforcement determinístico

**Arquivos-chave:**
- `README.md` — Lista curada organizada por categoria
- `templates/` — Implementações de referência de padrões

**Quando consultar:** Qualquer prompt — consultar primeiro para identificar padrões gerais aplicáveis antes de mergulhar nos repos específicos.

---

## Cross-Reference por Tema

| Tema | Archon | OpenDev | OpenCode | Rippletide | Pi-Mono | QMD | llm-wiki | awesome |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Agent loop | ● | ● | ● | | ● | | | ● |
| Context mgmt | ● | ● | | | ● | ● | | ● |
| Retrieval/search | | | | ● | | ● | | |
| Tool system | | ● | ● | | ● | ● | | ● |
| LLM providers | ● | ● | | ● | ● | ● | ● | |
| Governance | ● | ● | ● | ● | | | | ● |
| Code graph | | | | ● | | | ● | |
| Compaction | | ● | | | ● | | | ● |
| MCP | | | ● | | | ● | | |
| Patterns (Rust) | | ● | | ● | | | | |
