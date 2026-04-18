# Theo-Code Architecture Map

Reference document for the autonomous agent. Read this to understand what you're modifying.

**Project**: Theo-Code — AI coding assistant in Rust (11 library crates + 2 app binaries = 13 evaluated packages, ~30K LOC, 2451 tests)
**Repo**: `/home/paulo/Projetos/usetheo/theo-code`

---

## Workspace Layout

```
apps/
  theo-cli/          → CLI binary (package name: "theo")
  theo-desktop/      → Tauri v2 desktop app (SKIP — needs system deps)
  theo-marklive/     → Markdown live renderer

crates/
  theo-domain/          → Pure types, state machines, zero deps (247 tests)
  theo-agent-runtime/   → Agent loop, pilot mode, convergence (338 tests)
  theo-engine-parser/   → Tree-sitter extraction, 16 languages (468 tests)
  theo-engine-retrieval/ → Search, ranking, context assembly (220 tests)
  theo-engine-graph/    → Code graph construction, clustering (43 tests)
  theo-infra-llm/       → 25 LLM providers, streaming, retry (156 tests)
  theo-infra-auth/      → OAuth PKCE, device flow, env vars (87 tests)
  theo-tooling/         → 40+ tools, registry, schemas (144 tests)
  theo-governance/      → Sandbox, policy, impact analysis (41 tests)
  theo-application/     → Use cases, pipeline, wiki backend (58 tests, 26 COMPILE ERRORS)
  theo-api-contracts/   → Serializable DTOs (0 tests)
  theo-compat-harness/  → Upstream manifest extraction (3 tests, low priority)
```

## Dependency Graph (top → bottom = depends on)

```
theo-cli
  ├── theo-application
  │   ├── theo-engine-graph ── theo-engine-parser ── theo-domain
  │   ├── theo-engine-retrieval ── theo-engine-graph
  │   ├── theo-governance ── theo-domain
  │   └── theo-agent-runtime
  │       ├── theo-tooling ── theo-domain
  │       └── theo-infra-llm ── theo-domain
  └── theo-infra-auth
```

**Rule**: Changes to `theo-domain` rebuild EVERYTHING. Prefer leaf crate changes.

## Package Names (for `cargo test -p <name>`)

| Directory | Package Name |
|-----------|-------------|
| apps/theo-cli | `theo` |
| apps/theo-desktop | `theo-code-desktop` (SKIP) |
| apps/theo-marklive | `theo-marklive` |
| crates/theo-domain | `theo-domain` |
| crates/theo-agent-runtime | `theo-agent-runtime` |
| crates/theo-engine-parser | `theo-engine-parser` |
| crates/theo-engine-retrieval | `theo-engine-retrieval` |
| crates/theo-engine-graph | `theo-engine-graph` |
| crates/theo-infra-llm | `theo-infra-llm` |
| crates/theo-infra-auth | `theo-infra-auth` |
| crates/theo-tooling | `theo-tooling` |
| crates/theo-governance | `theo-governance` |
| crates/theo-application | `theo-application` |
| crates/theo-api-contracts | `theo-api-contracts` |

## Core Data Flow

```
User: "fix the auth bug"
  │
  ├─ CLI parse → AgentLoop::run_with_history()
  │
  ├─ AgentRunEngine builds context stack:
  │   ├─ System prompt (.theo/system-prompt.md or default)
  │   ├─ Project context (.theo/theo.md)
  │   ├─ Cross-session memories (~/.config/theo/memory/)
  │   ├─ Session bootstrap (progress.json + last 20 git commits)
  │   ├─ GRAPHCTX file hints (code intelligence, if ready)
  │   ├─ Available skills summary
  │   └─ User input as task objective
  │
  ├─ Main loop (repeat until converged or budget exhausted):
  │   ├─ Budget check (hard abort if exceeded)
  │   ├─ Context compaction (if >80% token window)
  │   ├─ LLM call (streaming, retry on 429/503/504)
  │   ├─ If tool_calls → execute tools → append results → continue
  │   ├─ If done() called → convergence gates:
  │   │   Gate 0: done_attempts < 3
  │   │   Gate 1: GitDiffConvergence + EditSuccessConvergence
  │   │   Gate 2: cargo test (Rust projects only)
  │   └─ If text only → converge or check follow-up queue
  │
  └─ Session exit: save metrics, patterns, episode summary
```

## State Machines

**RunState** (8 states, exhaustive transitions):
```
Initialized → Planning → Executing → Evaluating
  → Converged (terminal, success)
  → Replanning (loop back to Planning)
  → Waiting (external input needed)
  → Aborted (terminal, failure)
```

**TaskState** (9 states): Pending → Ready → Running → WaitingTool/WaitingInput/Blocked → Completed/Failed/Cancelled

**ToolCallState** (7 states): Queued → Dispatched → Running → Succeeded/Failed/Timeout/Cancelled

All terminal states reject ALL transitions. This is enforced by tests.

## Tool System

**Default registry** (registered at startup):
- File ops: `read`, `write`, `edit`, `apply_patch`, `undo`
- Shell: `bash` (sandboxed — bwrap > landlock > noop cascade)
- Search: `grep`, `glob`
- Git: `git_status`, `git_diff`, `git_commit`, `git_log`
- Web: `http_get`, `http_post`, `webfetch`
- Code intel: `codebase_context`
- Utility: `think`, `reflect`, `memory`, `env_info`

