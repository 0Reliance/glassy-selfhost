# Glassy — self-hosted

<!-- MAINTAINERS: See MAINTAINING.md for the sync process between this
     directory and the glassy-selfhost installer repo. Any change to
     files here MUST be synced to github.com/0Reliance/glassy-selfhost. -->

Run Glassy on your own machine. This is the recommended path if you want
live Obsidian sync, Ollama, Agent Gateway, or any other localhost integration —
the cloud server cannot reach `127.0.0.1` on your machine.

The image is published to the **public** GitHub Container Registry
(`ghcr.io/0reliance/glassy-dash`); no GitHub login required.

## Quick start

> **Self-hosting requires an active Glassy membership** (Clear or Pro). Sign up at
> [clear.glassy.fyi](https://clear.glassy.fyi) or [glassy.today](https://glassy.today)
> before continuing — the appliance will not start without a verified membership.

```bash
git clone https://github.com/0Reliance/glassy-selfhost.git
cd glassy-selfhost
cp .env.example .env
# Edit .env — fill in four required fields:
#   GLASSY_MEMBER_EMAIL=your@glassy-account-email
#   GLASSY_SELFHOST_TOKEN=<pairing token from Settings → Self-hosting on your cloud>
#   GLASSY_VERIFY_CLOUD_URL=https://app.glassy.fyi  (Clear members: https://clear.glassy.fyi)
#   JWT_SECRET=$(openssl rand -hex 32)
#   API_KEY_ENCRYPTION_KEY=$(openssl rand -hex 32)
docker compose up -d
```

On first boot the appliance verifies your membership AND pairing token against
the cloud, creates your local account using your membership email, and prints
the initial password once. The password is **also written to a file** so you can
recover it even if the Docker log buffer has rolled:

```bash
# Option A — grep the logs (only works on the very first boot, see note below):
docker compose logs glassy | grep -A2 "Default admin created"

# Option B — read the credentials file (survives container recreation, deleted
# after your first password change):
docker exec glassy cat /app/data/.initial_admin_password
```

> ⚠️ **The password line only appears on the true first boot** — when the `users`
> table is completely empty. If the `glassy-data` volume persisted from a
> previous run (e.g. you ran `docker compose down` without `-v`), no new
> password is printed and your existing admin password is unchanged. To start
> completely fresh, see [Reset everything](#reset-everything-nuclear-option).

Sign in at **http://localhost:3000** with your membership email and that password.
You will be **immediately prompted to set a permanent password** before you can
use the workspace — the random one is discarded after that.
Registration is permanently disabled — this is a single-owner personal appliance.
All premium features are unlocked automatically.

## Why sign in?

This is your own copy of Glassy, running on your machine. Your notes,
documents, and tags stay on this device — **your data remains offline**.
Sign-in uses your membership email and a local password — note content is
never sent to our servers.

Self-hosting requires a Glassy membership (Clear or Pro). Your membership
is verified against the cloud **once at boot** and cached for 30 days, so
the appliance works fully offline within that window. This is what keeps
the project sustainable while self-hosting scales.

**Sign-in is required during our Kickstarter launch.** Once our published
Kickstarter goals are met, sign-in on the appliance becomes **optional** —
the login screen will be a setting rather than a requirement.

We are a transparent, privacy-first, independent company. Track our goals
at [glassy.today/kickstarter](https://glassy.today/kickstarter).

**What stays on this device:**
- Your notes, documents, and tags
- Your API keys (stored encrypted in the local database)
- Any file attachments

The only outbound calls are: the membership check at boot (once per 30 days)
and AI providers *you* configure (Ollama on localhost, or BYOK keys you add
in Settings → API Keys). No note content or usage data is ever sent to us.

### How your account works

Glassy self-host is a **single-owner appliance**. Here's what happens the first
time you start it, and every time after:

**1. Membership + pairing-token check (once every 30 days, at boot).** The
appliance sends your email **and** your `GLASSY_SELFHOST_TOKEN` to
`app.glassy.fyi` — no password, no note content, no personal data. The cloud
replies with a signed yes/no: *"does this email have an active Clear or Pro
membership, and does the token match the one in the account?"* The token is
required so that someone who merely knows your email cannot spin up an
unlocked instance using your membership. The result is cached locally for 30
days (signed) or 24 hours (unsigned fallback), so the appliance works fully
offline within that window. If the cloud can't be reached and no usable cache
exists, the container refuses to start.

You generate the pairing token in your Glassy account on the cloud:
**Settings → Self-hosting → Generate token**.
  • Public / Pro members: https://app.glassy.fyi/#/settings?g=account&s=selfhost
  • Clear members:        https://clear.glassy.fyi/#/settings?g=account&s=selfhost
Paste it into `GLASSY_SELFHOST_TOKEN` in `.env`. If you generated the token on
Clear, also set `GLASSY_VERIFY_CLOUD_URL=https://clear.glassy.fyi`. Rotate the
token any time from the same settings page.

**2. Admin account created (first boot only).** If no account exists yet, the
appliance creates one using your `GLASSY_MEMBER_EMAIL` as the login email. A
random password is generated, printed to the logs **once**, written to
`/app/data/.initial_admin_password` (chmod 600), and never stored in plaintext
— only its bcrypt hash goes into the local database:

```bash
# Logs (first boot only — see warning above):
docker compose logs glassy | grep -A2 "Default admin created"
# File (survives container recreation, deleted after first password change):
docker exec glassy cat /app/data/.initial_admin_password
```

On first login you are **forced to set a permanent password** before you can
use the workspace. After that, the random password and the credentials file are
discarded.

**3. Every login after that is 100% local.** The appliance authenticates you
against its own local SQLite database using a JWT signed with your
`JWT_SECRET`. No cloud call happens during login — the cloud only confirmed
your membership at boot, and it only received your email address and pairing
token. Your notes, passwords, and session tokens never leave your machine.

```
GLASSY_MEMBER_EMAIL (your email)
        │
        ▼
  Boot: "does this email have a membership?" ──► Cloud: yes/no
        │  (email only, no password sent)         (cached 30 days)
        ▼
  First boot: create local admin account
        │  email = yours, random password printed once
        ▼
  Every login: local JWT auth against local database
        │  (no network, no cloud, no phone-home)
```

## What works differently from cloud

| Capability | Cloud (app.glassy.fyi) | Self-hosted (this) |
| --- | --- | --- |
| Notes, AI, capture, companion | Yes | Yes |
| Live Obsidian vault sync | No (server cannot reach your localhost) | Yes |
| Cloud Sync (cross-instance data sync) | Cloud side (token issuer) | Yes (appliance side) |
| Ollama local AI | No | Yes |
| Agent Gateway (OpenClaw, Hermes) | No (requires localhost) | Yes |
| MCP server + Second Brain | Pro only | Yes |
| Data location | Cloud VM | Your machine (`glassy-data` volume) |

## Configuration

All variables live in `.env` (see `.env.example`). Required variables are
called out below; everything else has a safe default.

### Required

| Variable | Description |
| --- | --- |
| `GLASSY_MEMBER_EMAIL` | Your Clear or Pro membership email. Verified against the cloud on first boot; cached for 30 days. |
| `GLASSY_SELFHOST_TOKEN` | Pairing token from Settings → Self-hosting. Prevents unauthorized use of your membership by someone who merely knows your email. |
| `GLASSY_VERIFY_CLOUD_URL` | Cloud instance that verifies your membership and token. Default `https://app.glassy.fyi`; Clear members must use `https://clear.glassy.fyi`. |
| `JWT_SECRET` | Session token signing key. Generate with `openssl rand -hex 32`. |
| `API_KEY_ENCRYPTION_KEY` | Encrypts stored API keys. Generate with `openssl rand -hex 32`. |

### Single-user defaults (already set in `.env.example`)

| Variable | Default | Description |
| --- | --- | --- |
| `INSTANCE_ACCESS_MODE_DEFAULT` | `private` | Hides all public surfaces from logged-out visitors. An admin account is seeded automatically on first boot. |
| `DEPLOYMENT_LOCALITY` | `local` | Tells the app it's running locally (hides the cloud-limitation banner in Obsidian settings). |
| `ENABLE_CORPUS_INDEXER` | `true` | Generates embeddings for semantic search (required for MCP search tools). |
| `ENABLE_KB_QUERY` | `true` | Mounts the KB query API endpoint. |
| `ENABLE_MCP_SERVER` | `true` | Mounts the MCP server at `/mcp` (15 tools, 3 prompts, 6 resources). |
| `ENABLE_HYBRID_SEARCH` | `true` | Enables BM25 + vector fusion search (best result quality). |
| `ENABLE_MCP_BRIDGE` | `true` | Enables Companion extension MCP token exchange. |
| `ENABLE_AGENT_GATEWAY` | `true` | Enables OpenClaw / Hermes Agent Gateway (self-host-appropriate). |

> **Registration is permanently disabled.** The server enforces this at the
> route level regardless of any env var or admin setting. The seeded `admin`
> account is the owner. Sub-accounts (multiple workspaces under the one owner)
> are fully supported via Settings → Accounts.

### Optional

| Variable | Default | Description |
| --- | --- | --- |
| `GLASSY_TAG` | `latest` | Image tag to pull from GHCR. Pin a version for reproducibility. |
| `APP_PORT` | `3000` | Host port Glassy listens on. Change if port 3000 is in use — then update `APP_URL` + `CORS_ORIGINS` to match. |
| `APP_URL` | `http://localhost:3000` | Base URL for OAuth + email links. **Set this if you access via Tailscale or a domain** — see [Multi-device access](#multi-device-access-tailscale--cloudflare-tunnel--netbird). |
| `CORS_ORIGINS` | `http://localhost:3000` | Comma-separated origins allowed to call the API. **Must include any additional origin you use** (Tailscale hostname, LAN IP, domain). |
| `GEMINI_API_KEY` | — | *Not used on the appliance.* Cloud AI keys (Gemini/OpenAI/Anthropic) are added in-app at **Settings → API Keys** (BYOK), stored encrypted per-account. Local AI (WebGPU/Ollama) works with no key. |
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Ollama on the host (reachable via Docker host gateway). The server auto-appends `/v1` if missing. Use `http://ollama:11434` with the bundled sidecar overlay. |
| `OBSIDIAN_NETWORK_ALLOWLIST` | — | Additional comma-separated hostnames/IPs allowed for Obsidian connections. Use when Obsidian is on a LAN IP, Tailscale node, or WSL2 bridge address not covered by the defaults. Self-hosted only. |
| `TRUST_PROXY` | unset | Set to `1` if behind a single reverse proxy. |

> **⚠️ If you change `APP_PORT`, you must also update `APP_URL` and `CORS_ORIGINS` to the same port.** Leaving them at `http://localhost:3000` while `APP_PORT=3005` will cause CORS failures and broken login redirects. All three must agree.
>
> **Email is disabled on the appliance.** Nothing leaves the machine, so
> `RESEND_API_KEY` / `EMAIL_FROM` are no-ops here. Lost-password recovery uses
> local paths instead (admin reset or a secret recovery key) — see
> [`docs/SELF_HOSTED_DEPLOYMENT.md` § Account recovery](../../docs/SELF_HOSTED_DEPLOYMENT.md).

### Advanced tuning

Every knob in `.env.example` under **Advanced tuning** is optional and safe to
leave at its default: worker count (`CLUSTER_WORKERS`), MCP tool-call rate
limits (`MCP_PRO_TOOLCALLS_PER_HOUR`), and Obsidian timeout / import caps
(`OBSIDIAN_REQUEST_TIMEOUT_MS`, `OBSIDIAN_IMPORT_MAX_*`). Raise them for a
multi-core host, heavy agent automation, or a very large vault.

## Local AI (bundled Ollama)

Glassy runs local AI out of the box: in-browser WebGPU models need nothing,
and Ollama is auto-detected on the host. If you don't already run Ollama, the
included overlay starts it as a sidecar so there's nothing extra to install:

```bash
docker compose -f docker-compose.yml -f docker-compose.ollama.yml up -d
# Pull a model once (stored in the ollama-models volume):
docker compose -f docker-compose.yml -f docker-compose.ollama.yml \
  exec ollama ollama pull llama3.2
```

Glassy is automatically pointed at the sidecar (`OLLAMA_BASE_URL=http://ollama:11434`).
Have an NVIDIA GPU? Uncomment the `deploy` block in
[`docker-compose.ollama.yml`](docker-compose.ollama.yml) after installing the
NVIDIA Container Toolkit. For **cloud** AI (Gemini / OpenAI / Anthropic), add
your own key in-app at **Settings → API Keys** (BYOK) — the appliance never
reads cloud keys from `.env`.

## Obsidian vault sync

Glassy connects to your Obsidian vault via the [Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api) plugin. There are three connection methods — the **browser extension bridge** is recommended for Windows/WSL2:

### 1. Browser Extension Bridge (recommended for Windows/WSL2)

On Windows with Docker Desktop (WSL2), the container cannot reach Obsidian on the Windows host's `127.0.0.1`. The [Glassy Companion](https://github.com/0Reliance/glassy-companion) extension solves this by proxying Obsidian requests from the server through your browser.

> **On self-hosted instances, the web app's Obsidian settings panel hides the URL, Test Connection, and Diagnostics controls** — these run server-side and would always fail from inside the container. The extension is the canonical source for the Obsidian URL and API key. Configure them in the extension popup.

**Setup:**

1. Install the **Obsidian Local REST API** plugin (v4.0+) in Obsidian. Copy the API key from the plugin settings.
2. Install the **Glassy Companion** extension (Chrome or Firefox).
3. **Sign in** to the extension with your Glassy account (same email as your self-hosted appliance).
4. Open the extension popup → Settings → **Obsidian Bridge**:
   - Set **Obsidian URL** to `http://127.0.0.1:27123` (HTTP avoids self-signed cert issues; HTTPS is `https://127.0.0.1:27124`).
   - Paste the **API Key** from the Obsidian plugin.
   - Toggle **Obsidian Bridge** on.
   - Click **Test Connection** — this tests the FULL bridge loop (server → extension → Obsidian), not just extension→Obsidian. A green result with "plugin v4.x" confirms both legs work.
   - Click **Save**.
5. In the self-hosted web app (Settings → Obsidian), you should see "✓ Extension bridge active — Obsidian connected."
6. **Verify:** `curl -H "Authorization: Bearer <jwt>" http://localhost:3000/api/ext/obsidian-bridge/status` should return `{"connected":true,...}`.

The extension holds the Obsidian API key locally (never sent to the server) and maintains a persistent SSE connection to the Glassy server via the offscreen document (which Chrome does not evict). When the server needs Obsidian data (AI context, vault browsing, search), it pushes a request to the extension, which calls Obsidian on `127.0.0.1:27124` directly and returns the result. See the [Obsidian integration guide](https://docs.glassy.fyi/02-core-features/integrations/obsidian-vault) for full details.

**Troubleshooting the bridge:**

- **Extension says "Bridge connected" but server says not connected:** Update to extension v2.17.0+ (v2.14.0+ is the minimum that moved the SSE out of the MV3 service worker, which Chrome evicts after ~30s, and added broad localhost permissions for self-host URLs; v2.16.0 adds the `chrome.alarms` heartbeat reliability fix; v2.17.0 fixes the save-card image preview). Verify `CLUSTER_WORKERS=1` (`docker exec glassy env | grep CLUSTER`). Toggle the bridge off and on.
- **Test Connection green but Obsidian features don't work:** Test Connection tests the full loop — if it's green, both legs work. Check server logs for `ECONNREFUSED` (the direct fallback failing — expected on WSL2).

### 2. Direct server → localhost (Linux/macOS)

On native Linux/macOS or Docker on Linux, the server reaches Obsidian directly via `host.docker.internal:27124`. This works out of the box with the default `OBSIDIAN_HOST_OVERRIDE=host.docker.internal`.

### 3. Network allowlist (split-machine setups)

If Obsidian runs on a different machine, set `OBSIDIAN_NETWORK_ALLOWLIST` to the Obsidian host's IP or hostname, and configure the plugin to bind to `0.0.0.0` instead of `127.0.0.1`:

```env
OBSIDIAN_NETWORK_ALLOWLIST=192.168.1.10,glassy.tail-net.ts.net
```

> ⚠️ Binding the Obsidian plugin to `0.0.0.0` exposes it to your network. Only do this on a trusted network or behind a firewall. The browser extension bridge is safer — it doesn't expose Obsidian to the network at all.

## Cloud Sync (cross-instance data sync)

Cloud Sync keeps your notes, documents, bookmarks, voice recordings,
conversations, and pinned tags two-way in sync between this appliance and your
Glassy cloud account (app.glassy.fyi or clear.glassy.fyi). It is separate
from the self-host pairing token — sync uses its own per-peer token that you
generate and rotate independently from Settings → Cloud Sync on the cloud
side.

### Enabling Cloud Sync

1. In your **Glassy cloud account** (app.glassy.fyi or clear.glassy.fyi), open
   **Settings → Cloud Sync** and click **Generate token**. Copy the raw token
   (it is shown only once).
2. In this appliance's `.env`, paste the token and set the cloud URL:
   ```bash
   GLASSY_SYNC_TOKEN=<paste-token-from-cloud>
   GLASSY_VERIFY_CLOUD_URL=https://app.glassy.fyi   # or https://clear.glassy.fyi
   ```
3. Restart the container: `docker compose up -d`. The scheduler starts on
   boot when `GLASSY_SYNC_TOKEN` is set and `INSTANCE_ID=self_hosted`.
4. Verify in the self-hosted web app at **Settings → Cloud Sync** — you should
   see the peer connection status, pending outbound count, and per-type
   cursor state. Click **Sync now** to trigger an immediate cycle.

### Tuning the scheduler (optional)

| Variable | Default | Meaning |
| --- | --- | --- |
| `GLASSY_SYNC_INTERVAL_MS` | `300000` (5 min) | Full cycle interval — pulls peer changes + pushes local. Set to `0` to disable automation (manual **Sync now** still works). |
| `GLASSY_SYNC_CHECK_MS` | `10000` (10 s) | Fast-check interval — if there are pending outbound rows, runs an immediate cycle for near-instant push. Set to `0` to disable fast-check. |

The fast check is a lightweight `COUNT(*)` query against the local outbox —
negligible overhead. When local writes are pending you typically see them
reach the peer within ~10 seconds.

### Per-type, direction, and conflict controls

In the cloud-side Settings → Cloud Sync panel you can:
- Toggle individual content types on/off (notes, documents, bookmarks, voice,
  conversations, pinned tags, etc.).
- Set the sync direction per type (push-only, pull-only, or two-way).
- Set the conflict policy: `most-recent` (last-writer-wins, the default) or
  `cloud-wins` (always apply the incoming cloud version).

Multi-appliance is supported: each appliance that handshakes with the same
cloud token gets its own row in `sync_peers`, and each runs its own scheduler
against the shared cloud state.

## Upgrading

```bash
docker compose pull
docker compose up -d
```

Database migrations run automatically on container start.

### Automatic updates (optional)

To have new images pulled and applied automatically, add the Watchtower
overlay — it polls once a day and recreates the container (same config +
volumes) when `:latest` moves:

```bash
docker compose -f docker-compose.yml -f docker-compose.watchtower.yml up -d
```

Pin `GLASSY_TAG` to a version in `.env` if you'd rather upgrade manually.

## Multi-device access (Tailscale · Cloudflare Tunnel · Netbird)

To use Glassy from another device (phone, laptop), you have three good options:

### Tailscale (recommended)

[Tailscale](https://tailscale.com/) is a WireGuard mesh VPN — no port
forwarding, no TLS to manage, no public attack surface. Each device on your
tailnet gets a stable IP (in `100.64.0.0/10`) and a MagicDNS hostname like
`glassy.tail-net.ts.net`.

```bash
# One-time, on the host running Glassy:
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Then access Glassy from any device on your tailnet at
`http://<this-machine>.tail-net.ts.net:3000` (replace `<this-machine>` with
your host's tailnet name).

**Required `.env` changes:**

```env
APP_URL=http://<this-machine>.tail-net.ts.net:3000
CORS_ORIGINS=http://localhost:3000,http://<this-machine>.tail-net.ts.net:3000
```

> ⚠️ **Tailscale CORS gotcha:** Tailscale uses `100.64.0.0/10`, which the
> app does *not* treat as internal. You must add the tailnet hostname
> (or IP) to `CORS_ORIGINS` — otherwise the browser will be CORS-rejected.

**Companion extension:** On your phone/secondary device, open the Glassy
Companion → Settings → **Server URL** and set it to
`http://<this-machine>.tail-net.ts.net:3000` for capture to work over Tailscale.

### Cloudflare Tunnel

[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
gives Glassy a public HTTPS URL through Cloudflare's edge — no port
forwarding, free TLS, but exposes the instance to the internet (gated by
Cloudflare Access if you want auth).

```bash
# One-time, on the host running Glassy:
cloudflared tunnel login
cloudflared tunnel create glassy
cloudflared tunnel route dns glassy glassy.example.com
cloudflared tunnel run glassy
```

**Required `.env` changes:**

```env
APP_URL=https://glassy.example.com
CORS_ORIGINS=https://glassy.example.com
```

### Netbird

[Netbird](https://netbird.io/) is similar to Tailscale (WireGuard mesh +
MagicDNS). Same `APP_URL` + `CORS_ORIGINS` pattern as Tailscale.

### Automatic HTTPS (Caddy)

If you own a domain and can point it at this host (public A/AAAA record, ports
80 + 443 open), the Caddy overlay terminates TLS with an auto-renewing
Let's Encrypt certificate — no manual cert wrangling:

```bash
# in .env:
#   GLASSY_DOMAIN=glassy.example.com
#   APP_URL=https://glassy.example.com
#   CORS_ORIGINS=https://glassy.example.com
docker compose -f docker-compose.yml -f docker-compose.https.yml up -d
```

Caddy proxies to Glassy on the internal network; you can drop the host `3000`
port publish from `docker-compose.yml` if you only want HTTPS ingress. For a
private network with no public domain, prefer Tailscale above.

## Data persistence, backups & restore

All data lives in the `glassy-data` Docker volume (notes DB, uploads, logs,
and `/app/data/backups`). Glassy takes an **automatic daily backup at 02:00** —
plain SQLite copies in `/app/data/backups`, roughly 7 days retained. No
configuration required.

**Full volume snapshot** (captures everything, including generated backups):

```bash
docker run --rm -v glassy-selfhost_glassy-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/glassy-backup.tar.gz -C /data .
```

> The named volume is `glassy-selfhost_glassy-data` (the `glassy-selfhost_`\n> prefix comes from the `name:` field in `docker-compose.yml`). Using\n> `glassy-data` without the prefix targets a nonexistent volume and backs\n> up nothing.

**Encrypted / on-demand backups.** For extra copies you can move off the
machine, use the backup CLI (honours `BACKUP_ENCRYPTION_KEY`,
`BACKUP_RETENTION_DAYS`, `BACKUP_DIR` from `.env`). The runtime image has no
`npm`, so call `node` directly:

```bash
docker compose exec glassy node server/utils/backup.js            # create
docker compose exec glassy ls -1 /app/data/backups               # list files
```

**Restore the database.** The CLI restore auto-decrypts `.enc` files and copies
plain `.db` files, so it works on both the automatic and CLI backups:

```bash
docker compose exec glassy node server/utils/backup.js --restore <backup-file>
```

The restore takes a pre-restore safety copy and waits 5 seconds before
overwriting the live database (press Ctrl+C to abort). For a clean restore,
stop other writers first. Set `BACKUP_ENCRYPTION_KEY` in `.env` before
restoring an encrypted (`.enc`) backup.

## Troubleshooting

### Port 3000 already in use

If another service is using port 3000 (common for dev tools), set a
different port in `.env`:

```env
APP_PORT=3001
APP_URL=http://localhost:3001
CORS_ORIGINS=http://localhost:3001
```

Then `docker compose up -d`. The container always listens on 8080 internally;
`APP_PORT` only changes the host-side mapping.

### Checking container health

The container includes a built-in health check. To verify it's healthy from
the host:

```bash
# Canonical health endpoint (used by Docker healthcheck):
curl http://localhost:3000/api/monitoring/ready

# Convenience alias:
curl http://localhost:3000/ready
```

Both return JSON with `"status":"ready"` when healthy. If you get HTML
instead, the container may still be starting up — wait a few seconds and
retry.

### Debugging from inside the container

The runtime image includes `curl` for network diagnostics:

```bash
# Enter the container:
docker compose exec glassy sh

# Test Ollama connectivity from inside the container:
curl -s http://host.docker.internal:11434/api/tags | head -c 200

# Test membership-verification endpoint reachability:
curl -s -o /dev/null -w "%{http_code}" https://app.glassy.fyi/api/verify-selfhost
```

### Container logs

```bash
# Full logs:
docker compose logs glassy

# Follow logs:
docker compose logs -f glassy

# Check for membership verification status:
docker compose logs glassy | grep -i "membership"

# Check for Agent Gateway mount status:
docker compose logs glassy | grep -i "Agent Gateway"
```

## Licensing

The Docker Compose files, Caddy configuration, and deployment scripts in this
repository are licensed under the **MIT License**.

The GlassyDash application image (`ghcr.io/0reliance/glassy-dash`) pulled by
these compose files is separately licensed under the **Business Source License
1.1** (BSL 1.1). It is available for personal, non-commercial, self-hosted use
and will transition to **AGPL-3.0** on 2027-07-13 or upon Kickstarter goal
satisfaction, whichever comes first.

For commercial licensing inquiries: hello@glassy.fyi
