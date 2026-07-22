# Self-Hosted Deployment Guide

**Audience:** Self-hosters running `INSTANCE_ID=self_hosted` on their own machine.  
**Quick start:** [`deploy/selfhost/README.md`](../deploy/selfhost/README.md) — start there.  
**This document:** Operational deep-dive: account management, backups, AI configuration, Obsidian, and troubleshooting.

---

## Contents

1. [Capability matrix](#1-capability-matrix)
2. [Instance identity & gating summary](#2-instance-identity--gating-summary)
3. [First boot & account setup](#3-first-boot--account-setup)
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

## 3. First boot & account setup

On first boot the appliance verifies your membership with the cloud, then
creates your local account using your `GLASSY_MEMBER_EMAIL` and prints the
initial password once. The password is **also written to a file** so you can
recover it even if the Docker log buffer has rolled:

```bash
# Option A — grep the logs (first boot ONLY — see warning below):
docker compose logs glassy | grep -A2 "Default admin created"

# Option B — read the credentials file (survives container recreation,
# deleted automatically after your first password change):
docker exec glassy cat /app/data/.initial_admin_password
```

You will see something like:

```
⚠️  Default admin created. Credentials (change immediately):
   Username: you@example.com
   Password: <22-char-base64url>
```

> ⚠️ **The password line only appears on the true first boot** — when the
> `users` table is completely empty. If the `glassy-data` volume persisted
> from a previous run (e.g. you ran `docker compose down` without `-v`), no
> new password is printed and your existing admin password is unchanged.
> Use the file fallback above, or to start completely fresh see
> [Reset everything](#reset-everything-nuclear-option).

Sign in at http://localhost:3000 with your membership email and that password.
You will be **immediately forced to set a permanent password** before you can
use the workspace — the random one is discarded after that, and the
`/app/data/.initial_admin_password` file is deleted on first successful
change.

The initial generated password is not stored in plaintext anywhere after it
is displayed — only its bcrypt hash lives in the local database.

If you are locked out and the file fallback is gone, see [Account recovery](#5-account-recovery-lost-password).

### Admin seeding behaviour

The seed only runs when no `users` row exists with `is_admin=1`. On subsequent boots it is a no-op — your admin account (and any changes you made to it) is preserved.

### How authentication works (and what the cloud sees)

Glassy self-host is a **single-owner appliance** — the appliance and the cloud
are two separate systems that share only two things: your email address and a
pairing token you control. Here's the full flow:

**1. Membership + pairing-token verification (boot, every 30 days).** The
appliance sends a server-to-server POST to `<GLASSY_VERIFY_CLOUD_URL>/api/verify-selfhost`
(default `https://app.glassy.fyi/api/verify-selfhost`; Clear members should set
it to `https://clear.glassy.fyi/api/verify-selfhost`) with body
`{ "email": "you@example.com", "selfhostToken": "<your pairing token>" }`.
**No password, no session data, no note content is ever sent.** The cloud looks
up the email, confirms the membership is active, and verifies the token matches
the one stored hashed in your account. It returns one of:

- `{ valid: true, tier: "clear_lifetime", ts, nonce, signature }` — active
  membership + token match. `signature` is an HMAC over `(email|tier|ts|nonce)`
  so the cached result cannot be forged on your disk.
- `{ valid: false }` — any failure (no account, no membership, missing/mismatched
  token). The endpoint deliberately does **not** distinguish reasons to prevent
  email + membership enumeration. The specific reason is logged server-side only.

Generate the pairing token in your Glassy account on the cloud:
**Settings → Self-hosting → Generate token**.
  • Public / Pro members: https://app.glassy.fyi/#/settings?g=account&s=selfhost
  • Clear members:        https://clear.glassy.fyi/#/settings?g=account&s=selfhost
Paste it into `GLASSY_SELFHOST_TOKEN` in `.env`. If you generated the token on
Clear, also set `GLASSY_VERIFY_CLOUD_URL=https://clear.glassy.fyi` so the
appliance verifies against the correct cloud instance. Rotate the token any time
from the same page (the old token stops working on the next 30-day re-verification,
or immediately if you destroy the cache).

The endpoint is rate-limited (10 requests per IP per 15 minutes). The result is
cached to `.membership_cache.json` in the data volume for 30 days when signed,
or 24 hours when unsigned. If the cloud is unreachable, the appliance falls back
to the cache (signed caches accepted indefinitely offline; unsigned caches up to
7 days past expiry as a degraded-mode safety net) and warns in the logs. If no
usable cache exists, the container exits with code 1.

**2. Admin account created (first boot only).** If the `users` table is empty,
the appliance creates a local admin account:

- **Email** = your `GLASSY_MEMBER_EMAIL` (so you can log in with your real address)
- **Password** = a 22-character random string generated with `crypto.randomBytes(16)`,
  bcrypt-hashed (cost 12) and stored as a hash. The plaintext is printed to
  stdout **once** and written to `/app/data/.initial_admin_password` (chmod 600)
  so you can recover it if the log buffer rolls. The file is deleted on your
  first successful password change.
- **Tier** = `clear_lifetime` — unlocks all premium features via the existing
  `isClearMember()` entitlement path. No commerce flow, no credit ledger.
- **`password_must_change=1`** — forces a one-time password change on first
  login so you set a permanent password regardless of how you discovered the
  random one.

You retrieve the password with `docker exec glassy cat /app/data/.initial_admin_password`
(or grep the logs on the very first boot), sign in, and set a permanent password
when prompted. After that, the generated password is irrelevant — only your new
password's hash matters.

**3. Ongoing authentication (every login).** Entirely local. You POST
`{ email, password }` to `/api/login`; the server looks up the email in the
local SQLite `users` table, compares the bcrypt hash, and issues a JWT signed
with your `JWT_SECRET`. No cloud call, no network dependency. The cloud never
sees your password, your JWT, or any of your note content — it only confirmed
your membership and token once at boot.

```
Your .env: GLASSY_MEMBER_EMAIL=you@example.com
          GLASSY_SELFHOST_TOKEN=<pairing token>
        │
        ▼
  ┌─────────────────────────────────┐
  │ Boot (every 30 days)            │
  │ POST /api/verify-selfhost        │  ← email + pairing token, no password
  │ Cloud checks: membership + token │
  └────────────┬────────────────────┘
               │ valid: true, tier, signed cache
               ▼
  ┌─────────────────────────────────┐
  │ First boot only                  │
  │ Create local admin account       │  ← random password printed + saved to
  │ email = GLASSY_MEMBER_EMAIL      │     /app/data/.initial_admin_password
  │ tier  = clear_lifetime           │     bcrypt hash in local SQLite
  │ must_change = 1                  │     forced change on first login
  └────────────┬────────────────────┘
               │
               ▼
  ┌─────────────────────────────────┐
  │ First login                      │
  │ Forced password-change screen    │  ← set permanent password, file deleted
  └────────────┬────────────────────┘
               │
               ▼
  ┌─────────────────────────────────┐
  │ Every login after that          │
  │ POST /api/login (local only)     │  ← 100% offline, JWT auth
  │ bcrypt compare → JWT signed       │     no cloud, no phone-home
  └─────────────────────────────────┘
```

**Security notes:**

- The cloud endpoint cannot leak your password — it never receives one.
- The pairing token prevents anyone who merely knows your email from spinning
  up an unlocked instance using your membership. Keep it private; rotate it if
  it leaks.
- The membership cache is HMAC-signed by the cloud; a forged cache file on your
  disk will fail signature verification and degrade to a 24h TTL (or be rejected
  if unsigned and older than 7 days past expiry).
- The `JWT_SECRET` in your `.env` is the only signing key for session tokens.
  Rotate it by editing `.env` and restarting (this invalidates all existing sessions).
- The membership cache file (`.membership_cache.json`) contains your email, the
  tier string, a timestamp, a nonce, and an HMAC signature — no passwords, no
  tokens, no secrets beyond the signature itself.

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
db.prepare('UPDATE users SET password_hash = ? WHERE email = ?').run(hash, 'target@example.com');
console.log('Done');
"
```

Replace `target@example.com` with the sub-account's email and `NewPassword123!` with a new temporary password, then have the user change it in Settings.

> **The `users` table uses `email`, not `username`.** The admin account's email is your `GLASSY_MEMBER_EMAIL`, not `admin`.

### Option B — Docker exec (admin locked out)

If the admin account itself is inaccessible, use `docker exec` to reset the password directly in the database. The runtime image already includes `bcryptjs`, so no host-side tools are needed:

```bash
# Stop the container first to avoid write conflicts:
docker compose down

# Reset the admin password (replace TempPass123! with your new password
# and your GLASSY_MEMBER_EMAIL with the actual admin email):
docker run --rm -v glassy-selfhost_glassy-data:/app/data \
  --entrypoint node ghcr.io/0reliance/glassy-dash:latest -e "
const Database = require('better-sqlite3');
const bcrypt = require('bcryptjs');
const db = new Database('/app/data/notes.db');
const hash = bcrypt.hashSync('TempPass123!', 12);
db.prepare('UPDATE users SET password_hash = ? WHERE email = ?').run(hash, 'your.member@email.com');
console.log('Password reset for your.member@email.com');
db.close();
"

docker compose up -d
```

> **The volume path differs by Docker backend.** On Docker Desktop (WSL2/macOS), the volume is inside the Docker VM — don't try to access it via `/var/lib/docker/volumes` on the host. The `docker run` command above works on all platforms because it mounts the named volume directly.
>
> **The `users` table has an `email` column, not `username`.** The admin email is your `GLASSY_MEMBER_EMAIL`.

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
3. In Glassy: Settings → AI → **Ollama** — Glassy auto-detects models from `http://host.docker.internal:11434`

The `OLLAMA_BASE_URL` env var defaults to `http://host.docker.internal:11434` (reaches Ollama running on the host via Docker's host gateway). The server automatically appends `/v1` if it's missing, so both `http://host.docker.internal:11434` and `http://host.docker.internal:11434/v1` work. If you're using the bundled sidecar overlay, use `http://ollama:11434` instead. Override in `.env` if Ollama runs on a different port or host.

**No Ollama installed?** Use the bundled sidecar overlay so there's nothing extra to install on the host:

```bash
docker compose -f docker-compose.yml -f docker-compose.ollama.yml up -d
docker compose -f docker-compose.yml -f docker-compose.ollama.yml exec ollama ollama pull llama3.2
```

The overlay points Glassy at the sidecar automatically (`OLLAMA_BASE_URL=http://ollama:11434`) and supports NVIDIA GPUs (see [`deploy/selfhost/docker-compose.ollama.yml`](../deploy/selfhost/docker-compose.ollama.yml)).

---

## 7. Obsidian live sync

Live Obsidian vault sync is the primary reason to self-host. The cloud server cannot reach `127.0.0.1` on your machine; a local install can.

### Two connection paths

| Path | Works on | How |
|------|----------|-----|
| **Browser extension bridge** (recommended) | All platforms, required on Windows/WSL2 | Extension proxies requests from server → browser → Obsidian |
| **Direct server→Obsidian** | Native Linux, macOS, Docker-on-Linux | Server reaches `host.docker.internal:27124` directly |

On **Windows with WSL2/Docker Desktop**, only the browser extension bridge works — the container cannot reach the Windows host's `127.0.0.1`. The server's Obsidian settings panel (URL, Test Connection, Diagnostics) is hidden on self-hosted instances because those controls run server-side and would always fail from inside the container. The extension is the canonical source for the Obsidian URL and API key on self-host.

### Setup on Windows/WSL2 (the bridge path)

1. **Install Obsidian Local REST API plugin** (v4.0+) in your Obsidian desktop app. Note the API key and the URL (HTTPS `127.0.0.1:27124` or HTTP `127.0.0.1:27123`).
2. **Install the Glassy Companion** browser extension (Chrome or Firefox).
3. **Sign in** to the extension with your Glassy account (same email as your self-hosted appliance).
4. **Open the extension popup** → Settings → **Obsidian Bridge**:
   - Set **Obsidian URL** to your plugin URL (e.g. `http://127.0.0.1:27123` — HTTP avoids self-signed cert issues).
   - Paste the **API Key** from the Obsidian plugin.
   - Toggle **Obsidian Bridge** on.
   - Click **Test Connection** — this tests the FULL bridge loop (server → extension → Obsidian), not just extension→Obsidian. A green result with "plugin v4.x" confirms both legs work.
   - Click **Save**.
5. **Verify on the server**: open `http://localhost:3000` in your browser, sign in, go to Settings → Obsidian. You should see "✓ Extension bridge active — Obsidian connected." The URL/token fields are hidden because the extension manages them.
6. **Verify via API** (optional): `curl -H "Authorization: Bearer <your-jwt>" http://localhost:3000/api/ext/obsidian-bridge/status` should return `{"connected":true,...}`.

The extension maintains a persistent SSE connection to the server (via the offscreen document, which Chrome does not evict). When the server needs Obsidian data (AI context, vault browsing, search), it pushes a request to the extension, which calls Obsidian on `127.0.0.1:27124` directly and returns the result. The extension holds the API key locally — it is never sent to the server.

### Setup on native Linux/macOS (direct path)

The compose file includes `OBSIDIAN_HOST_OVERRIDE=host.docker.internal`, which rewrites `127.0.0.1` references so the container can reach the Obsidian desktop app running on the host. This works out of the box on **native Linux and macOS**. Configure the URL and API key in Settings → Obsidian on the web app.

> **⚠️ Windows + WSL2 users:** `host.docker.internal` inside the container resolves to the **WSL2 VM**, not the Windows host. The container cannot reach Obsidian running on Windows `127.0.0.1` this way. Use the **browser extension bridge** (steps above). See [`deploy/selfhost/README.md` § Obsidian vault sync](../deploy/selfhost/README.md#obsidian-vault-sync) for the full WSL2 setup guide.

### Troubleshooting Obsidian connectivity

- **Extension says "Bridge connected" but server says not connected:** This was a known issue in older extension versions where the SSE connection lived in the MV3 service worker (which Chrome evicts after ~30s). Update to extension v2.13.0+ which moves the SSE into the offscreen document (persistent, never evicted). Verify with `curl -H "Authorization: Bearer <jwt>" http://localhost:3000/api/ext/obsidian-bridge/status`.
- **Test Connection in extension is green but Obsidian features don't work:** The Test Connection button tests the full bridge loop. If it's green, both legs work. If features still fail, check the server logs for `ECONNREFUSED` (direct fallback failing — expected on WSL2) and verify `CLUSTER_WORKERS=1` is set in the container env (`docker exec glassy env | grep CLUSTER`).
- **Container can't reach Obsidian plugin (Linux/macOS direct path):** verify `host.docker.internal` resolves. On Linux, the `extra_hosts: ['host.docker.internal:host-gateway']` in the compose file handles this; Docker Desktop (Mac/Windows) includes it automatically.
- **WSL2 (`host.docker.internal` → WSL VM, not Windows):** use the browser extension bridge (see Setup above). See [`deploy/selfhost/README.md` § Browser Extension Bridge](../deploy/selfhost/README.md#1-browser-extension-bridge-recommended-for-windowswsl2).
- **Obsidian on a different machine (LAN/Tailscale):** set `OBSIDIAN_NETWORK_ALLOWLIST` to the Obsidian host's IP or hostname in `.env`. The plugin must bind to `0.0.0.0` instead of `127.0.0.1` (see [`deploy/selfhost/README.md` § Network allowlist](../deploy/selfhost/README.md#3-network-allowlist-split-machine-setups)).
- **`APP_URL` mismatch:** if you access Glassy from a hostname other than `localhost`, set `APP_URL` and `CORS_ORIGINS` accordingly (see [multi-device access](../deploy/selfhost/README.md#multi-device-access-tailscale--cloudflare-tunnel--netbird)).
- **Self-signed cert errors:** use `http://127.0.0.1:27123` (HTTP port) instead of `https://127.0.0.1:27124` in the extension settings. The Obsidian plugin serves both ports by default.

---

## 8. Backup & restore

All persistent data lives in the `glassy-data` Docker volume (the `notes.db` SQLite file).

> **Built-in automatic backups.** Glassy already takes a daily SQLite backup at 02:00 into `/app/data/backups` (inside the volume, ~7 days retained) — no setup needed. For encrypted, off-machine copies use the backup CLI (`node server/utils/backup.js`, controlled by `BACKUP_ENCRYPTION_KEY` / `BACKUP_RETENTION_DAYS`). See [`deploy/selfhost/README.md` § Data persistence, backups & restore](../deploy/selfhost/README.md). The full-volume snapshot below is the simplest way to capture everything (DB, uploads, and generated backups) in one archive.

### Backup

```bash
# Creates glassy-backup-YYYYMMDD.tar.gz in the current directory
docker run --rm \
  -v glassy-selfhost_glassy-data:/data \
  -v "$(pwd)":/backup \
  alpine tar czf /backup/glassy-backup-$(date +%Y%m%d).tar.gz -C /data .
```

Schedule this with cron for automated daily backups:

```cron
0 3 * * * docker run --rm -v glassy-selfhost_glassy-data:/data -v /path/to/backups:/backup alpine tar czf /path/to/backups/glassy-backup-$(date +\%Y\%m\%d).tar.gz -C /data .
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
cd glassy/deploy/selfhost
docker compose pull
docker compose up -d
```

Database migrations apply automatically on start. There is no downtime during a rolling update (the old container keeps serving until the new one is healthy).

To pin a specific version instead of tracking `latest`, set `GLASSY_TAG=v2.35.0` in `.env`.

**Hands-off updates (optional).** Add the Watchtower overlay to pull and apply new `:latest` images automatically (daily poll):

```bash
docker compose -f docker-compose.yml -f docker-compose.watchtower.yml up -d
```

### Rollback

```bash
GLASSY_TAG=v2.35.0-beta.7 docker compose up -d
```

Or set `GLASSY_TAG=v2.35.0-beta.7` in `.env` and re-run `docker compose up -d`.

---

## 10. Security hardening

### Secrets

- `JWT_SECRET` and `API_KEY_ENCRYPTION_KEY` are **required**. Generate with `openssl rand -hex 32`. Store them in `.env`, which is excluded from version control.
- Rotate `JWT_SECRET` by updating `.env` and restarting the container. All existing sessions are invalidated.
- Do not set `SENTRY_DSN` — telemetry is not appropriate for a private appliance, and the server ignores it on `self_hosted` regardless.

### Network exposure

- By default Glassy binds to `0.0.0.0:3000` on the host. On a single-user machine, use a firewall to restrict access to `127.0.0.1:3000` unless you need LAN/Tailscale access.
- Do not expose port 3000 directly to the public internet without TLS in front (Cloudflare Tunnel or a local nginx reverse proxy).

### TLS (optional)

For a public hostname, run Cloudflare Tunnel or add nginx in front:

```nginx
server {
    listen 443 ssl;
    server_name glassy.example.com;
    ssl_certificate     /etc/letsencrypt/live/glassy.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/glassy.example.com/privkey.pem;
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Set `TRUST_PROXY=1` in `.env` when behind a reverse proxy.

---

## 11. Troubleshooting

### Container won't start

```bash
docker compose logs glassy
```

Common causes:
- `JWT_SECRET` or `API_KEY_ENCRYPTION_KEY` not set → look for `set JWT_SECRET` / `set API_KEY_ENCRYPTION_KEY` in the log.
- Port 3000 already in use → set `APP_PORT=3001` in `.env` **and** update `APP_URL` and `CORS_ORIGINS` to match (e.g. `http://localhost:3001`).

> **⚠️ If you change `APP_PORT`, you must also update `APP_URL` and `CORS_ORIGINS` to the same port.** Leaving them at `http://localhost:3000` while `APP_PORT=3005` will cause CORS failures and broken login redirects.

### Login page says "registration disabled"

This is expected. Registration is permanently disabled on the self-hosted appliance. Log in with the admin account (see [First boot](#3-first-boot--admin-account)).

### Checking health from outside the container

The container exposes a JSON health endpoint. The **canonical endpoint** (used by the Docker healthcheck) is:

```bash
curl http://localhost:3000/api/monitoring/ready
```

Returns `{"status":"ready", ...}` when healthy. There is also a convenience alias:

```bash
curl http://localhost:3000/ready
```

Both return JSON when the server is up. If you get HTML instead of JSON, the
SPA catch-all is responding — the container may still be starting up. Wait a
few seconds and retry. The runtime image includes `curl` for in-container
network diagnostics (`docker compose exec glassy curl …`).

### AI features not working

1. **BYOK path:** Settings → AI → API Keys — verify your key is saved and the correct provider is selected.
2. **Ollama path:** run `ollama list` on the host to verify a model is installed. Check `OLLAMA_BASE_URL` in `.env` (default `http://host.docker.internal:11434`).
3. **No provider configured:** the app returns a clear error: "No AI provider configured. Add your own API key in Settings → API Keys, or run a local Ollama model."

### Obsidian sync not connecting

See [Obsidian live sync § Troubleshooting](#troubleshooting-obsidian-connectivity).

### "Store" or "Upgrade" redirect to Settings

Expected. Commerce surfaces are not available on the self-hosted appliance — all premium features are already unlocked.

### Container healthy but app shows errors

```bash
# Check database integrity
docker exec glassy sqlite3 /app/data/notes.db "PRAGMA integrity_check;"
# Should print: ok
```

### Reset everything (nuclear option)

```bash
# -v removes the named volume too (without it, your account persists and the
# admin password line will NOT be re-printed on the next boot):
docker compose down -v
docker compose up -d
# A fresh admin account will be seeded on first boot.
```

> **`docker compose down` without `-v` keeps the `glassy-data` volume.** That
> is usually what you want (it preserves your account and notes), but if your
> goal is a true reset you MUST add `-v` — otherwise the admin seeding block
> sees a non-empty `users` table and skips, so no password is printed and your
> old admin password is the only way in.

> **This is irreversible if you have no backup.** See [Backup & restore](#8-backup--restore).
