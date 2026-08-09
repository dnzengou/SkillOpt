#!/usr/bin/env bash
# migrate_to_evo_skillopt.sh
#
# Assemble a clean, self-contained seed directory for the new
# private `evo-skillopt` repo. Copies exactly the files that need
# to move, generates minimal scaffolding (README, LICENSE,
# .gitignore, Dockerfile, fly.toml, CI), and prints the 3-step
# push command at the end.
#
# What it does NOT do:
#   - Create a GitHub repo (requires your credentials)
#   - Push (you run `git push` after inspecting the seed)
#
# Usage:
#   ./scripts/migrate_to_evo_skillopt.sh                 # → ./evo-skillopt-seed/
#   DEST=/tmp/evo-skillopt ./scripts/migrate_to_evo_skillopt.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${DEST:-$ROOT/evo-skillopt-seed}"

log() { printf "\033[1;36m▸\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m✓\033[0m %s\n" "$*"; }

# ─── PRE-FLIGHT ─────────────────────────────────────────────────────────
if [ -d "$DEST" ]; then
  log "Removing existing $DEST"
  rm -rf "$DEST"
fi
mkdir -p "$DEST"/{worker,docs/applications,examples,scripts,.github/workflows}

# ─── CORE: THE WORKER ───────────────────────────────────────────────────
log "Lifting worker/skillopt_worker.py"
cp "$ROOT/scripts/skillopt_worker.py" "$DEST/worker/skillopt_worker.py"
chmod +x "$DEST/worker/skillopt_worker.py"

# ─── SUPPORTING SCRIPTS ─────────────────────────────────────────────────
log "Lifting scripts/smoke.sh (health probe)"
cp "$ROOT/scripts/smoke.sh" "$DEST/scripts/smoke.sh"
chmod +x "$DEST/scripts/smoke.sh"

# ─── DOCS — the Blueprint is THE doc, everything else references it ────
log "Lifting docs"
cp "$ROOT/EvoSkillOpt_Blueprint.md"     "$DEST/EvoSkillOpt_Blueprint.md"
cp "$ROOT/EvoSkillOpt.md"                "$DEST/docs/CONCEPT.md"           # the original brief (provenance)
cp "$ROOT/EvoSkillOpt_DeepTechX.md"      "$DEST/docs/applications/DEEPTECHX.md"
cp "$ROOT/EvoStack.md"                   "$DEST/docs/EVOSTACK.md"          # name-space reference

# ─── EXAMPLE BOTS — from the Clow marketplace inventory ─────────────────
log "Lifting example skill.md + eval sets (adapted for standalone worker)"
for bot in telegram-summarizer discord-moderator slack-standup; do
  if [ -d "$ROOT/bots/$bot" ]; then
    mkdir -p "$DEST/examples/$bot"
    cp -r "$ROOT/bots/$bot/"* "$DEST/examples/$bot/"
  fi
done

# ─── DOCKERFILE for the worker ──────────────────────────────────────────
log "Generating worker/Dockerfile"
cat > "$DEST/worker/Dockerfile" <<'DOCKERFILE'
# EvoSkillOpt worker — stdlib-only Python 3.11+
# Vendored SkillOpt: install as a subdirectory or git submodule under /app/skillopt
FROM python:3.11-slim
WORKDIR /app

# System deps for SkillOpt training + git-tracked skills
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install SkillOpt (public MIT — pin a tag when vendoring for reproducibility)
# Option A: pip install the SkillOpt package (once published)
#   RUN pip install --no-cache-dir skillopt==<TAG>
# Option B (recommended for MVP): git submodule + editable install
#   Add SkillOpt as a submodule under skillopt/ and:
COPY skillopt/ /app/skillopt
RUN pip install --no-cache-dir -e /app/skillopt

# Worker itself
COPY worker/skillopt_worker.py /app/skillopt_worker.py
ENV OUTPUT_ROOT=/data/outputs
ENV TRAIN_SCRIPT=/app/skillopt/scripts/train.py
ENV PORT=9000
EXPOSE 9000
CMD ["python3", "/app/skillopt_worker.py"]
DOCKERFILE

log "Generating worker/fly.toml"
cat > "$DEST/worker/fly.toml" <<'FLYTOML'
app = "evo-skillopt-worker"
primary_region = "ord"

[build]
  dockerfile = "Dockerfile"

[env]
  PYTHONUNBUFFERED = "1"
  PORT = "9000"

[http_service]
  internal_port = 9000
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 0

[[mounts]]
  source = "evo_data"
  destination = "/data"

[[vm]]
  memory = "1gb"
  cpu_kind = "shared"
  cpus = 1
FLYTOML

log "Generating worker/README.md"
cat > "$DEST/worker/README.md" <<'MD'
# EvoSkillOpt worker

