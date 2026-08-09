# EvoSkillOpt — Blueprint & Living Roadmap
## v1.0 · Aug 2026 · The master doc for the private-repo fork

> This is the document you carry into the new `evo-skillopt` repo. Everything in it — vision, architecture, ownership split, use cases, roadmap, KPIs, hiring signals, licensing strategy — lives here and gets updated in the private repo, not back-ported.

---

## Table of contents

1. [Vision](#1-vision) — one paragraph
2. [What evo-skillopt is](#2-what-evo-skillopt-is) — concrete scope
3. [Architecture](#3-architecture) — diagram + components
4. [Ownership matrix](#4-ownership-matrix) — what's ours vs inherited
5. [Capabilities](#5-capabilities) — shipped + planned matrix
6. [Use cases catalog](#6-use-cases-catalog) — 5 high-ROI patterns
7. [Reference applications](#7-reference-applications) — DeepTechX + Clow
8. [Roadmap](#8-roadmap) — quarterly targets v0.2 → v1.0
9. [KPIs](#9-kpis) — what to measure
10. [Team & hiring signals](#10-team--hiring-signals) — when to expand
11. [License & commercialization](#11-license--commercialization) — MIT-plus strategy
12. [Naming rules](#12-naming-rules) — kebab / CamelCase
13. [Change management](#13-change-management) — how to update this file
14. [RRSS status & closure list](#14-rrss-status--closure-list)
15. [Cross-references](#15-cross-references)

---

## 1. Vision

**Every AI agent product ships a v1.0 system prompt and iterates via git commits.** EvoSkillOpt makes that iteration happen in production, gated on real user signals, without touching model weights.

The moat is not the code (open source, replicable). The moat is the accumulated trajectories + evolved meta-skills across the customer base.

---

## 2. What evo-skillopt is

**Concretely, one sentence:** A productized wrapper around [SkillOpt](https://arxiv.org/abs/2605.23904) (arXiv:2605.23904) that exposes text-space skill optimization as an HTTP service, callable from any agent runtime.

**Not:** a new training algorithm · a new LLM · a prompt-engineering tool · an eval framework alone.

**Is:** the operations layer that closes the loop between (a) real production signals and (b) the SkillOpt training loop, at inference-time cost, with git-tracked audit trails.

**Elevator pitch (30 sec):**
> Your customer support bot answers 500 tickets a week. Every ticket is a training signal. EvoSkillOpt takes those signals, runs SkillOpt training against your bot's held-out eval set, and ships a smarter skill.md every Monday — if it beats the previous one. If it doesn't, we roll back. Never touches model weights. Costs $12/month per bot in LLM tokens.

---

## 3. Architecture

```
   your agent runtime              evo-skillopt worker              SkillOpt core
   (Rust / Go / Node / Python)     (Python HTTP server)             (unchanged)
        │                                │                                │
        │ POST /train                    │                                │
        │  {bot_id,                      │                                │
        │   skill_path,                  │                                │
        │   skill_version,               │                                │
        │   eval_split_dir,              │                                │
        │   config,                      │                                │
        │   num_epochs,                  │                                │
        │   gate_min_improvement}        │                                │
        │───────────────────────────►    │                                │
        │                                │  subprocess.run(               │
        │                                │    ["python",                  │
        │                                │     "scripts/train.py",        │
        │                                │     ...])                      │
        │                                │──────────────────────────►     │
        │                                │                                │  rollout
        │                                │                                │  reflect
        │                                │                                │  aggregate
        │                                │                                │  select
        │                                │                                │  update
        │                                │                                │  gate
        │                                │  parse                         │
        │                                │  outputs/*/history.json        │
        │                                │  compute gate_score_delta      │
        │                                │◄──────────────────────────     │
        │  {ok:            true,         │                                │
        │   gate_passed:   true,         │                                │
        │   gate_score_delta: 0.073,     │                                │
        │   next_version:  "0.1.5",      │                                │
        │   output_dir:    "outputs/…",  │                                │
        │   duration_s:    412}          │                                │
        │◄───────────────────────────    │                                │

           ┌─────────────────────────────────────────────┐
           │  Optional orchestrator layer (per-product)   │
           │  Rust / TypeScript / whatever                │
           │  • Trajectory ingestion (KafCa bus)          │
           │  • Fitness EMA per bot                       │
           │  • Cadence-triggered evolution (KafCade)     │
           │  • Public leaderboard endpoint               │
           └─────────────────────────────────────────────┘
```

**Components:**

| Component | Language | Where | Status |
|-----------|----------|-------|--------|
| `worker/skillopt_worker.py` | Python 3.9+ (stdlib only) | private repo | ✅ v0.1 shipped |
| `worker/Dockerfile` + `fly.toml` | — | private repo | to build in Week 1 |
| SkillOpt core | Python | vendored from `microsoft/SkillOpt` | ✅ inherited (MIT) |
| Orchestrator (optional) | Rust or TS | per-product | reference: `evo-metaclaw` (Clow) |
| Job queue | Redis / SQLite | private repo | § 8 Q1 |
| Reward model | Python | private repo | § 8 Q2 |
| Federated meta-skills | Python | private repo | § 8 Q3 |
| Meta-optimizer (skill evolves its own optimizer) | Python | private repo | § 8 Q4 |

---

## 4. Ownership matrix

**Bright line between what evo-skillopt owns (proprietary + open) vs what it inherits (SkillOpt, MIT):**

| Layer | Owner | License | Origin |
|-------|-------|---------|--------|
| SkillOpt training loop | Microsoft | MIT | `microsoft/SkillOpt` |
| SkillOpt benchmarks (SearchQA, ALFWorld, DocVQA, ...) | Microsoft | MIT | `microsoft/SkillOpt` |
| LLM backend abstraction | Microsoft | MIT | `microsoft/SkillOpt` |
| **HTTP worker** (`skillopt_worker.py`) | Us | MIT | This session |
| **Deployment configs** (Dockerfile, fly.toml) | Us | MIT | This session (adapted) |
| **Orchestrator patterns** (KafCa bus, KafCade cadence, fitness EMA, gate simulation fallback) | Us | MIT | `evo-metaclaw` (this session) |
| **Job queue** (planned) | Us | proprietary or MIT | Q1 build |
| **Reward-model gate** (planned) | Us | proprietary | Q2 build (competitive) |
| **Federated meta-skills** (planned) | Us | proprietary | Q3 build (moat) |
| **Dashboard UI** (planned) | Us | proprietary | Q2 build |
| **A/B skill deployment** (planned) | Us | proprietary | Q2 build |
| **Marketplace of eval sets** (planned) | Us + community | community-contributed CC-BY | Q3 curation |

**Suggested split:**
- **Open (MIT):** worker, deployment configs, orchestrator patterns — enables ecosystem
- **Proprietary:** job queue at scale, reward model, federated learning, dashboard, A/B — the differentiators
- **Community:** eval sets — the flywheel

---

## 5. Capabilities

Version-numbered checklist. Update on each release.

### v0.1 (shipped, this session)

| Capability | Where |
|-----------|-------|
| ✅ HTTP `POST /train` → returns gate outcome | `worker/skillopt_worker.py` |
| ✅ Bearer auth via `WORKER_TOKEN` env | worker |
| ✅ Body cap (1MB) + subprocess timeout (1h) | worker |
| ✅ Fallback: dev mode when token unset | worker |
| ✅ Parses `history.json` for real gate delta | worker |
| ✅ Version bump semantics (`0.1.4` → `0.1.5`) | worker |
| ✅ Reference orchestrator with KafCa bus + KafCade cadence | `evo-metaclaw` (in Clow branch) |
| ✅ Opt-in bridge from orchestrator (`SKILLOPT_WORKER_URL`) | `evo-metaclaw::call_skillopt_worker` |
| ✅ Fallback to fitness simulation when worker unset | orchestrator |

### v0.2 target (Q1 — ~3 weeks of eng)

| Capability | Notes |
|-----------|-------|
| ⬜ Job queue (SQLite or Redis) — concurrent bot evolution | Priority order queue; ~200 LOC |
| ⬜ Git-tracked skill versioning | libgit2 or `git` shell-out; ~300 LOC |
| ⬜ Cost accounting per evolution (LLM token counter) | Wrap SkillOpt's LLM calls; ~100 LOC |
| ⬜ Rollback UX endpoint (`POST /bots/{id}/rollback?to=v0.1.4`) | + `GET /bots/{id}/skill` + `GET /bots/{id}/diff` |
| ⬜ Structured logs (JSON) with `bot_id` correlation | |
| ⬜ Prometheus `/metrics` endpoint | RED method — request rate, error rate, duration |

### v0.3 target (Q2 — ~6 weeks)

| Capability | Notes |
|-----------|-------|
| ⬜ Reward-model gate (LLM-as-judge with rubric) | Alternative to exact-match; ~500 LOC + eval |
| ⬜ A/B skill deployment (canary traffic %) | Depends on agent runtime supporting per-req skill |
| ⬜ Dashboard UI (per-bot fitness curves, evolution log, cost breakdown) | React or Svelte; single-file OK for MVP |
| ⬜ Per-tenant isolation (SQLite → Postgres) | Tenant-scoped skill storage + audit |
| ⬜ Rate limiting (per-tenant, per-bot) | Simple token bucket |
| ⬜ Human-in-the-loop review queue for high-liability skill changes | Skills touching regex-matched sensitive sections |

### v0.4 target (Q3 — ~9 weeks)

| Capability | Notes |
|-----------|-------|
| ⬜ Federated meta-skills (cross-tenant learning w/o raw data) | Aggregation + differential-privacy layer; MOAT |
| ⬜ Public marketplace of eval sets (community curation) | Category standards: customer-support-v1, moderation-v1, etc |
| ⬜ Auto-generated skill diffs as user-shareable summaries | Weekly digest: "here's what your bot learned" |
| ⬜ Skill inspector — read-only preview + syntax-highlighted diff view | Trust-building UX |
| ⬜ Cost prediction (before triggering evolution) | Historical cost per token vol → dollar estimate |

### v1.0 target (Q4 — production-ready, enterprise-sellable)

| Capability | Notes |
|-----------|-------|
| ⬜ Meta-optimization (SkillOpt-eating-SkillOpt) | Optimizer prompt is itself an evolving skill.md |
| ⬜ Enterprise SSO / SAML | Auth passthrough |
| ⬜ Compliance exports (audit log CSV/PDF, GDPR data export) | Regulatory-tailwind story |
| ⬜ Multi-region deployment (data residency) | US + EU by default |
| ⬜ SLA-backed uptime (99.9% for Growth+, 99.99% for Enterprise) | Ops maturity gate |
| ⬜ On-prem installer (Docker Compose + k8s Helm chart) | Enterprise ask |

---

## 6. Use cases catalog

Each use case is a full playbook: signal wiring, cadence, ROI math, guardrails. Copy from here into per-tenant onboarding docs.

### Catalog (from `EvoSkillOpt.md` § 3)

| # | Use case | Signal source | Est. ROI at scale |
|---|----------|---------------|-------------------|
| 1 | **Customer-support bot** | Intercom/Zendesk CSAT + resolution | ~$3.5k/mo saved at 500-user SaaS |
| 2 | **Outbound SDR / sales-reply** | HubSpot email interactions | Meta-knowledge → team playbook |
| 3 | **Doc/API assistant** | Bot frontend thumbs + follow-ups | ~$3.3k/mo saved + activation lift |
| 4 | **Community moderator** | Mod-console overrides | ~2% churn saved, network effects |
| 5 | **Personalized tutor** (edtech) | Exercise completions | $36k/mo net at 10k subs — **killer app** |

### Additional patterns discovered in DeepTechX application

| # | Use case | Signal source | Est. ROI at scale |
|---|----------|---------------|-------------------|
| 6 | **Grant-writing assistant** (EU / Horizon / EIC) | Section keep/reject + funded outcome | ~$18k/mo MRR at 500 learners (killer for edtech) |
| 7 | **HMW ("How Might We") Coach** | HMW picks + downstream deliverable use | Free-tier activation trigger |
| 8 | **Interview simulator** (role-play B2B/B2G archetypes) | Question-quality + realism ratings | Premium upsell |
| 9 | **Prototype critic** (fidelity roadmap + inclusive design) | Accept/dispute + iteration count | Deliverable-quality lift |
| 10 | **Discord cohort facilitator** | Mod thanks + connection uptake | Community NPS + human-mod hours saved |

### Templates for use case authoring

Each new use case must document, in order:

1. **What** — one sentence
2. **skill.md structure** — 30-50 lines of behavior + guardrails
3. **eval/held_out.json structure** — 20-30 examples with `reward_criteria`
4. **Signal wiring** — table of events → `fitness_delta` values
5. **Cadence** — how often evolution triggers
6. **ROI math** — baseline vs after-evolution with concrete numbers
7. **Guardrails** — what evolution can NEVER change

Template file: `docs/use-cases/_TEMPLATE.md` (build in v0.2).

---

## 7. Reference applications

### 7.1. DeepTechX (edtech · courses on space/quantum/nuclear/SMR/climate)

**Doc:** [`applications/deeptechx.md`](./applications/deeptechx.md) (600 lines · full 6-bot playbook · 90-day rollout)

**TL;DR:** 6 bots (grant writer, tutor, HMW coach, interview simulator, prototype critic, Discord facilitator). ~$38k/mo MRR ceiling at 500 learners vs ~$15k static baseline. First-week deliverable: HMW Coach live behind a feature flag.

**Status:** design complete, integration architecture defined, first-week action list ready. Not yet implemented in DeepTechX repo — that's the next step post-migration.

### 7.2. Clow bots ecosystem

**Doc:** [`applications/clow.md`](./applications/clow.md) (short — how the reference orchestrator + skill.md ecosystem work)

**TL;DR:** Marketplace of PicoClaw bots where each bot can opt into EvoMetaClaw (the Clow-specific name for our orchestration pattern). Pro tier ($9/mo) unlocks weekly evolution for 1 bot. Public evolution leaderboard is a marketplace trust signal.

**Status:** the full stack is code-complete in the `dnzengou/SkillOpt` fork branch `claude/clow-bots-marketing-gtm-p6nTm`. Marketplace UI + backend deployed via `scripts/deploy_fullstack.sh`.

### 7.3. Others (pipeline — quarterly cadence)

Target one new named reference application per quarter to prove pattern generality:

- Q1: **customer-support SaaS** (medium tail)
- Q2: **healthcare-scribe** (highest signal density + regulatory story)
- Q3: **fintech-KYC-assistant** (compliance + audit-trail moat)
- Q4: **legal-doc-reviewer** (highest per-user ARR)

---

## 8. Roadmap

### Quarter by quarter

| Q | Version | Theme | Key ships |
|---|---------|-------|-----------|
| Q1 (this Q) | **v0.2** | Foundation for scale | Job queue, git-tracked skills, cost accounting, rollback UX, structured logs, Prometheus metrics |
| Q2 | **v0.3** | Product-ready | Reward-model gate, A/B skill deploy, dashboard UI, per-tenant isolation, rate limiting, HITL review queue |
| Q3 | **v0.4** | Moat + community | Federated meta-skills, eval-set marketplace, weekly-diff digests, skill inspector, cost prediction |
| Q4 | **v1.0** | Enterprise + meta | Meta-optimization, SSO, compliance exports, multi-region, SLA, on-prem installer |

### 3-week micro-plan for Q1 (immediate after migration)

**Week 1:**
- Migrate this file + `skillopt_worker.py` + reference orchestrator patterns to new repo
- Set up CI (cargo check + node check + py compile — reuse from SkillOpt fork)
- Author `docs/use-cases/_TEMPLATE.md`
- Stub `docs/applications/deeptechx.md` (copy over)

**Week 2:**
- Job queue (SQLite-backed, ~200 LOC) — prevents serial GPU/API blocking
- Cost accounting (~100 LOC) — wraps SkillOpt's LLM calls with token counter
- Structured logs (JSON) — refactor `print(flush=True)` → `logging.getLogger` with JSON formatter

**Week 3:**
- Git-tracked skill versioning — `git init --bare skills.git` per tenant + `commit-on-accept`
- Rollback endpoint + diff endpoint
- Prometheus `/metrics` endpoint
- CHANGELOG.md v0.2 entry
- Docker publish to GHCR (`ghcr.io/<you>/evo-skillopt:0.2`)

**Deliverable:** v0.2 tagged release with docker image + running smoke tests.

### 12-month macro-goals

| Goal | Metric | Deadline |
|------|--------|----------|
| First paying tenant (Team tier) | $99 MRR | End Q1 |
| 5 paying tenants (mixed tiers) | $500 MRR | End Q2 |
| 20 paying tenants + community eval sets published | $2k MRR + 10 categories | End Q3 |
| Enterprise pilot | $5k MRR + 1 named enterprise logo | End Q4 |
| GHCR pulls (leading indicator) | 500/mo | End Q3 |
| GitHub stars on public evo-skillopt repo | 500 | End Q4 |

---

## 9. KPIs

**Product health (weekly review):**
- p50 / p95 evolution wall-time
- Gate pass rate (per tenant, per bot)
- Cost per evolution (LLM $)
- Cost per accepted evolution (economic efficiency)
- Rollback rate (should be < 5% — higher = eval sets too weak)
- Skill drift metric: KL-divergence between v0.1.0 and current (safety check)

**Business (monthly review):**
- MRR by tier
- Net revenue retention
- Time-from-signup to first-accepted-evolution
- % tenants with ≥ 3 bots (multi-bot = defensive retention)
- Support ticket rate per tenant
- Ratio: paying tenants / free tenants (marketplace-of-eval-sets flywheel proxy)

**Ecosystem (quarterly review):**
- GHCR image pulls
- GitHub stars, forks
- Community-contributed eval sets (count + categories)
- Named third-party integrations (agent frameworks referencing evo-skillopt)
- Academic citations (evo-skillopt paper? long-term)

---

## 10. Team & hiring signals

**Founding team (now):** 1 (you) + 1 AI collaborator + community contributions.

**Trigger to hire (in priority order):**

| Role | Trigger | Cost/mo |
|------|---------|---------|
| Full-stack eng (Python + Rust) | 5+ paying tenants, backlog blocking Q2 ships | $12-15k |
| DevRel / community | 200+ community-contributed eval sets or 1k GitHub stars | $8-12k |
| Head of AI ops | 20+ tenants, need federated meta-skills operationalized | $15-20k |
| Sales (enterprise) | 3+ inbound enterprise leads > $10k ARR | $10k + comm |
| Solutions architect | 5+ concurrent enterprise onboardings | $12k |

**Advisory targets:**
- One SkillOpt paper co-author (technical legitimacy)
- One agent-framework maintainer (LangChain, AutoGen, CrewAI)
- One enterprise AI-safety officer (regulatory tailwind)

---

## 11. License & commercialization

**Public / open (MIT):**
- `worker/skillopt_worker.py` (already stdlib-only, MIT-clean)
- SkillOpt core (inherited MIT)
- Orchestrator patterns (Rust reference impl from Clow)
- All docs in the public repo (this Blueprint minus commercial specifics)

**Proprietary (private repo):**
- Job queue at scale (Redis cluster orchestration)
- Federated meta-skills (the moat)
- Dashboard UI + admin console
- A/B skill deployment infrastructure
- Reward model + eval-set marketplace curation
- Enterprise features (SSO, compliance exports, on-prem installer)

**Suggested tiers:**

| Tier | Price | What |
|------|-------|------|
| Open source | $0 | Self-host worker + basic orchestrator. Community support only. |
| Solo | $19/mo | 1 tenant, 1 bot, weekly evolution, hosted worker, dashboard |
| Team | $99/mo | 5 bots, daily evolution, private eval sets, cost dashboard |
| Growth | $499/mo | 50 bots, hourly cadence, A/B deploy, reward model, HITL queue |
| Enterprise | custom (~$5k+/mo) | Federated meta-skills, SSO, compliance, on-prem, SLA |

**Pricing benchmarks:**
- LangSmith: $39/mo/seat (observability only)
- Braintrust: $99/mo entry (evals only)
- W&B Prompts: $50/mo/seat (prompt versioning)

We do the union of all three + close the loop. Can price 2× on Team+ tiers.

---

## 12. Naming rules

Preserve consistency. Reject drift.

| Concept | Public / branding | Code / crate |
|---------|-------------------|--------------|
| The service | **EvoSkillOpt** | `evo-skillopt` |
| The worker binary | EvoSkillOpt worker | `skillopt_worker.py` |
| The Rust orchestrator (product-neutral) | **EvoOrchestrator** | `evo-orchestrator` |
| The Clow-specific orchestrator | EvoMetaClaw | `evo-metaclaw` |
| The bus | **KafCa** | `kafca` module in shared/ |
| The cadence layer | **KafCade** | tokio interval loops (informal) |
| The resilience rubric | **RRSS** | (no code — audit checklist) |
| The build-time UX (bot publisher onramp) | **EvoForge** | `evo-forge` (future CLI) |

**Rules:**
- CamelCase in docs, kebab-case in code
- Never split into two words in public copy (e.g., "Evo Skill Opt" — no)
- Prefix all internal-only projects with `evo-` for coherence
- Future services should follow: `evo-<noun>` (avoid `evo-<verb>-<noun>` — too long)

---

## 13. Change management

**How to update this Blueprint:**

1. Every commit that ships a capability from § 5 → tick the ⬜ → ✅ and add a one-line changelog entry at bottom of file
2. Every quarterly review → update § 8 roadmap + § 9 KPI actuals + § 10 hiring signal thresholds
3. Every new named reference application → append to § 7 (never delete — history compounds)
4. Every version tag (`v0.2`, `v0.3`, ...) → cut a copy of this file at that state under `docs/blueprint-history/vX.Y.md` for reference

**Cadence:**
- Weekly: tick capabilities, no full review
- Monthly: KPIs actuals update
- Quarterly: full read-through + roadmap re-plan

**Ownership:** this file is the Blueprint. If it disagrees with a decision in a meeting, either update it same-day or don't make that decision.

---

## 14. RRSS status & closure list

**Current (v0.1, from `EvoSkillOpt.md` § 7):**

| Dimension | Status |
|-----------|--------|
| **R**obustify | ⚠️ partial — worker has timeouts, no retry-on-transient |
| **R**eliabilify | ⚠️ partial — `/health` + print logs, no metrics/traces/alerts |
| **S**olidify | ⚠️ partial — bearer auth ✓, no formal worker test suite |
| **S**tabilize | ❌ — no concurrency control, no output retention policy |

**Closure list (pre-v0.2 shipping — hard gate for first paying tenant):**

- [ ] **Stabilize.1** — Add graceful shutdown to worker (SIGTERM handler; drain in-flight jobs; ~30 LOC)
- [ ] **Stabilize.2** — `OUTPUT_ROOT` retention policy: keep last 30 evolutions per bot, delete older (~50 LOC)
- [ ] **Stabilize.3** — Per-tenant memory caps on skill history (~30 LOC)
- [ ] **Robustify.1** — Retry on transient LLM API failures (5xx, ECONNRESET) with exp backoff (~80 LOC)
- [ ] **Robustify.2** — Circuit breaker on LLM provider — trip after 5 consecutive fails, half-open probe every 30s (~100 LOC)
- [ ] **Reliabilify.1** — Prometheus `/metrics` endpoint (~100 LOC)
- [ ] **Reliabilify.2** — Structured JSON logs with `bot_id` + `job_id` correlation (~50 LOC)
- [ ] **Reliabilify.3** — Alert wiring (Slack webhook on gate-failure-rate > 40% for 1h) (~30 LOC)
- [ ] **Solidify.1** — pytest suite for worker (mock SkillOpt to avoid burning tokens; ~15 tests, ~400 LOC)
- [ ] **Solidify.2** — CI runs pytest + docker build on every push (~30 LOC yml)

Total: ~1000 LOC + tests. Realistic: **2 weeks of eng** to close all 10.

---

## 15. Cross-references

**In this repo (post-migration):**
- `worker/skillopt_worker.py` — the core HTTP service
- `worker/README.md` — worker-specific ops docs
- `docs/architecture.md` — expanded § 3
- `docs/use-cases.md` — expanded § 6
- `docs/roadmap.md` — expanded § 8
- `docs/applications/deeptechx.md` — full DeepTechX playbook
- `docs/applications/clow.md` — Clow integration reference
- `examples/` — starter skill.md + eval.json per pattern

**In the SkillOpt fork (source repo — reference-only after migration):**
- `github.com/dnzengou/SkillOpt` on branch `claude/clow-bots-marketing-gtm-p6nTm`
- `scripts/skillopt_worker.py` — the version that was lifted (freeze here for provenance)
- `clow-agents/backend/evo-metaclaw/` — the orchestrator reference impl
- `EvoSkillOpt.md` — the original brief (this Blueprint's ancestor)
- `EvoSkillOpt_DeepTechX.md` — the DeepTechX application source doc

**External:**
- [SkillOpt paper (arXiv:2605.23904)](https://arxiv.org/abs/2605.23904)
- [SkillOpt docs](https://microsoft.github.io/SkillOpt/)
- [Microsoft/SkillOpt repo](https://github.com/microsoft/SkillOpt) — upstream to track

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-08-09 | Blueprint created (this file). v0.1 capabilities documented as shipped. Q1 → Q4 roadmap set. RRSS closure list defined. Migration from `dnzengou/SkillOpt` fork branch prepped. |

---

*EvoSkillOpt Blueprint v1.0 · Aug 2026 · MIT (public) + proprietary (private) · Built on SkillOpt (arXiv:2605.23904) · KafCa · KafCade · RRSS · ARM*
