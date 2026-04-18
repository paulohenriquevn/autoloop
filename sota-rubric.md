# SOTA Quality Rubric

Rubrica de auto-avaliação para o evolution loop. O agente pontua cada dimensão de 0 a 3 após cada iteração. A convergência ocorre quando a média das 5 dimensões ≥ 2.5.

**Regra G18:** Toda pontuação DEVE citar evidência específica das referências consultadas. "Padrão aplicado" sem citar qual padrão e de qual referência = pontuação inválida.

---

## As 5 Dimensões

### 1. Pattern Fidelity — Fidelidade ao padrão de referência

O quanto a implementação reflete os padrões SOTA identificados nos repos de referência.

| Score | Nível | Definição | Exemplo no contexto theo-code |
|:---:|---|---|---|
| 0 | None | Nenhum padrão de referência identificado ou aplicado | Mudança ad-hoc sem consultar referências |
| 1 | Basic | Padrão identificado mas aplicado parcialmente — elementos-chave ausentes | Implementou hybrid search mas sem re-ranking (QMD tem 3 estágios, implementou 1) |
| 2 | Good | Padrão aplicado com gaps menores — funciona mas falta polish | Implementou compaction em estágios (como OpenDev) mas sem validação de mensagens entre estágios |
| 3 | SOTA | Padrão fielmente adaptado ao contexto Rust/theo, com adaptações idiomáticas | ReAct loop com thinking/critique separados (como OpenDev) usando traits Rust e async/await nativo |

**Como pontuar:**
- Cite o padrão específico: "Padrão X do repo Y (arquivo Z)"
- Compare: o que a referência faz vs o que foi implementado
- Gaps: liste o que falta para chegar ao nível seguinte

---

### 2. Architectural Fit — Encaixe arquitetural

O quanto a mudança respeita e melhora a arquitetura existente do theo-code.

| Score | Nível | Definição | Exemplo no contexto theo-code |
|:---:|---|---|---|
| 0 | None | Viola fronteiras do theo-code (dependency direction, domain purity) | Adicionou dependência de theo-infra-llm em theo-domain |
| 1 | Basic | Respeita fronteiras mas integração awkward — workarounds, type conversions forçadas | Trait definido no crate errado, forçando imports circulares |
| 2 | Good | Integração limpa seguindo convenções existentes — parece que sempre esteve ali | Novo trait em theo-domain, impl em theo-application, seguindo GraphContextProvider pattern |
| 3 | SOTA | Melhora a arquitetura existente — reduz acoplamento, simplifica dependências | Refatorou composição de contexto eliminando 2 camadas desnecessárias, mantendo todos os testes |

**Como pontuar:**
- Verifique: dependency graph respeitado? (theo-architecture.md)
- Verifique: convenções existentes seguidas? (trait em domain, impl em application)
- Verifique: a mudança tornou o código mais fácil de navegar ou mais difícil?

---

### 3. Completeness — Completude

O quanto a implementação cobre o escopo necessário para produção.

| Score | Nível | Definição | Exemplo no contexto theo-code |
|:---:|---|---|---|
| 0 | None | Stub ou skeleton — compila mas não funciona | Trait com métodos `todo!()` |
| 1 | Basic | Happy path funciona, edge cases ausentes | Busca retorna resultados para queries simples, mas falha com query vazia ou sem resultados |
| 2 | Good | Core + edge cases principais tratados | Busca funciona, queries vazias retornam empty vec, timeout configurável, overflow de tokens tratado |
| 3 | SOTA | Production-ready: error handling, timeouts, métricas, graceful degradation | Busca com fallback cascade (como QMD: Tier 2 → Tier 1 → Tier 0), metrics per-query, budget enforcement |

**Como pontuar:**
- Liste os edge cases conhecidos e quais foram tratados
- Verifique: erro retornado é tipado (`Result<T, DomainError>`) ou genérico?
- Verifique: comportamento degradado é graceful (retorna parcial) ou catastrófico (panic)?

---

### 4. Testability — Testabilidade

Qualidade e cobertura dos testes que acompanham a mudança.

| Score | Nível | Definição | Exemplo no contexto theo-code |
|:---:|---|---|---|
| 0 | None | Sem testes | Mudança sem nenhum `#[test]` |
| 1 | Basic | Happy path testado | `test_query_returns_results()` — 1 teste verificando que funciona |
| 2 | Good | Core behavior + edge cases testados com boa cobertura | Testes para query vazia, query grande, budget excedido, timeout, resultados parciais |
| 3 | SOTA | Property-based ou boundary tests verificando invariantes, testes de regressão | `test_total_tokens_never_exceeds_budget()` via proptest/quickcheck, boundary tests em structural_hygiene.rs |

**Como pontuar:**
- Conte: quantos testes adicionados?
- Verifique: testes cobrem edge cases ou só happy path?
- Verifique: testes verificam comportamento ou estrutura? (comportamento é melhor)
- Verifique: testes são determinísticos? (sem flaky)

---

### 5. Simplicity — Simplicidade