Stdlib-only Python HTTP service. Wraps SkillOpt's `scripts/train.py`.

## Endpoints

| Method | Path | Notes |
|--------|------|-------|
| GET | `/health` | Liveness |
| POST | `/train` | Run one training step (bearer auth if `WORKER_TOKEN` set) |

## Env

| Var | Default | Purpose |
|-----|---------|---------|
| `WORKER_TOKEN` | (unset — dev mode) | Bearer token for `POST /train` |
| `OUTPUT_ROOT` | `outputs/evo` | Where training runs write outputs |
| `TRAIN_SCRIPT` | `scripts/train.py` | Path to SkillOpt's train entrypoint |
| `PORT` | `9000` | Listen port |

## Local dev

```bash
WORKER_TOKEN=dev-token PORT=9000 python3 skillopt_worker.py
```

## Deploy (Fly.io)

```bash
# One-time
fly apps create evo-skillopt-worker
fly volumes create evo_data --region ord --size 1

# Deploy
fly deploy

# Verify
curl https://evo-skillopt-worker.fly.dev/health
```

## Test the training endpoint

```bash
curl -X POST https://evo-skillopt-worker.fly.dev/train \
  -H "Authorization: Bearer $WORKER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "bot_id": "test/bot-1",
    "skill_version": "0.1.0",
    "config": "configs/searchqa/default.yaml",
    "num_epochs": 1
  }'
```

See `../EvoSkillOpt_Blueprint.md` for the full roadmap.
MD

# ─── TOP-LEVEL README ───────────────────────────────────────────────────
log "Generating top-level README.md"
cat > "$DEST/README.md" <<'MD'
# evo-skillopt