**Meta-tools** (injected by tool_bridge, not in registry):
- `done`: Signals completion (triggers convergence gates)
- `subagent`: Delegate to sub-agent (explorer/implementer/verifier)
- `subagent_parallel`: Multiple sub-agents concurrently
- `batch`: Up to 25 parallel tool calls
- `skill`: Invoke packaged workflow

**Sub-agent isolation**: Sub-agents get `done` + `batch` only (no recursive delegation).

## Pilot Mode (Autonomous Loop)

```rust
PilotLoop {
    promise: String,           // "implement feature X"
    complete: Option<String>,  // Definition of Done
    circuit_state: CircuitBreakerState,
    session_messages: Vec<Message>,  // rotating, max 100
}
```

**Exit conditions** (dual-gate):
1. PromiseFulfilled: 2 consecutive completion signals + real git progress
2. FixPlanComplete: all checkboxes in .theo/fix_plan.md
3. CircuitBreaker: 3 loops no progress OR 5 identical errors
4. RateLimit: max_loops_per_hour exceeded
5. MaxCalls: default 50 total loops

**Corrective guidance**: HeuristicReflector injects nudges like "Focus on EDITING" or "Try a DIFFERENT approach" when failures detected.

## GRAPHCTX (Code Intelligence)

```
extract_repo() → Tree-sitter parse → build_graph()
  → add_git_cochanges() → Louvain cluster()
  → cache to .theo-cache/
  → assemble_context_with_code(query) → ranked context blocks
```

Nodes: files, symbols (functions, structs, traits, imports)
Edges: call, contains, imports, extends, implements (weighted)
Search: BM25 + Tantivy full-text + graph proximity + git recency

## LLM Provider Architecture

```rust
trait LlmProvider: Send + Sync {
    async fn chat(&self, req: &ChatRequest) -> Result<ChatResponse>;
    async fn chat_stream(&self, req: &ChatRequest) -> Result<SseStream>;
}
```

25 providers via OpenAI-compatible interface. Format adapters for Anthropic, Codex.
Streaming with delta callbacks. Token tracking. Overflow detection + recovery.

## Key Invariants (enforced by tests)

1. Tool must not modify messages array during execution
2. All state transitions are atomic (reject invalid transitions)
3. State machine reachability: every non-terminal state is reachable
4. Sandbox policy checked before every tool execution
5. Every execution has unique RunId
6. Snapshots persist before session exit
7. Budget enforcer records iteration BEFORE budget check
8. Terminal states reject ALL transitions

## Governance & Sandbox

- **Bubblewrap** (bwrap) as primary sandbox backend, Landlock fallback
- PID namespace, network isolation, capability dropping
- Resource limits via setrlimit
- Env var sanitization
- Command lexical validation
- Sandbox audit trail (which tools were invoked)
- Impact analysis (affected modules, co-change prediction)

## Known Issues (as of 2026-04-16)

1. **theo-application**: 26 compile errors in lib test target (lib compiles OK, tests don't)
2. **theo-api-contracts**: 0 tests
3. **60 compiler warnings** across workspace
4. **543 clippy warnings** across workspace
5. **1265 unwrap() calls** in production code
6. **12 #[allow(dead_code)]** attributes
7. **0 structural hygiene tests** (structural_hygiene.rs doesn't exist yet)
8. **5 boundary tests** (boundary_test.rs has 5, target is 15+)
9. **0/5 documentation artifacts** (clippy.toml, AGENTS.md, QUALITY_RULES.md, QUALITY_SCORE.md, structural_hygiene.rs)

## Dual-Layer Score Opportunities

### Layer 1 — Workspace Hygiene (current: 90.8/100)

| Action | L1 Impact | Effort |
|--------|----------|--------|
| Fix theo-application compile (26 errors) | +3.08 | Medium |
| Fix 60 cargo warnings | +3.0 | Easy |
| Add tests (api-contracts, governance, graph) | +0.2 | Easy |

### Layer 2 — Harness Maturity (current: 14.1/100)

| Action | L2 Impact | Effort |
|--------|----------|--------|
| Create 5 doc artifacts | +15.0 | Easy (file creation) |
| Fix 543 clippy warnings → 0 | +14.4 | Medium-Hard |
| Reduce 1265 unwrap → 300 | +12.8 | Hard (batch by crate) |
| Add 30 structural tests | +15.0 | Medium |
| Expand boundary tests 5→15 | +10.0 | Medium |
| Remove 12 dead_code attrs → 0 | +6.0 | Easy |

### Combined Score Baseline

**score=52.454** (L1=90.8, L2=14.1) — **47.5 pts headroom**

## Existing Harness Infrastructure

Already present (leverage, don't rebuild):
- `.claude/CLAUDE.md` — architecture overview, dependency rules
- `.claude/rules/` — architecture.md, rust-conventions.md, testing.md, tdd.md
- `.claude/agents/` — 17 agent definitions
- `.claude/hooks/` — boundary-check.sh, post-edit-check.sh, validate-command.sh
- `crates/theo-governance/tests/boundary_test.rs` — 5 ArchUnit-style tests
- Session bootstrap (`progress.json`), failure tracker, convergence evaluator

## Files You Must Not Touch

- `apps/theo-benchmark/` — benchmark isolation
- `apps/theo-desktop/` — needs Tauri, not in eval scope
- `.claude/CLAUDE.md` — project instructions
- `theo-evaluate.sh` — immutable evaluation harness
