# Self-Hosted Deployment Guide

**Audience:** Self-hosters running `INSTANCE_ID=self_hosted` on their own machine.  
**Quick start:** [README.md](README.md) — start there.  
**This document:** Operational deep-dive: account management, backups, AI configuration, Obsidian, and troubleshooting.

---

## Contents

1. [Capability matrix](#1-capability-matrix)
2. [Instance identity & gating summary](#2-instance-identity--gating-summary)
3. [First boot & admin account](#3-first-boot--admin-account)
4. [Account management (sub-accounts)](#4-account-management-sub-accounts)
5. [Account recovery (lost password)](#5-account-recovery-lost-password)
6. [AI providers (BYOK + Ollama)](#6-ai-providers-byok--ollama)
7. [Obsidian live sync](#7-obsidian-live-sync)
8. [Backup & restore](#8-backup--restore)
9. [Upgrading](#9-upgrading)
10. [Security hardening](#10-security-hardening)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Capability matrix

| Capability | Cloud (`app.glassy.fyi`) | Self-hosted |
|---|---|---|
| Notes, tags, folders, trash | ✅ | ✅ |
| GlassyKeep (Markdown knowledge base) | Pro only | ✅ unlocked |
| GlassyCalc (spreadsheet) | Pro only | ✅ unlocked |
| Custom themes | Pro only | ✅ unlocked |
| Voice Studio | Pro only | ✅ unlocked |
| Knowledge base (KB) | Pro only | ✅ unlocked |
| MCP server + Second Brain | Pro only | ✅ unlocked |
| Agent Gateway (OpenClaw / Hermes) | Pro only | ✅ unlocked |
| Companion browser extension | ✅ | ✅ |
| Capture pipeline | ✅ | ✅ |
| Data export (JSON, Obsidian ZIP, GDPR) | ✅ | ✅ |
| Live Obsidian vault sync | ❌ (server ≠ localhost) | ✅ |
| Ollama local AI | ❌ | ✅ |
| BYOK (your own API keys) | ✅ | ✅ (only AI path) |
| Cloud metered AI (Gemini/OpenAI/Anthropic system keys) | ✅ | ❌ disabled |
| AI credit metering / top-ups | ✅ | ❌ no-op (unlimited BYOK) |
| Stripe / commerce / upgrade funnel | ✅ | ❌ not mounted |
| Web push notifications | ✅ | ❌ disabled (no FCM/APNs offline) |
| Transactional email | ✅ | ❌ disabled (nothing leaves the machine) |
| Google OAuth | ✅ | ❌ disabled |
| Registration | ✅ | ❌ permanently disabled |
| Telemetry (Sentry) | ✅ | ❌ not initialised |
| Sub-accounts (multiple workspaces, one owner) | ✅ | ✅ |
| Linked accounts (cross-user email linking) | ✅ | ❌ disabled |

---

## 2. Instance identity & gating summary

Setting `INSTANCE_ID=self_hosted` in `docker-compose.yml` activates the single-user appliance mode. The following gates are **enforced server-side** and cannot be overridden by environment variables:

| Gate | Behaviour |
|---|---|
| `/api/auth/register` | Hard 403 `REGISTRATION_DISABLED` — first check, before any admin setting. |
| `/api/commerce/*` and `/api/stripe/*` | Routes not mounted → 404. |
| `/api/push/*` (web push) | Routes not mounted → 404. |
| `/api/auth/oauth/status` | Always returns `{google: false}`. |
| `/api/accounts/link/request` and `/link/verify` | 403 `LINKING_DISABLED`. |
| `PATCH /api/admin/settings` | Mutations to `allowNewAccounts` and `instanceAccessMode` silently rejected; server re-enforces them on every boot. |
| `sendEmail()` | Returns early without any network call, even if `RESEND_API_KEY` is set. |
| Sentry | Not initialised, even if `SENTRY_DSN` is set. |
| Cloud system AI keys | Not loaded at startup. Only BYOK (`/api/api-keys`) and Ollama work. |
| `deductAiCredits()` | No-op — no credit ledger exists on the appliance. |

The seeded admin is automatically granted `clear_lifetime` tier, which unlocks every premium feature through the existing `isClearMember()` entitlement path.

---

## 3. First boot & admin account

On first boot the server seeds one admin account and prints the generated credentials to the container log **once**:

```bash
docker compose logs glassy | grep -A2 "Default admin created"
```

You will see something like:

```
Default admin created — username: admin  password: <generated>
```

**Change the password immediately** in Settings → Account. The generated password is not stored anywhere after it is displayed.

If you miss the initial log output, see [Account recovery](#5-account-recovery-lost-password).

### Admin seeding behaviour

The seed only runs when no `users` row exists with `is_admin=1`. On subsequent boots it is a no-op — your admin account (and any changes you made to it) is preserved.

---

## 4. Account management (sub-accounts)

The self-hosted appliance supports **sub-accounts** — multiple isolated workspaces under the same owner, switchable without logging out. This works entirely offline; no SMTP or cloud connectivity required.

To create a sub-account:

1. Settings → Accounts → **Add account**
2. Choose a username + password
3. Switch between accounts from the sidebar or Settings → Accounts

Sub-accounts share the same Docker volume (`glassy-data`) but have fully isolated note stores, settings, and AI keys.

> **Account linking is disabled.** Account linking (`/accounts/link/*`) requires email verification and has no place on an offline appliance. Use sub-accounts instead.

---

## 5. Account recovery (lost password)

Email-based password reset is disabled on the self-hosted appliance (email is off). Use one of the following recovery paths:

### Option A — Admin resets another account's password

If you are logged in as admin and a sub-account user has lost their password:

```bash
docker exec -it glassy node -e "
const db = require('./server/db');
const bcrypt = require('bcryptjs');
const hash = bcrypt.hashSync('NewPassword123!', 12);
db.prepare('UPDATE users SET password_hash = ? WHERE username = ?').run(hash, 'TARGET_USERNAME');
console.log('Done');
"
```

Replace `TARGET_USERNAME` and `NewPassword123!` with the target username and a new temporary password, then have the user change it in Settings.

### Option B — SQLite direct (admin locked out)

If the admin account itself is inaccessible, stop the container and edit the database directly:

```bash
docker compose down
# Default volume path on Linux:
# /var/lib/docker/volumes/glassy-selfhost_glassy-data/_data/notes.db
sqlite3 /var/lib/docker/volumes/glassy-selfhost_glassy-data/_data/notes.db \
  "UPDATE users SET password_hash = '\$(python3 -c \"import bcrypt; print(bcrypt.hashpw(b'Temp1234!', bcrypt.gensalt(12)).decode())\")'
   WHERE username = 'admin';"
docker compose up -d
```

### Option C — Secret recovery key

Glassy supports a **secret recovery key** (a local fallback independent of email). If you set one up in Settings → Security before losing access, use it via the **"Use secret recovery key"** link on the login screen.

---

## 6. AI providers (BYOK + Ollama)

### BYOK (bring your own API key)

Cloud system keys are not loaded on the self-hosted appliance. To use cloud AI:

1. Obtain a key from the provider (Google AI Studio, OpenAI, Anthropic, etc.)
2. Settings → AI → **API Keys** → add your key
3. Keys are encrypted at rest using `API_KEY_ENCRYPTION_KEY`

Supported providers: Gemini, OpenAI, Anthropic, Mistral, and any OpenAI-compatible endpoint.

> BYOK calls are billed to **your** provider account. There is no credit ledger or metering on the appliance.

### Local AI with Ollama

Ollama is already reachable via `host.docker.internal` without any configuration change. To use it:

1. Install Ollama on the host: https://ollama.com
2. Pull a model: `ollama pull llama3.2` (or any supported model)
3. In Glassy: Settings → AI → **Ollama** — Glassy auto-detects models from `http://localhost:11434`

The `OLLAMA_BASE_URL` env var defaults to `http://localhost:11434` (mapped to `host.docker.internal:11434` inside the container). Override in `.env` if Ollama runs on a different port or host.

**No Ollama installed?** Use the bundled sidecar overlay so there's nothing extra to install on the host:

```bash
docker compose -f docker-compose.yml -f docker-compose.ollama.yml up -d
docker compose -f docker-compose.yml -f docker-compose.ollama.yml exec ollama ollama pull llama3.2
```

The overlay points Glassy at the sidecar automatically (`OLLAMA_BASE_URL=http://ollama:11434`) and supports NVIDIA GPUs (see [`docker-compose.ollama.yml`](docker-compose.ollama.yml)).

---

## 7. Obsidian live sync

Live Obsidian vault sync is the primary reason to self-host. The cloud server cannot reach `127.0.0.1` on your machine; a local install can.

### Setup

1. Install the **Glassy Companion** browser extension (see [glassy-companion](https://github.com/0Reliance/glassy-companion) or the Firefox/Chrome store listing).
2. In Companion settings, set the **Server URL** to `http://localhost:3000` (or your Tailscale / LAN URL — see [multi-device access](README.md#multi-device-access-tailscale--cloudflare-tunnel--netbird)).
3. In Glassy: Settings → **Obsidian** → enable sync and point it at your vault path.

The compose file includes `OBSIDIAN_HOST_OVERRIDE=host.docker.internal`, which rewrites `127.0.0.1` references so the container can reach the Obsidian desktop app running on the host. No extra configuration is needed for a single-machine setup.

### Troubleshooting Obsidian connectivity

- **Container can't reach Obsidian plugin:** verify `host.docker.internal` resolves. On Linux, the `extra_hosts: ['host.docker.internal:host-gateway']` in the compose file handles this; Docker Desktop (Mac/Windows) includes it automatically.
- **`APP_URL` mismatch:** if you access Glassy from a hostname other than `localhost`, set `APP_URL` and `CORS_ORIGINS` accordingly (see [multi-device access](README.md#multi-device-access-tailscale--cloudflare-tunnel--netbird)).

---

## 8. Backup & restore

All persistent data lives in the `glassy-data` Docker volume (the `notes.db` SQLite file).

> **Built-in automatic backups.** Glassy already takes a daily SQLite backup at 02:00 into `/app/data/backups` (inside the volume, ~7 days retained) — no setup needed. For encrypted, off-machine copies use the backup CLI (`node server/utils/backup.js`, controlled by `BACKUP_ENCRYPTION_KEY` / `BACKUP_RETENTION_DAYS`). See [README.md § Data persistence, backups & restore](README.md). The full-volume snapshot below is the simplest way to capture everything (DB, uploads, and generated backups) in one archive.

### Backup

```bash
docker run --rm \
  -v glassy-selfhost_glassy-data:/data \
  -v "$(pwd)":/backup \
  alpine tar czf /backup/glassy-backup-$(date +%Y%m%d).tar.gz -C /data .
```

### Restore

```bash
docker compose down
docker volume rm glassy-selfhost_glassy-data
docker volume create glassy-selfhost_glassy-data
docker run --rm \
  -v glassy-selfhost_glassy-data:/data \
  -v "$(pwd)":/backup \
  alpine tar xzf /backup/glassy-backup-YYYYMMDD.tar.gz -C /data
docker compose up -d
```

> Database migrations run automatically on container start. Restoring an older backup and starting a newer image is safe — forward migrations will be applied.

---

## 9. Upgrading

```bash
cd glassy-selfhost
docker compose pull
docker compose up -d
```

Database migrations apply automatically on start.

To pin a specific version instead of tracking `latest`, set `GLASSY_TAG=v2.35.0` in `.env`.

**Hands-off updates (optional).** Add the Watchtower overlay to pull and apply new `:latest` images automatically (daily poll):

```bash
docker compose -f docker-compose.yml -f docker-compose.watchtower.yml up -d
```

### Rollback

```bash
GLASSY_TAG=v2.34.2 docker compose up -d
```

---

## 10. Security hardening

### Secrets

- `JWT_SECRET` and `API_KEY_ENCRYPTION_KEY` are **required**. Generate with `openssl rand -hex 32`. Store them in `.env`, which is excluded from version control by `.gitignore`.
- Rotate `JWT_SECRET` by updating `.env` and restarting the container. All existing sessions are invalidated.
- Do not set `SENTRY_DSN` — telemetry is not appropriate for a private appliance, and the server ignores it on `self_hosted` regardless.

### Network exposure

- By default Glassy binds to `0.0.0.0:3000` on the host. On a single-user machine, use a firewall to restrict access to `127.0.0.1:3000` unless you need LAN/Tailscale access.
- Do not expose port 3000 directly to the public internet without TLS in front (use the Caddy overlay or Cloudflare Tunnel — see [README.md](README.md)).
- If running behind a reverse proxy, set `TRUST_PROXY=1` in `.env`.

### Backup key

- If you set `BACKUP_ENCRYPTION_KEY`, store it somewhere safe **off the machine** — a password manager, printed paper, or a separate encrypted drive. Without it, encrypted backups cannot be restored.

---

## 11. Troubleshooting

### Container exits immediately

```bash
docker compose logs glassy
```

Common causes:
- `JWT_SECRET` or `API_KEY_ENCRYPTION_KEY` not set in `.env`
- `.env` file missing — run `cp .env.example .env` and fill in the secrets

### Can't reach http://localhost:3000

- Verify the container is running: `docker compose ps`
- Check the port is mapped: `docker compose port glassy 8080`
- On Linux, verify no firewall is blocking port 3000

### Obsidian sync not working

See [\u00a77 Obsidian live sync](#7-obsidian-live-sync) and the troubleshooting steps there.

### AI not working

- Local AI (WebGPU): runs in the browser, no server config needed.
- Ollama: verify Ollama is running on the host (`ollama list`), then reload Settings → AI.
- Cloud AI: add your key in Settings → API Keys (not in `.env`).

### Lost admin password

See [\u00a75 Account recovery](#5-account-recovery-lost-password).