O quanto a implementação é mínima e focada, sem complexidade desnecessária.

| Score | Nível | Definição | Exemplo no contexto theo-code |
|:---:|---|---|---|
| 0 | None | Over-engineered ou under-designed | 5 novos traits e 3 structs para o que deveria ser 1 função |
| 1 | Basic | Complexidade razoável mas abstrações desnecessárias presentes | Builder pattern para struct com 3 campos |
| 2 | Good | Limpo e focado — cada abstração justifica sua existência | Trait com 2 métodos, 1 impl, 3 funções auxiliares — tudo necessário |
| 3 | SOTA | Implementação mínima viável — impossível remover algo sem quebrar funcionalidade | Mudança de 40 linhas que resolve o problema completamente, sem boilerplate |

**Como pontuar:**
- Pergunte: "posso remover algo sem perder funcionalidade?"
- Verifique: abstrações criadas têm pelo menos 2 usos concretos? (YAGNI)
- Verifique: linhas de código proporcionais ao problema resolvido?
- **G20 check:** novas abstrações (traits, structs, módulos) existem porque o padrão de referência exige?

---

## Convergência

**Threshold:** Média das 5 dimensões ≥ 2.5

Isso significa que a implementação está "Good+" na maioria das dimensões, com pelo menos algumas em SOTA. Uma implementação uniformemente "Good" (todas = 2, média = 2.0) **não converge** — precisa de pelo menos 3 dimensões em SOTA ou equivalente.

**Exemplos de perfis convergentes:**
- `[3, 3, 2, 2, 3]` = 2.6 ✓ (forte em fidelidade, arquitetura e simplicidade)
- `[2, 3, 3, 3, 2]` = 2.6 ✓ (forte em completude e testes)
- `[3, 2, 3, 2, 3]` = 2.6 ✓ (SOTA em padrão, completude e simplicidade)

**Exemplos de perfis NÃO convergentes:**
- `[2, 2, 2, 2, 2]` = 2.0 ✗ (uniformemente Good mas sem SOTA em nenhuma dimensão)
- `[3, 3, 1, 1, 3]` = 2.2 ✗ (forte nos extremos mas completude e testes fracos)
- `[3, 1, 3, 3, 1]` = 2.2 ✗ (padrão aplicado mas arquitetura e simplicidade ruins)

---

## Armadilhas Comuns

### Inflação de nota
- **Sintoma:** Todas as dimensões pontuadas em 3 na primeira iteração
- **Causa:** O agente otimiza para convergir rápido, não para qualidade real
- **Prevenção:** G18 exige citação de evidência. Se não cita padrão específico, Pattern Fidelity = 0

### Comparação com referência errada
- **Sintoma:** "Implementei como o Archon faz" para um problema de retrieval
- **Causa:** Archon não é referência para retrieval — QMD e Rippletide são
- **Prevenção:** Seguir o lookup table em `reference-catalog.md`

### SOTA sem testes
- **Sintoma:** Pattern Fidelity = 3, Testability = 0
- **Causa:** O agente focou em implementar o padrão mas esqueceu os testes
- **Prevenção:** Testability < 2 impede convergência (média cai)

### Complexidade importada da referência
- **Sintoma:** Implementação copia a complexidade do TypeScript/Python sem adaptar para Rust
- **Causa:** Referências em TS/Python usam patterns que não são idiomáticos em Rust
- **Prevenção:** Simplicity avalia adaptação idiomática, não cópia literal

---

## Template de Assessment

O agente deve gravar em `.theo/evolution_assessment.md` após cada iteração:

```markdown
## Evolution Assessment — Iteration N

**Prompt:** [prompt de evolução]
**Commit:** [SHA]
**Referências consultadas:** [repos e arquivos]

### Scores

| Dimensão | Score | Evidência |
|---|:---:|---|
| Pattern Fidelity | X/3 | Padrão: [qual], Referência: [repo/arquivo]. Aplicado: [o que]. Gap: [o que falta] |
| Architectural Fit | X/3 | Fronteiras: [respeitadas/violadas]. Convenção: [seguida/adaptada]. Impacto: [positivo/neutro] |
| Completeness | X/3 | Happy path: [sim/não]. Edge cases: [lista]. Error handling: [tipado/genérico] |
| Testability | X/3 | Testes adicionados: [N]. Cobertura: [happy path / edge cases / invariantes] |
| Simplicity | X/3 | LOC: [N]. Abstrações novas: [lista]. Justificativa: [YAGNI check] |

**Média:** X.X
**Status:** ITERATE / CONVERGED
**Gaps prioritários:** [dimensões com score mais baixo e o que fazer]
```

---

## Referências

- **Autoresearch pattern:** Karpathy (2026) — greedy ratchet with binary accept/reject
- **Rubric-based assessment:** ProjDevBench (Lu et al., 2026) — dual evaluation (execution + code review)
- **Evidence-grounded evaluation:** VeRO (Ursekar et al., 2026) — per-sample scores with traces
- **Pattern fidelity:** Böckeler (2026) — "if sensors never fire, is that high quality or inadequate detection?"
