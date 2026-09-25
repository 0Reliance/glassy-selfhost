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
12. [Cloud Sync (cross-instance data sync)](#12-cloud-sync-cross-instance-data-sync)
13. [Push notifications — opt-in on self-host](#13-push-notifications--opt-in-on-self-host)

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
| Agent Gateway (OpenClaw / Hermes) | Pro only | ✅ unlocked — LAN/Tailscale `baseUrl`s allowed on self-host (beta.40, #37); cloud keeps the strict allowlist |
| Companion browser extension | ✅ | ✅ |
| Capture pipeline | ✅ | ✅ |
| Cloud Sync (pair appliance ⇄ cloud) | ✅ (cloud side) | ✅ (appliance side — token pairing, owner-scoped, single-flight scheduler) |
| Sync media transfer (note images, custom backgrounds, voice audio) | Serves available owner-authorized files | Appliance downloads missing files on eligible pull cycles (beta.40); not two-way file replication or checksum-verified transfer. Instance-wide `mediaMissing` counts voice/note images only |
| Custom backgrounds (upload, 3 renditions, dedup by hash) | ✅ (tier-capped) | ✅ unlocked + synced (beta.40: rows via migration 0107 triggers, bytes via media transfer) |
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
| Public Window (publish to the web) | ✅ | ✅ — resolves from the appliance's own origin; private mode still guards anonymous access, and the signed-in owner views their own window (session attached client-side, beta.36) |
| Social previews (OG tags on `/w/:slug`) | ✅ | ✅ mounted, 401 to anonymous crawlers — private mode is enforced before the User-Agent branch |
| Follow Glassy people (social graph) | ✅ | ⚠️ works; following cloud people needs outbound internet |
| Follow external RSS publications | ✅ Pro/Clear unlimited, free ≤10 | ✅ unlimited (local) |
| Content reporting (abuse) | ✅ | ⚠️ mounted but effectively unreachable — there are no anonymous visitors to report content |
| Named per-agent MCP keys (agent identity) | ❌ single shared key | ✅ — one named key per agent, each pinned to a verified identity (`/api/mcp-keys`); authorship, memory and notifications key off the principal, not a self-declared name |
| Agent awareness lane (`glassy_notify`) | ❌ not available | ✅ — notifications + owner surface + 24h/72h review escalation; ≤10 notifications/min per key by design |
| The approval badge on artifacts | ✅ | ✅ — the derived review state rides note reads, so you decide on the work itself |
| Collaboration (per-note collaborators) | ⚠️ | ⚠️ mounted; sub-accounts share one login, cross-user discovery is a no-op on a single-user box |
| Two-factor authentication (TOTP + 10 recovery codes) | ✅ | ✅ — verification accepts ±1 30-second step (beta.42, RFC 6238 §5.2). **The appliance has no cloud NTP of its own:** a Docker host whose clock is more than ~30s out rejects every code from every device, and re-enrolling 2FA will not fix it |
| Note authorship (`last_edited_by`, `created_by`) | ✅ | ✅ — `created_by` is write-once and survives edits (beta.43). MCP writes record the connecting client's `clientInfo.name`, falling back to `MCP agent`. Publish/takedown deliberately does **not** stamp an editor |
| Bookmark authorship | ✅ | ✅ — same three columns (migration 0109, beta.43). Content writes go through `bookmarkService`. A takedown is not an edit |
| Document authorship | ✅ | ✅ — same three columns (migration 0110, beta.43). Content create/update and the public toggle go through `documentService`. Archive, pin and account move stay narrow state transitions and do not stamp an editor |
| Write warnings | ✅ | ✅ — a note write that includes a tag render will strip (`<video>` and the sanitizer's other non-allowlist tags) returns `warnings` with code `STRIPPED_AT_RENDER` (beta.43) |
| Note delete / restore | Soft delete to bin | Same, via one service (beta.41). Delete is idempotent; **restore is owner-only** and returns a real `403`; a collaborator's delete unfollows instead of erroring |
| Tag policy | 20 tags × 64 chars | Identical — **one** canonical policy across notes, bookmarks, captures, extension writes, AI auto-tag and MCP (beta.41). Accents, internal spaces and punctuation are preserved; case and surrounding whitespace are normalised; invalid tags are refused with `422 INVALID_TAGS` naming each offender |
| Storage headroom enforcement | Checked before write | Same (beta.41) — capture, the extension's note/document endpoints and the notes POST/PUT/PATCH paths refuse up front rather than writing past quota. Bookmarks are deliberately ungated |
| Memory layer (semantic + keyword + graph) | One lane for all content | One lane (2.37): notes, bookmarks, documents and vault files share ONE memory system — `content_embeddings`, `vault_fts`, and the `note_links` graph. Trashed or archived content is never indexed, and deleting content removes its index rows. The graph accepts every content type — a note's `[[wikilink]]` to another note or document becomes an edge, and the graph MCP tools take node keys (`note:<id>`, `document:<id>`) as well as vault paths |
| Memory rebuild | Automatic | Automatic (2.37): whenever content arrives — including via Cloud Sync — its memory (embeddings, full-text, graph edges) builds on that machine. No manual reindex. `POST /api/kb/backfill/reindex` remains the one-call repair path for a model change or a missed batch; `POST /api/kb/backfill` seeds types in bulk |

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
| `/api/admin/users` (POST) and `/api/admin/users/:id` (DELETE) | 404 — the appliance cannot create or delete users. The single-user invariant is enforced here as well as at `/api/auth/register`; without it the owner (who is admin) could mint arbitrary `users` rows and turn the appliance into the multi-user hosted service the BSL forbids. The admin panel hides "Add User" to match. |
| `POST /api/verify-selfhost` | Not mounted (`index.js:3931-3933`) — an appliance cannot validate other appliances, so it cannot act as a membership oracle. |
| `GET /w/:slug` and `GET /w/:slug/:noteId` (social meta) | 401 in private mode — guarded before the User-Agent branch; a spoofed crawler UA is not a credential. |
| `PATCH /api/admin/settings` | Mutations to `allowNewAccounts` and `instanceAccessMode` silently rejected; server re-enforces them on every boot. The admin panel disables both toggles and explains why, so it no longer reports success for a change the server discarded. |
| `sendEmail()` | Returns early without any network call, even if `RESEND_API_KEY` is set. |
| Sentry | Not initialised, even if `SENTRY_DSN` is set. |
| Cloud system AI keys | Not loaded at startup. Only BYOK (`/api/api-keys`) and Ollama work. |
| `deductAiCredits()` | No-op — no credit ledger exists on the appliance. |

The seeded admin is also granted `clear_lifetime` tier as belt-and-braces, but premium
features do not depend on it: entitlement is **instance-driven** — `INSTANCE_ID=self_hosted`
short-circuits every tier gate in `server/config/tierPolicy.js` (and, since beta.30, the
client mirror in `src/config/tierPolicy.js`), so DB tier drift (a restore, a bad sync) can
never degrade the appliance. Cloud deployments keep every gate.

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

> ⚠️ **The credentials file has TWO lines** — line 1 is the admin **email**,
> line 2 is the **password**. Use only line 2 as the password (copying both
> lines will fail login). To grab just the password:
> `docker exec glassy sed -n 2p /app/data/.initial_admin_password`

### Degraded mode (membership could not be verified)

The appliance **always starts and works**. You buy and you own: if the cloud cannot be
reached, or `GLASSY_MEMBER_EMAIL` / `GLASSY_SELFHOST_TOKEN` are unset or wrong, the
appliance boots in **degraded mode** instead of refusing to start.

Degraded mode is informational and means exactly this:

- Every local feature keeps working, and premium features keep working too — entitlement
  is instance-driven (see §2), not tier-driven, so it does not depend on verification.
- `GET /api/instance` reports `membershipState`, and the boot log explains the cause:

| Value | Meaning |
|---|---|
| `unverified` | Boot has not reached the check yet |
| `verified` | Cloud confirmed the membership (live, or from the signed offline cache) |
| `degraded` | Not confirmed — the appliance is otherwise fully functional |

- Nothing else changes. No service is switched off by degraded mode; the state exists so
  the operator — and future cloud features — can tell a confirmed membership from an
  unconfirmed one.

After a failed live verification the appliance skips the live retry while inside the
backoff window (at most 15 minutes), so a container that restarts for *any* reason cannot
exhaust the cloud's verification rate limit (10 requests / 15 min / IP) — and once that
budget is spent, the cloud rejects even correct tokens for the rest of the window. Fix the
`.env` values and restart; the next boot after the window retries live.

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
usable cache exists, the appliance starts in **degraded mode** (see
[Degraded mode](#degraded-mode-membership-could-not-be-verified)) — the
container no longer exits over a failed verification.

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

#### BYOK and a local Ollama (the "local" option)

The BYOK dialog's **local (localhost:11434)** choice is offered because the form runs in your browser — but the request is made by the **server**, which on an appliance runs inside a container where `localhost` is the container itself. That mismatch used to save successfully and then fail on the first call with `fetch failed`.

That is now handled for you: a loopback address (localhost / 127.0.0.1 / 0.0.0.0 / ::1) is rewritten to `host.docker.internal` automatically when the server is in a container, on both the validation path and the runtime path. A host you name yourself is never rewritten, and `ollama.com` is never rewritten.

- **You probably do not need BYOK for a local daemon at all.** The non-BYOK lane above (`OLLAMA_BASE_URL=http://host.docker.internal:11434`) is what the AI assistant uses by default and works out of the box. BYOK's local option is for a *second* daemon or for `ollama.com` with your own key.
- **To pin a specific host anyway** (a remote GPU box, a sidecar, a different port), set `OLLAMA_HOST_OVERRIDE` in `.env` — it wins over the automatic rewrite, on containers and bare metal alike.
- **The model is probed before it is stored.** Saving with no model no longer writes a hardcoded default your instance has never pulled (which produced an opaque 404 at first use). The instance's real `/api/tags` list is read first; if it cannot be reached, no model is stored and the response says so, rather than inventing one.

### Local AI with Ollama

Ollama is already reachable via `host.docker.internal` without any configuration change. To use it:

1. Install Ollama on the host: https://ollama.com
2. Pull a model: `ollama pull llama3.2` (or any supported model)
3. In Glassy: Settings → AI → **Ollama** — Glassy auto-detects models from `http://host.docker.internal:11434`

`OLLAMA_BASE_URL` is set to `http://host.docker.internal:11434` by
[`deploy/selfhost/docker-compose.yml`](../deploy/selfhost/docker-compose.yml),
which reaches Ollama running on the host via Docker's host gateway. Do not
remove that override: the server's own code default is
`http://localhost:11434/v1`, and inside a container `localhost` is the container
itself, so every embedding request fails with `TypeError: fetch failed`. The
server automatically appends `/v1` if it's missing, so both
`http://host.docker.internal:11434` and `http://host.docker.internal:11434/v1`
work. If you're using the bundled sidecar overlay, use `http://ollama:11434`
instead. Override in `.env` if Ollama runs on a different port or host.

**No Ollama installed?** Use the bundled sidecar overlay so there's nothing extra to install on the host:

```bash
docker compose -f docker-compose.yml -f docker-compose.ollama.yml up -d
docker compose -f docker-compose.yml -f docker-compose.ollama.yml exec ollama ollama pull llama3.2
```

The overlay points Glassy at the sidecar automatically (`OLLAMA_BASE_URL=http://ollama:11434`) and supports NVIDIA GPUs (see [`deploy/selfhost/docker-compose.ollama.yml`](../deploy/selfhost/docker-compose.ollama.yml)).

### Bulk-ingesting an existing vault (`#89`)

The Obsidian bridge indexes files as they change; it cannot seed a vault that
already exists. For that, the instance has a bulk ingest:

```bash
# the vault must be a path THIS SERVER can read — on Docker, mount it in. Declare once:
echo 'VAULT_INGEST_ROOT=/mnt/vault' >> .env

curl -sX POST http://localhost:3000/api/ingest -H "Authorization: Bearer $TOKEN"
# {"jobId":"…","planned":5012,"skippedCount":0}

curl -s "http://localhost:3000/api/ingest/status?jobId=…" -H "Authorization: Bearer $TOKEN"
# {"job":{…,"status":"running"},"counts":{"pending":0,"processing":0,"done":5012,…},"errors":[]}

curl -sX POST http://localhost:3000/api/ingest/<jobId>/cancel -H "Authorization: Bearer $TOKEN"
```

What it guarantees, and why each guarantee exists:

- **Resumable.** Progress is rows, not memory. A restart resumes from where the
  run stopped; a file finished once is never indexed twice. If a worker dies
  mid-batch its claims are returned to the queue after a staleness threshold.
- **Idempotent.** Re-running over an unchanged vault is a **no-op** — every file
  is reported `skipped`, because the indexer already knows which sources are
  synced. You can run it again without fear; you cannot double-embed anything.
- **Honest.** `status` reports counts plus the first errors, and files that could
  not be read are listed rather than silently missing. Nothing is truncated
  without a reported reason.

**Cost, stated plainly:** every newly-indexed file costs one embedding call. On
the cloud provider that is real money at vault scale (thousands of files), which
is why ingest is **explicitly opt-in** — it never runs by itself, and re-runs cost
nothing because there is nothing new to embed. On a local Ollama embedding model
there is no per-file cost, only time.

### Re-indexing embeddings

**Changing the embedding model or provider invalidates every stored vector.**
Vectors are only comparable within the width their model produces:
`gemini-embedding-001` → 768, `nomic-embed-text` → 768, `mxbai-embed-large` → 1024,
`llama3.2:3b` → 3072. After a change, cosine similarity throws on the width
mismatch and the row is skipped — so semantic search quietly returns less (often
nothing) while the API still answers 200.

This applies to `GLASSY_EMBEDDING_MODEL`, `GLASSY_EMBEDDING_PROVIDER` and
`OLLAMA_EMBEDDING_MODEL`.

**Check whether you have drift:**

```bash
curl -s localhost:3000/api/monitoring/ready | jq '.embeddingHealth'
```

`ok: true` means one consistent width is stored. `ok: false` reports
`offReferenceRows` (vectors the current model cannot use), `distinctWidths`, and an
`action` naming the remedy. This field is informational and never flips the
endpoint to `not ready` — a stale index degrades search, it does not stop the
process serving traffic.

**Re-index (destructive; the vectors are derived data and are rebuilt from your
notes, bookmarks, documents and transcripts):**

Back up first — this is the whole point of §8, and here you are deliberately
deleting an index:

```bash
docker compose exec glassy node -e "
  const db = require('./server/db').getDb();
  for (const t of ['content_embeddings','note_embeddings','voice_embeddings',
                   'document_embeddings','bookmark_embeddings','embedding_sync_status']) {
    const n = db.prepare('SELECT COUNT(*) n FROM ' + t).get().n;
    console.log(t, n);
  }
"
```

That counts the rows you are about to drop. Confirm `GLASSY_TAG` is a released
version, take a backup, then clear the index and the sync ledger together —
**both** are required, because backfill only processes items that are not already
recorded as `synced`, so clearing vectors alone leaves them permanently unrebuilt:

```sql
DELETE FROM content_embeddings;
DELETE FROM embedding_sync_status;
DELETE FROM note_embeddings;
DELETE FROM voice_embeddings;
DELETE FROM document_embeddings;
DELETE FROM bookmark_embeddings;
```

Then re-run the backfill — **Settings → Second Brain → Backfill**, or:

```bash
curl -s -X POST localhost:3000/api/kb/backfill \
  -H "Authorization: Bearer <jwt>" -H 'Content-Type: application/json' \
  -d '{"sourceTypes":["note","bookmark","document","voice_transcript"]}'
```

Watch it with `GET /api/kb/backfill-status`, then re-check
`.embeddingHealth` — it should read `ok: true` with a single `distinctWidths` entry.

**Re-index in one call (preferred):** the appliance now ships a reset-and-rebuild
endpoint, surfaced as **Settings → Connections & data → Second Brain → Rebuild
index** (a deliberate two-click arm/confirm button). It clears the same tables as
the SQL below — vectors *and* the sync ledger together — and starts the backfill
immediately:

```bash
curl -X POST localhost:3000/api/kb/backfill/reindex \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true}'
```

The manual SQL below remains the no-API fallback (for example when the server
will not boot). Never hand-edit these tables on the hosted service.

**Scoped re-index — one source only (#92).** Since the per-source width pins, a
model change for ONE source does not force a corpus-wide, billable rebuild. The
endpoint accepts an optional `sourceTypes` array and touches only the named
sources (their vectors, their sync-ledger rows, their legacy tables and their
width pins; every other source's rows survive):

```bash
curl -X POST localhost:3000/api/kb/backfill/reindex \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true, "sourceTypes": ["note"]}'
```

**Per-source width pins (#92).** Migration 0119 pins the expected vector width
per source type (`embedding_source_pins`): the first write establishes it, a
mismatched write RAISES `EMBEDDING_DIMENSION_MISMATCH` naming the source (loud,
not silent), and a query whose width differs from a requested source's pinned
width answers 409 naming that source — search the matching sources or re-index
the named ones. Two widths coexist fine: each source searches with its own
width. Per-source health rides the readiness endpoint:

```bash
curl -s localhost:3000/api/monitoring/ready | jq '.embeddingHealth.bySource'
# [{ "sourceType": "note", "ok": true, "width": 768, "pinnedWidth": 768,
#    "offWidthRows": 0, "lastModelChangeAt": "..." }, ...]
```

`ok: false` for a source means some of its rows disagree with the pin — a scoped
re-index of that source restores it.

### Register external search corpora (federated search, #94)

`glassy_search` can fuse the local index with registered REMOTE search endpoints.
A corpus joins **by config, not code**: a row in `external_corpora`, managed on
self-host at `/api/external-corpora` (cloud answers 403 — external corpora are a
self-host capability). Endpoints are SSRF-validated at registration and again at
every fetch, and the fetch has a 10s hard timeout.

**On the appliance the operator owns the network**, so a LAN IP, a Tailscale node,
loopback and `host.docker.internal` are all valid endpoints — the same posture
Obsidian, calendar feeds and the agent gateway already use. Format and protocol are
still checked (http/https only). On **cloud** the strict posture applies and
registration additionally resolves DNS, so a hostname that only looks public cannot
smuggle a private-IP fetch.

```bash
# A corpus on your LAN, a sibling container, or the Docker host:
curl -X POST localhost:3000/api/external-corpora \
  -H "Authorization: Bearer <token>" -H 'Content-Type: application/json' \
  -d '{"id": "ext-nas", "name": "Home NAS vault", "endpoint": "http://192.168.1.50:8080/search", "dim": 768}'

# Disable a flaky corpus WITHOUT losing its config (search filters enabled = 1):
curl -X PATCH localhost:3000/api/external-corpora/ext-nas \
  -H "Authorization: Bearer <token>" -H 'Content-Type: application/json' \
  -d '{"enabled": false}'
```

The remote endpoint receives `POST { query, limit }` and answers
`{ "results": [{ "sourceId", "title", "content", "score" }] }`. Agents search it
with `glassy_search({ query, corpora: ["local", "ext-nas"], weights: { "ext-nas": 2 } })`
— every result carries its `corpus` attribution, and a corpus that fails is named
in `degraded: []` (never silently omitted). Backlink-aware ranking (a modest
graph-centrality boost, default-on) applies to local note results only.

### Connect your AI agent (MCP)

Running Glassy with an AI agent (Claude, Cursor, Hermes, …)? Give it
[`GIVE-THIS-TO-YOUR-AI-AGENT.md`](https://github.com/0Reliance/glassy-selfhost/blob/main/GIVE-THIS-TO-YOUR-AI-AGENT.md)
from the installer repo root: a self-contained onboarding brief with the MCP endpoint and Bearer auth,
the full 40-tool table, the Obsidian-bridge explainer, ops facts, and first
actions. The self-host compose enables the MCP stack by default.

**Give each agent its own named key.** Both key kinds live in one panel:
**Settings → Connections & data → AI tools (MCP)** ("Connections & data" is the
group, "AI tools (MCP)" is the panel). The instance key sits at the top; the *Named
agent keys* section below it mints one key per agent, each pinned to a verified
identity, and is the only place a named key can be revoked.

A named key is what makes an agent a **principal** rather than a guest: its note
edits are attributed to its own name instead of "MCP agent", `glassy_recall
{ scope: "mine" }` returns only its own memories, and its notifications and digests
are signed. The two key kinds are the same `gky_mcp_…` shape, so an agent verifies
which it holds by reading the `glassy://status` resource (`agent.verified`), not by
looking at the key. Named keys are self-host only — `/api/mcp-keys` answers 403
`FEATURE_NOT_AVAILABLE` on cloud, and `/api/capabilities` reports
`agentIdentity.mode` as `named-keys` here and `single-key` there.

### What the instance can do (`/api/capabilities`)

`/api/instance` answers *who am I*; `/api/capabilities` answers *what can this
instance DO*, so an agent does not have to discover it by probing and getting a
201 that silently does nothing:

```bash
curl -s http://localhost:3000/api/capabilities | jq '.capabilities.notes.renderer.droppedAtRender'
# [ "video", "audio", "iframe", "script", "style", "object", "embed", "form" ]
```

It reports, read from the code that enforces each value: note types, image/item
limits, the renderer allowlists per SURFACE, document limits + route shapes,
accepted upload MIME types (and that video is not served), upload cache
lifetimes, the embedding chunk size and dimensions, the review-loop limits, and
the live MCP tool list.

**The split rule is in the manifest** (v2.40.0): every capability that differs
between the appliance and cloud is gated on the instance identity and reported,
so an agent or a client can tell what this instance offers BEFORE probing:

```bash
curl -s http://localhost:3000/api/capabilities | jq '.capabilities | {agentIdentity, notifications}'
# { "agentIdentity": { "available": true, "mode": "named-keys" },
#   "notifications": { "available": true } }
```

`agentIdentity.mode: "named-keys"` means the appliance accepts named per-agent
MCP keys at `/api/mcp-keys` (each pinned to a verified identity — the key an
agent uses becomes the agent's principal for authorship, memory and
notifications). `notifications.available` means the awareness lane exists here
(`glassy_notify`, the owner surface on the Agent Review page, and the 24h/72h
aging-review escalation). On cloud both report `false`/`single-key`, and the
corresponding endpoints answer 403 `FEATURE_NOT_AVAILABLE`. Clients are expected
to gate on this manifest — the Companion extension does exactly that (fail
closed: any error resolves to "capability absent").

### Renderers are per-surface, with the discard behavior (#75)

The product holds **six** renderer configs, not one. The manifest reports each
one separately with its allowlist AND what happens when you violate it — because
the expensive failure is not the allowlist, it is that violation is *silent*:

```bash
curl -s http://localhost:3000/api/capabilities | jq '.capabilities.renderers | keys'
# [ "ai-assistant-preview", "help-article", "keep", "note", "window", "writing" ]
curl -s http://localhost:3000/api/capabilities | jq '.capabilities.renderers.keep.discardBehavior'
# "silent-drop"      <- the tag vanishes at render; the write already succeeded
curl -s http://localhost:3000/api/capabilities | jq '.capabilities.renderers."ai-assistant-preview".allowAttrs'
# []                 <- no attributes survive there, not even class
```

`discardBehavior` is `silent-drop` (the element disappears at render) or
`prompt-only` (it constrains what the model may emit, not a sanitizer). The
`note` surface is the only one that also *warns at write time*
(`warnsAtWrite: true`, via the `warnings` array on write responses), and `keep`
distinguishes validated **embeds** (youtube/vimeo, built from ids) from **user
`<iframe>`s, which are stripped**.

Every value is derived from the enforcing module. The mirrors are drift-checked
against their sources by tests that parse the source files (`safe-markdown.js`,
`keep.js`, `writing.js`, `AiWritingAssistant.jsx`, `HelpArticle.jsx`), so the
manifest cannot silently disagree with what the app renders.

### Ask-and-answer loop for agents

Agents can ask you a question and wait for a click: `glassy_request_review`
(question + 2–10 choices, optionally linked to a note or document), then poll
`glassy_get_review`. Questions appear in the **Agent Review** sidebar view
(self-host only) with one button per choice, an optional comment box, and the
linked item rendered next to them. Answers sync between paired seats, so a
question asked on one machine can be answered on the other.

### Dispatching tasks to your own agent (Agent Gateway)

The Agent Gateway sends a task to an agent framework you run, and puts the
answer where you can read it. On the appliance it is **enabled by default**
(`ENABLE_AGENT_GATEWAY=true` in `deploy/selfhost/docker-compose.yml`), and the
**Agent Gateway** nav item appears because the instance is self-hosted.

**The whole difficulty is one sentence: the Glassy SERVER makes the call, not your
browser.** Everything below follows from that.

**1. Run the agent's gateway on the host.** Note the port it listens on. Defaults:
Hermes `8642` (profile installs commonly land on `8643`), OpenClaw `18789`.
Antigravity is the cloud option — it talks to Google and needs no local gateway.

**2. Settings → Agent connections → Framework: Hermes (or OpenClaw).**

- **Base URL** — pre-filled with `http://host.docker.internal:<port>`, and that is
  the right answer: the appliance's compose maps `host.docker.internal` to the host
  gateway (`extra_hosts: ['host.docker.internal:host-gateway']`, line 120).
  `http://127.0.0.1:8642` **can never work** — inside the container that address is
  the container itself.
- **Bearer Token** — the **agent gateway's own** key, not a Glassy key. For Hermes
  it is `api_server.key` in the agent profile's `config.yaml` (not `.env`; the
  `API_SERVER_KEY` environment variable is the legacy path). Leave it empty only if
  your agent accepts anonymous calls.

**3. Verify from inside the container before dispatching:**

```bash
docker exec glassy curl -4 -s http://host.docker.internal:8642/health
# {"status":"ok", ...}
```

A `curl` on your host proves nothing about this path — it must run *in the
container*, which is where the server's call comes from.

**4. Dispatch, and read it back:**

```bash
curl -sX POST http://localhost:3000/api/agents/<connection-id>/task \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"task": "Summarise what changed in the vault today"}'
# → { "success": true, "response": "…the model's actual answer…", "sessionId": "…" }
```

The body key is **`task`**, not `prompt`. Every dispatch, status change and error
is recorded and shown in the Agent Gateway panel (`GET /api/agents/activity`).

**Two exceptions worth knowing:**

- **Tailscale overlay** (`docker-compose.tailscale.yml`) — explicitly cannot reach
  `host.docker.internal`; type the host's tailnet name or IP instead. The field
  keeps whatever you type (it only follows the framework's default port while you
  have not edited it).
- **The discovery panel** can report "not reachable" while a configured connection
  dispatches perfectly: `GET /api/agents/discover` probes a hardcoded
  `127.0.0.1:8642` (#84). Trust the `curl` in step 3, not the probe.

**On SSRF posture:** the hosted tier accepts only a small allowlist
(`localhost`, `127.0.0.1`, `::1`, `host.docker.internal`); a **self-hosted**
instance accepts any host, because you own the network — that is deliberate
(`getAgentSsrfOptions` in `server/utils/urlValidator.js`), and it is what lets an
appliance talk to a LAN or Tailscale address.

> From 2.39.0 the appliance's framework list offers **OpenClaw and Hermes**, not
> just Antigravity. Before that they were gated on the Clear instance identity,
> which a self-hosted appliance never reports — so the local-agent recipe was not
> expressible in the UI at all (#85).

### Canvas pages and the embed allowlist

A `canvas` note is a first-class page type that may embed **live content** —
dashboards, charts, build logs — under an origin allowlist that the note renderer
does **not** grant (`safe-markdown` still strips iframes and scripts from normal
notes). Open one two ways: the note modal (from the Notes list), or the full-screen
`#/canvas/<id>` link an agent hands you.

The allowlist differs by instance **by design**:

- **Self-host** defaults to LAN hostnames (`localhost`, `127.0.0.1`,
  `host.docker.internal`), so a dashboard on the host or a LAN service embeds
  without config. Extend it with `CANVAS_EMBED_ORIGINS` (comma-separated).
- **Cloud** is locked: no third-party origin renders until an admin lists one.

A canvas page that references a host **not** on the allowlist refuses to render and
names the offending origin — a dashboard missing half its frames must not look like
it rendered. The effective list is reported at `/api/capabilities` →
`renderers.canvas.allowedOrigins`. Agents list and open canvas pages with
`glassy_list_notes {type:"canvas"}` and `glassy_read_note`.

---

Live Obsidian vault sync is the primary reason to self-host. The cloud server cannot reach `127.0.0.1` on your machine; a local install can.

### Two connection paths

| Path | Works on | How |
|------|----------|-----|
| **Browser extension bridge** (recommended) | All platforms, required on Windows/WSL2 | Extension proxies requests from server → browser → Obsidian |
| **Direct server→Obsidian** | Native Linux, macOS, Docker-on-Linux | Server reaches the host via `host.docker.internal:27123/27124` — requires the plugin bound to `0.0.0.0` and a host firewall allowance (see the direct-path setup below) |

On **Windows with WSL2/Docker Desktop**, only the browser extension bridge works — the container cannot reach the Windows host's `127.0.0.1`. The server's Obsidian settings panel (URL, Test Connection, Diagnostics) is hidden on self-hosted instances because those controls run server-side and would always fail from inside the container. The extension is the canonical source for the Obsidian URL and API key on self-host.

### Setup on Windows/WSL2 (the bridge path)

1. **Install Obsidian Local REST API plugin** (v4.0+) in your Obsidian desktop app. Note the API key and the URL (HTTPS `127.0.0.1:27124` or HTTP `127.0.0.1:27123`).
2. **Install the Glassy Companion** browser extension (Chrome or Firefox) — **v2.18.0+** recommended (v2.14.0+ is the minimum floor for self-host WSL2; earlier versions lacked localhost host permissions for the Glassy server URL). v2.18.0 ships **bridge transport v2**: vault WRITES (tap-to-toggle checkboxes, add-under-heading, daily-note append, push-to-vault) now traverse the bridge with raw bodies + headers (If-Match/ETag relay) — on companions ≤ 2.17.1 reads work over the bridge but writes fall back to the unreachable direct path and 502. v2.17.1 is the save & sync reliability release (capture-rule pre-population, 5xx-resilient sessions, offline-queue pause semantics, popup offline queueing, wildcard glassy.fyi host permissions); v2.16.0 adds the `chrome.alarms` heartbeat reliability fix and the MCP Settings UI; v2.17.0 fixes the save-card image preview (og:image object-fit:cover, favicon placeholder fallback, CSP img-src mirrors connect-src).
3. **Sign in** to the extension with your Glassy account (same email as your self-hosted appliance). Set the extension's **Server URL** to your self-host Glassy address (e.g. `http://localhost:3000`).
4. **Open the extension popup** → Settings → **Obsidian Bridge**:
   - Set **Obsidian URL** to your plugin URL (e.g. `http://127.0.0.1:27123` — HTTP avoids self-signed cert issues).
   - Paste the **API Key** from the Obsidian plugin.
   - Toggle **Obsidian Bridge** on. **Chrome will prompt for permission to access localhost** — click **Allow**. This grants the extension host permission to reach both the Obsidian URL and the Glassy server URL (both are localhost). If you deny it, the popup shows a warning banner and the bridge won't connect.
   - Click **Test Connection** — this tests the FULL bridge loop (server → extension → Obsidian), not just extension→Obsidian. A green result with "plugin v4.x" confirms both legs work.
   - Click **Save**.
5. **Verify on the server**: open `http://localhost:3000` in your browser, sign in, go to Settings → Obsidian. You should see "✓ Extension bridge active — Obsidian connected." The URL/token fields are hidden because the extension manages them.
6. **Verify via API** (optional): `curl -H "Authorization: Bearer <your-jwt>" http://localhost:3000/api/ext/obsidian-bridge/status` should return `{"connected":true,...}`.

The extension maintains a persistent SSE connection to the server (via the offscreen document, which Chrome does not evict). When the server needs Obsidian data (AI context, vault browsing, search) — or needs to WRITE to the vault (checkbox toggles, add-under-heading, daily-note append, push-to-vault; companion v2.18.0+ transport v2) — it pushes a request to the extension, which calls Obsidian on `127.0.0.1:27124` directly and returns the result, including upstream response headers (ETag) that power concurrency-safe writes. The extension holds the API key locally — it is never sent to the server. The extension advertises its version on connect (`&extv=` on the subscribe URL); the server enables transport v2 only for companions ≥ 2.18.0, so older extensions keep the proven read-only-over-bridge behavior.

### Setup on native Linux/macOS (direct path)

The compose file includes `OBSIDIAN_HOST_OVERRIDE=host.docker.internal`, which rewrites `127.0.0.1` references in the configured URL so the server dials the host machine instead of its own loopback. That rewrite is necessary but **not sufficient by itself**: the Obsidian Local REST API plugin binds to `127.0.0.1` by default, and no container can reach a loopback-bound port on the host. Three things are required:

1. **Rebind the plugin to all interfaces.** In Obsidian → Settings → Local REST API, enable the network/listen-on-all-interfaces option so the plugin binds `0.0.0.0` instead of `127.0.0.1` (the same change the [network allowlist](#troubleshooting-obsidian-connectivity) guidance teaches for split-machine setups). Without it, every server-side call fails with a connection timeout.
2. **Allow the container network through the host firewall.** With `ufw` in default-deny mode, container→host traffic to the plugin ports is dropped silently — the symptom is a bare timeout with no matching rule in `ufw status`. A working rule (adjust the subnet to your compose network — `docker network inspect` shows it): `ufw allow from 172.18.0.0/16 to any port 27123 proto tcp`.
3. **Configure the server side.** The Obsidian settings panel (URL, Test Connection) is hidden on self-hosted instances by design — those controls run server-side and the browser extension is the canonical path. For the direct path, set the same fields the hidden panel would have, via the API:

```bash
curl -X PATCH http://localhost:3000/api/users/profile \
  -H "Authorization: Bearer <your-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"obsidian_url": "http://host.docker.internal:27123", "obsidian_token": "<plugin API key>", "obsidian_enabled": true}'
```

Self-host sets `allowAnyHost` in the SSRF validator, and `host.docker.internal` is on the agent allowlist, so both forms are accepted. Afterwards `GET /api/obsidian/status` should return `"connected": true, "authenticated": true` — the same check the hidden Test Connection button performs.

> **⚠️ Windows + WSL2 users:** `host.docker.internal` inside the container resolves to the **WSL2 VM**, not the Windows host. The container cannot reach Obsidian running on Windows `127.0.0.1` this way. Use the **browser extension bridge** (steps above). See [`deploy/selfhost/README.md` § Obsidian vault sync](../deploy/selfhost/README.md#obsidian-vault-sync) for the full WSL2 setup guide.

### Troubleshooting Obsidian connectivity

- **Vault writes fail (502) but reads work:** writes need companion **v2.18.0+** (bridge transport v2) AND a server with the Obsidian glass-pane follow-up (v2.36.0-beta.17+). On older companions, raw-markdown writes (checkbox toggles, add-under-heading, daily append, push) fall back to the direct server→Obsidian path — unreachable from WSL2 containers. Update the extension.
- **Extension says "Bridge connected" but server says not connected:** This was a known issue in older extension versions where the SSE connection lived in the MV3 service worker (which Chrome evicts after ~30s). Update to extension **v2.18.0+** (v2.14.0+ is the minimum that moves the SSE into the offscreen document (persistent, never evicted) AND broadens `optional_host_permissions` to cover any localhost port — the old manifest only covered Obsidian ports 27123/27124, so SSE to a localhost self-host Glassy server on port 3000/3010 was silently blocked by Chrome). v2.16.0+ additionally moves the heartbeat onto `chrome.alarms` for reliability under service-worker eviction. v2.17.1 hardens save & sync reliability (offline-queue pause semantics, 5xx-resilient sessions); v2.18.0 adds bridge transport v2 (vault writes over the bridge). Verify with `curl -H "Authorization: Bearer <jwt>" http://localhost:3000/api/ext/obsidian-bridge/status`.
- **Server logs show `401 Invalid or expired SSE ticket`:** update the server image to **v2.35.0-beta.9+**. This is a server-side auth bug fixed in beta.9 — the `/api/ext` and `/api/ext/obsidian-bridge` routers ran `auth` twice on every bridge request, consuming the one-time SSE ticket on the first run. The extension masked it by silently falling back to the less-secure `?token=<JWT>` URL form (so the bridge still worked), but the JWT was leaking into server/proxy logs. beta.9 reorders the router mounts and adds a regression test. No extension or Obsidian configuration change is required.
- **Chrome doesn't prompt for localhost permission / bridge won't connect on self-host:** v2.14.0+ declares `http(s)://127.0.0.1/*` and `http(s)://localhost/*` in `optional_host_permissions`. When you toggle the bridge on or save settings, Chrome prompts for permission to access localhost. If you deny it, the popup shows a warning banner — the bridge will start but SSE/fetches will fail. Re-save to re-prompt.
- **Test Connection in extension is green but Obsidian features don't work:** The Test Connection button tests the full bridge loop. If it's green, both legs work. If features still fail, check the server logs for `ECONNREFUSED` (direct fallback failing — expected on WSL2) and verify `CLUSTER_WORKERS=1` is set in the container env (`docker exec glassy env | grep CLUSTER`). Also ensure the server is running v2.35.0-beta.11+ (beta.8 fixed the bridge-first route guards; beta.9 fixed the SSE ticket double-consumption + plugin version misreport; beta.11 fixed the bridge registry race condition where stale close handlers nuked newer connections — if the bridge "cycles every ~60s", update to beta.11).
- **Container can't reach Obsidian plugin (Linux/macOS direct path):** verify `host.docker.internal` resolves. On Linux, the `extra_hosts: ['host.docker.internal:host-gateway']` in the compose file handles this; Docker Desktop (Mac/Windows) includes it automatically. Resolution is only the DNS leg — the plugin must also be bound to `0.0.0.0` (not its `127.0.0.1` default) and the host firewall must allow the container network (see [§7 direct path](#7-obsidian-live-sync)).
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

In your self-host directory (the directory containing `docker-compose.yml`):

```bash
docker compose pull
docker compose up -d
```

Database migrations apply automatically on start. There is no downtime during a rolling update (the old container keeps serving until the new one is healthy).

`GLASSY_TAG` is **required** and must name a released version (e.g.
`GLASSY_TAG=v2.40.4`) — `docker compose` refuses to start without it. **Do not use
`latest`**: that floating tag is the hosted build and is rebuilt on every push
to `main` without the self-host build-time flags, which hides the AI tools
(MCP), Second Brain, Agent connections and API keys (BYOK) settings. See
`DEPLOYMENT_RUNBOOK.md` → "GHCR tag semantics".

**Hands-off updates (optional).** With `GLASSY_TAG` pinned to an immutable
versioned tag there is nothing for the Watchtower overlay to pull, so it is a
no-op. To upgrade, change `GLASSY_TAG` to the new released version and re-run
`docker compose up -d`. (Pointing `GLASSY_TAG` at `latest` would restore
auto-updates at the cost of the self-host feature set — not recommended.)

```bash
docker compose -f docker-compose.yml -f docker-compose.watchtower.yml up -d
```

### Rollback

```bash
GLASSY_TAG=<previous-released-version> docker compose up -d
```

Or set `GLASSY_TAG=<previous-released-version>` in `.env` and re-run
`docker compose up -d`.

### Reinstalling from scratch? Rotate `JWT_SECRET` first

If you destroy the data volume but reuse the previous `.env`, the old
`JWT_SECRET` survives — and session tokens are verified against that secret alone
(`jwt.verify(token, JWT_SECRET)`). The appliance seeds its admin from
`GLASSY_MEMBER_EMAIL`, so a browser still holding a token from the *previous*
install authenticates straight into the new one and skips the
"set your permanent password" first-boot screen entirely. You are then logged in
against a database you have never seen, with no prompt telling you so.

Before reinstalling, do one of these:

```bash
# Rotate the signing key — invalidates every existing session:
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$(openssl rand -hex 32)|" .env
```

…or clear site data for the appliance origin in every browser that previously used
it. If you intentionally restore a **backup** onto a fresh install with the same
`JWT_SECRET`, existing sessions keep working — that is the desired outcome there,
which is why this is a reinstall caution and not a code change.

A `jwt_version` claim bumped when a fresh database is seeded was considered and
rejected: it would also invalidate tokens after a legitimate restore-from-backup,
and on a single-user appliance rotating one secret is a strictly smaller blast
radius than a token-schema migration.

---

## 10. Security hardening

### Secrets

- `JWT_SECRET` and `API_KEY_ENCRYPTION_KEY` are **required**. Generate with `openssl rand -hex 32`. Store them in `.env`, which is excluded from version control.
- Rotate `JWT_SECRET` by updating `.env` and restarting the container. All existing sessions are invalidated.
- Do not set `SENTRY_DSN` — telemetry is not appropriate for a private appliance, and the server ignores it on `self_hosted` regardless.

### Network exposure

- By default Glassy binds to `0.0.0.0:3000` on the host. On a single-user machine, use a firewall to restrict access to `127.0.0.1:3000` unless you need LAN/Tailscale access.
- Do not expose port 3000 directly to the public internet without TLS in front (Cloudflare Tunnel or a local nginx reverse proxy).

### `/uploads` is unauthenticated and serves any extension — know this before you open a port

The `/uploads/*` path is deliberately **unauthenticated** (notes embed images over a plain static path) and has **no extension allowlist** — it serves whatever is in the data volume, including a video or an HTML file someone placed there. Combined with the compose default that publishes `${APP_PORT:-3000}:8080` on `0.0.0.0`, that is a network-reachable, unauthenticated static host whose contents the product did not choose.

This is a documented trade-off, not a silent one (it is disclosed in the `/api/capabilities` manifest as `uploads.servedExtensions: null` + `authenticated: false`). The default posture is safe for the intended single-user, closed-network deployment (firewall/Tailscale only). If you run on a VPS with the port open, restrict the host binding or put auth in front — you are the one choosing what lands in that volume.

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

### Verify your compose file before starting

After editing `.env`, validate that Docker can parse the configuration:

```bash
docker compose config
```

Run this before `docker compose up -d` whenever you change `.env`, `docker-compose.yml`, or any overlay. It catches typos in env var names and port mappings without starting containers.

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

### "Invalid verification code" — 2FA rejects a code you just read

Work through these in order. On an appliance, **step 2 is the one that is
actually likely**, and it is the one people skip.

1. **Upgrade to `v2.36.0-beta.42` or later.** Earlier builds verified against the
   exact current 30-second step only, so a *correct* code was rejected whenever the
   step boundary fell between the user reading it and the server checking it —
   roughly every login landing in the back half of a step. beta.42 accepts ±1 step
   (RFC 6238 §5.2), which is what every Google Authenticator-compatible service
   does. If the appliance is behind, this is almost certainly the cause and nothing
   the user does differently will help. Check with:
   ```bash
   curl -s http://localhost:3000/api/health | head -c 120   # → {"version":"2.36.0-beta.NN",…}
   ```
2. **Check the Docker host's clock, not the phone's.** The container inherits the
   host clock and has no NTP of its own. TOTP is derived from the time, and the ±1
   step tolerance absorbs roughly 30 seconds of skew in either direction — a host
   that is minutes out will reject **every code from every device**, and
   re-enrolling 2FA will not fix it:
   ```bash
   date -u                                   # on the host
   docker compose exec glassy date -u        # inside the container; should match
   curl -sI https://cloudflare.com | grep -i '^date:'   # a trusted reference
   ```
   Fix the host's time sync (`timedatectl set-ntp true` on systemd hosts, or the
   equivalent for your OS), then restart the container. Do not re-enrol first.
3. **Then the phone.** Automatic time sync on; Google Authenticator also has
   Settings → *Time correction for codes* → *Sync now*.
4. **Only then re-enrol.** Disabling 2FA clears the secret **and** the existing
   recovery codes; re-enrolling issues a fresh set of 10, shown once. Re-enrolling
   against a wrong host clock produces a new secret that also will not verify.

> **Trade-off, stated so it is a decision rather than a surprise:** the ±1 window
> means a code stays valid ~90s instead of ~30s, so there is no replay protection
> inside that span. That is the standard TOTP trade-off. The mitigation is
> throttling the verify endpoints, not narrowing the window back to something that
> rejects honest users — see `docs/NEXT_STEPS.md` OPEN 3 for the current state of
> the limiter, which is a separate open item.

### "Membership verification failed" — even though the token is correct

The appliance verifies `GLASSY_MEMBER_EMAIL` + `GLASSY_SELFHOST_TOKEN` against
the cloud at boot. That endpoint is **rate-limited (10 requests / 15 min /
IP)**, and to prevent account enumeration the cloud returns the same generic
`valid:false` for every failure — including when you are temporarily
rate-limited with a perfectly valid token.

Two traps to know:

1. **A wrong/placeholder token cannot burn the rate budget.** Before v2.36.0-beta.30 a
   failed verification exited the container, and each restart re-verified (~1/s),
   burning the entire 15-minute rate budget in seconds. Since v2.36.0-beta.30 the
   appliance **always boots** — a failed verification starts it in degraded mode —
   and the live retry is **skipped while inside the persisted backoff window**
   (30 s → 60 s → 120 s … capped at 15 min), so no restart pattern can exhaust the
   budget while you fix `.env`. `GET /api/instance` reports the current state as
   `membershipState` (`verified` / `degraded` / `unverified`).
2. **After the budget is burned, even a CORRECT token reads invalid** for the
   rest of the 15-minute window. If you just fixed the token and still see
   `Membership verification failed`, **wait 15 minutes** (or restart the
   container once after the window passes).

To check the token independently of the appliance:

```bash
curl -X POST https://app.glassy.fyi/api/verify-selfhost \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","selfhostToken":"<token>"}'
```

> 💡 The pairing token is shown **once** when generated (it is stored hashed
> on the cloud and cannot be recovered). Keep a copy in your password manager
> — if it is lost, generate a new one in Settings → Self-hosting.

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
>
> **This is irreversible if you have no backup.** See [Backup & restore](#8-backup--restore).

## 12. Cloud Sync (cross-instance data sync)

Cloud Sync keeps this appliance and your Glassy cloud account two-way in
sync. Setup (token, `.env`, scheduler tuning) is documented in the README's
**Cloud Sync** section; this section covers the security model and day-2
operations.

### Security model

- The channel authenticates with its **own** sync token (`GLASSY_SYNC_TOKEN`)
  — separate from the self-host pairing token and your login session. Rotate
  or revoke it any time from **Settings → Cloud Sync** on the cloud side.
- S2S change and media-serving endpoints check the sync token's owner.
  Do not generalize this to all local diagnostics: beta.40's missing-media
  scan and download-candidate collection are instance-wide. Health counters
  are not a per-account inventory; owner-scoping these scans remains follow-up
  work before relying on them for multi-user isolation.
- Sync tokens are stored **hashed** on the cloud; the raw token is shown once
  at generation.

### Operational notes

- Scheduler: a full pull+push cycle every `GLASSY_SYNC_INTERVAL_MS` (default
  5 min), plus a fast check every `GLASSY_SYNC_CHECK_MS` (default 10 s) while
  the outbox has pending rows — local writes typically reach the cloud within
  ~10 seconds.
- Conflicts: last-writer-wins by default; `cloud-wins` is selectable per
  pairing on the cloud side.
- Changes for **disabled content types are held, not lost** — they sit paused
  in the outbox and flow again when you re-enable the type. The Settings →
  Cloud Sync badge shows them as `+N paused (type disabled)` so they don't
  read as "stuck".
- Changes that repeatedly fail to apply are **dead-lettered after 10
  attempts** and surfaced as an alert in Settings → Cloud Sync. They are
  never silently dropped — fix the cause and press **Sync now**, or export /
  re-import the affected type.
- Deletes propagate fully for notes, documents, folders, and voice
  recordings. Deletes of bookmarks, collections, highlights, conversations,
  and pinned tags are best-effort — delete on the other instance too.

### Troubleshooting

- **Pending badge never drains:** check the cloud-side panel. Rows may be
  paused (type disabled) or dead-lettered (alert shown) — both are visible,
  neither loses data.
- **Upgrading from a pre-0093 build:** legacy outbox rows whose owner cannot
  be determined (e.g., tombstones for already-deleted rows on multi-user
  clouds) are skipped during migration; live rows are attributed from their
  source table and are unaffected.
- **Appliance says "no peers connected yet":** the cloud side hasn't seen a
  handshake since the token was set — verify `GLASSY_SYNC_TOKEN` and
  `GLASSY_VERIFY_CLOUD_URL`, then **Sync now**.

---

## 13. Push notifications — opt-in on self-host

**Browser push works on the appliance if you ask for it.** The original
"unavailable" stance rested on a wrong premise: standard Web Push (VAPID,
RFC 8291/8292 — the `web-push` package in `pushService.js`) does **not** require
FCM/APNs for a browser PWA. Deliveries go to each subscription's push-service
endpoint (Chrome's is Google-operated, Firefox's is Mozilla-operated), so the
only third-party involvement is the push service itself — which is why push
stays **off by default**: an operator may reasonably not want that dependency.

**To opt in** (#45): generate a keypair and set the variables in your `.env`
(see the `Web Push (VAPID)` block in `deploy/selfhost/.env.example`):

```bash
node scripts/generate-vapid-keys.js
# then set in .env:
#   VAPID_PUBLIC_KEY=...
#   VAPID_PRIVATE_KEY=...
#   VAPID_SUBJECT=mailto:you@example.com
```

With both keys set, `server/index.js` mounts `/api/push/*` and the
**Settings → Notifications → Push** panel appears (the panel feature-detects the
route: `/api/push/status` 404s → hidden, exactly the behavior when push is off).
Unset them and both disappear again.

**Consequences worth knowing:**

- Without the keys, `/api/push/*` answers 404 and the panel hides itself —
  identical to the previous behavior, so nothing changes for existing installs.
- Reminders always also fire **in-app over SSE** on the appliance, and
  `pushService` logs a boot warning when push is disabled. Rule-driven
  `push_reminder` actions are never silently lost — they just never leave the tab
  unless you opted in.
- The subscription endpoints still belong to third-party push services — that
  is inherent to Web Push, not something Glassy adds.

See `server/index.js` (route mounting) and
`src/components/settings/PushNotificationSettings.jsx` (panel gating). If you were
looking for this because model downloads fail, that is a separate CSP issue — see
§6 and `server/middleware/security.js`.