> [SkillOpt](https://arxiv.org/abs/2605.23904) as a service. Text-space skill optimization for production LLM agents, callable over HTTP.

**Living roadmap:** [`EvoSkillOpt_Blueprint.md`](./EvoSkillOpt_Blueprint.md)
**Concept doc:** [`docs/CONCEPT.md`](./docs/CONCEPT.md)
**Applications:** [`docs/applications/`](./docs/applications/)

---

## Quick start

```bash
# Add SkillOpt as a submodule (Microsoft/SkillOpt, MIT)
git submodule add https://github.com/microsoft/SkillOpt skillopt

# Run the worker locally
cd worker
WORKER_TOKEN=dev-token PORT=9000 python3 skillopt_worker.py

# In another terminal
curl http://localhost:9000/health
```

## What this is

A minimal HTTP wrapper around SkillOpt that lets any agent runtime
POST a training job and get back a gate outcome. See
[`EvoSkillOpt_Blueprint.md`](./EvoSkillOpt_Blueprint.md) for the full
picture — capabilities, roadmap (v0.1 → v1.0), use cases, KPIs,
hiring signals, licensing strategy.

## Structure

```
evo-skillopt/
├── EvoSkillOpt_Blueprint.md      # THE living roadmap — read first
├── README.md                     # this file
├── LICENSE                       # MIT
├── worker/
│   ├── skillopt_worker.py        # the core HTTP service (stdlib only)
│   ├── Dockerfile
│   ├── fly.toml
│   └── README.md
├── docs/
│   ├── CONCEPT.md                # original v0 brief (provenance)
│   ├── EVOSTACK.md               # name-space reference
│   └── applications/
│       └── DEEPTECHX.md          # DeepTechX 6-bot playbook
├── examples/                     # starter skill.md + eval.json per pattern
│   ├── telegram-summarizer/
│   ├── discord-moderator/
│   └── slack-standup/
├── scripts/
│   └── smoke.sh                  # health probe
└── .github/workflows/
    └── ci.yml                    # py compile + shellcheck + docker build
```

## Contributing

Read [`EvoSkillOpt_Blueprint.md § 13`](./EvoSkillOpt_Blueprint.md#13-change-management) before opening a PR.

## License

MIT — see [`LICENSE`](./LICENSE). SkillOpt (vendored) is MIT (Microsoft).
MD

# ─── LICENSE (MIT — matches SkillOpt upstream) ──────────────────────────
log "Generating LICENSE (MIT)"
cat > "$DEST/LICENSE" <<'LICENSE'
MIT License

Copyright (c) 2026 evo-skillopt contributors
Copyright (c) 2026 Microsoft Corporation (vendored SkillOpt, arXiv:2605.23904)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICENSE

# ─── .gitignore ─────────────────────────────────────────────────────────
log "Generating .gitignore"
cat > "$DEST/.gitignore" <<'GITIGNORE'
# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
.pytest_cache/

# Output data
/outputs/
/data/
*.db
*.sqlite
*.log

# Env
.env
.env.local
.env.*.local

# IDE
.idea/
.vscode/
*.swp
.DS_Store

# Fly
.fly/

# Docker
.dockerignore

# Vendored SkillOpt (added as submodule; don't check in as regular files)
# Uncomment if you vendor instead of submodule:
# /skillopt/
GITIGNORE

# ─── CI ─────────────────────────────────────────────────────────────────
log "Generating .github/workflows/ci.yml"
cat > "$DEST/.github/workflows/ci.yml" <<'YML'
name: ci

on:
  push:
    branches: [main, "develop/**", "feature/**"]
  pull_request:

jobs:
  py-check:
    name: python compile + smoke test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - name: py compile worker
        run: python3 -m py_compile worker/skillopt_worker.py
      - name: bash -n smoke
        run: bash -n scripts/smoke.sh

  shellcheck:
    name: shellcheck (informational)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: install + run
        run: |
          sudo apt-get update && sudo apt-get install -y shellcheck
          shellcheck scripts/*.sh || true

  docker-build:
    name: docker build (worker image)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # NOTE: this build will fail until SkillOpt is added as submodule.
      # Uncomment when submodule is in place:
      # - name: check out submodules
      #   run: git submodule update --init --recursive
      # - name: build worker image
      #   working-directory: worker
      #   run: docker build -t evo-skillopt-worker:ci .
YML

# ─── ONE-PAGE MIGRATE.md AT THE ROOT OF THE SEED ────────────────────────
log "Generating MIGRATE.md"
cat > "$DEST/MIGRATE.md" <<'MD'
# How to complete the migration

This seed dir is ready. Three commands.

## 1. Create the private repo on GitHub

Manually, or via `gh` if you have it installed:

```bash
gh repo create your-github/evo-skillopt --private --description "SkillOpt as a service"
```

## 2. Initialize + push from this seed

```bash
cd evo-skillopt-seed
git init
git branch -M main
git add .
git commit -m "chore: initial commit (migrated from dnzengou/SkillOpt fork)

Seeded from `claude/clow-bots-marketing-gtm-p6nTm` on dnzengou/SkillOpt.
Contains:
  - worker/ — stdlib Python HTTP service wrapping SkillOpt
  - EvoSkillOpt_Blueprint.md — living roadmap (READ FIRST)
  - docs/ — concept, name-space reference, applications
  - examples/ — starter skill.md + eval.json per pattern
  - scripts/ — health probe
  - .github/workflows/ci.yml — py compile + shellcheck + docker build

See EvoSkillOpt_Blueprint.md § 8 for Q1 → v0.2 shipping plan."
git remote add origin git@github.com:your-github/evo-skillopt.git
git push -u origin main
```

## 3. Add SkillOpt as a submodule

```bash
git submodule add https://github.com/microsoft/SkillOpt skillopt
git commit -am "chore: vendor SkillOpt as submodule (MIT)"
git push
```

Done. First-week plan is in `EvoSkillOpt_Blueprint.md § 8`.

---

## What was left behind on purpose

The source branch (`dnzengou/SkillOpt` · `claude/clow-bots-marketing-gtm-p6nTm`)
also contains Clow-specific artifacts that do NOT belong in evo-skillopt:

- `clow-agents/backend/evo-metaclaw/` — Clow-specific orchestrator
   (reference impl only; when we build the product-neutral EvoOrchestrator
    in Q2, we'll port patterns from this)
- `clow-agents/backend/{gtm-engine,security-agent}/` — Clow-specific services
- `clow_landing.html`, `use_cases.html`, `dashboard.html` — Clow UI
- `bots/*` — Clow marketplace inventory (copied to evo-skillopt/examples/
   as reference bot templates)
- `MARKETING.md`, `Clow_GTM_Blueprint.md`, `X_THREADS.md`, `EvoMetaClaw.md`,
  `CLOW.md`, `DEPLOY.md`, `vercel.json`, `api/*.js` — all Clow-specific

The source branch stays intact as the reference implementation for Clow.
MD

# ─── SUMMARY ────────────────────────────────────────────────────────────
ok "Seed assembled at: $DEST"
echo ""
echo "Contents:"
find "$DEST" -maxdepth 3 -type f 2>/dev/null | sed "s|$DEST/|  |" | sort
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo " Next steps (see MIGRATE.md for details)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "  1. Inspect the seed:                cd $DEST && ls -R"
echo "  2. Create the repo:                 gh repo create your-github/evo-skillopt --private"
echo "  3. Push:                            cd $DEST && git init && git add . && git commit -m 'chore: initial commit' && git remote add origin git@github.com:your-github/evo-skillopt.git && git push -u origin main"
echo "  4. Add SkillOpt submodule:          git submodule add https://github.com/microsoft/SkillOpt skillopt"
echo ""
echo "Read $DEST/EvoSkillOpt_Blueprint.md first."
