# Autoloop Roadmap

Modelo operacional prompt-driven para evolução de features do theo-code.

---

## Modelo Operacional

O autoloop v2 não segue fases fixas (STABILIZE → SCAFFOLD → etc.). Em vez disso, opera sob demanda: o operador fornece um **prompt de evolução** e o agente executa o ciclo completo até convergência SOTA.

```
OPERADOR                          AGENTE
  │                                 │
  ├─ "Evolua o context manager" ──→ │
  │                                 ├─ RESEARCH (referências)
  │                                 ├─ IMPLEMENT (mudança)
  │                                 ├─ HYGIENE CHECK (piso)
  │                                 ├─ SOTA EVALUATE (rubrica)
  │                                 ├─ ITERATE (até convergir)
  │    ←── "Converged (2.6/3.0)" ──┤
  │                                 │
  ├─ "Implemente HyDE no retrieval" →│
  │                                 ├─ RESEARCH ...
  │                                 └─ ...
```

### Ciclo de Vida de um Prompt

1. **Receber** — operador escreve em `.theo/evolution_prompt.md`
2. **Pesquisar** — agente consulta `reference-catalog.md`, lê repos relevantes
3. **Implementar** — mudanças incrementais (max 200 linhas/iteração)
4. **Avaliar** — hygiene floor + SOTA rubric (5 dimensões)
5. **Iterar** — até SOTA média ≥ 2.5 ou 15 iterações
6. **Reportar** — assessment final em `evolution_assessment.md`

### Tipos de Prompt Suportados

| Tipo | Exemplo | Ação do agente |
|---|---|---|
| **Evolução** | "Evolua o context manager" | Pesquisa SOTA, implementa melhorias incrementais |
| **Implementação** | "Implemente HyDE no retrieval" | Pesquisa o padrão, implementa do zero |
| **Revisão** | "Revise o error handling do agent loop" | Pesquisa padrões de error handling, refatora |
| **Comparação** | "Compare nosso sandbox com o do OpenDev" | Pesquisa, documenta gaps, implementa melhorias |

---

## Hygiene Floor

O score dual-layer (L1+L2)/2 continua sendo calculado a cada iteração como **piso inegociável**:

- Score caiu? → revert imediato, independente da qualidade SOTA
- Score mantido? → normal, continue com SOTA evaluation
- Score subiu? → bônus — o agente melhorou hygiene enquanto evoluía a feature

O operador pode, entre prompts de evolução, rodar sessões de hygiene pura usando a feature_list.json existente se quiser aumentar o baseline.

---

## Métricas de Progresso

### Por Prompt

| Métrica | O que mede |
|---|---|
| Iterações até convergência | Eficiência do agente naquele domínio |
| SOTA scores por dimensão | Onde o agente é forte/fraco |
| Hygiene delta | Impacto colateral nas métricas de código |
| Referências consultadas | Quais repos informaram a evolução |

### Acumuladas

| Métrica | O que mede |
|---|---|
| Prompts convergidos / total | Taxa de sucesso geral |
| Média de iterações por prompt | Eficiência média |
| Dimensões mais fracas (agregado) | Onde o agente precisa melhorar sistematicamente |
| Referências mais úteis | Quais repos têm mais impact |

---

## Quando Usar Hygiene Loop vs Evolution Loop

| Situação | Usar |
|---|---|
| Codebase com muitos warnings, unwraps, compile errors | **Hygiene** (feature_list.json com score ratchet) |
| Quero melhorar uma feature específica | **Evolution** (prompt + SOTA rubric) |
| Quero comparar com SOTA | **Evolution** com prompt de comparação |
| Manutenção rotineira | **Hygiene** |
| Overnight run para evolução | **Evolution** com prompt definido |

---

## Referências

- **Prompt-driven evolution**: Karpathy autoresearch — human sets direction, agent iterates
- **Rubric-based assessment**: ProjDevBench (Lu et al., 2026) — dual evaluation
- **Evidence-grounded**: VeRO (Ursekar et al., 2026) — per-sample scores with traces
- **Incremental progress**: Anthropic (Young, 2025) — one feature at a time
