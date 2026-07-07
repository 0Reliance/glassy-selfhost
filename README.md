# Glassy — self-hosted

Run Glassy on your own machine as a **single-user personal appliance**.
This is the recommended path if you want live Obsidian vault sync, Ollama,
Agent Gateway, or any other localhost integration — the cloud server cannot
reach `127.0.0.1` on your machine.

> **Beta `v2.35.0-beta.2`** — GHCR image is now public. No GitHub login required.
> Stable `v1.0` coming soon. Subscribe to [releases](https://github.com/0Reliance/glassy-selfhost/releases) to be notified.

[![GitHub release](https://img.shields.io/github/v/release/0Reliance/glassy-selfhost?include_prereleases&style=flat-square&label=latest)](https://github.com/0Reliance/glassy-selfhost/releases)
[![Docker](https://img.shields.io/badge/ghcr.io-0reliance%2Fglassy--dash-2496ED?style=flat-square&logo=docker)](https://ghcr.io/0reliance/glassy-dash)
[![License](https://img.shields.io/badge/license-MIT-22c55e?style=flat-square)](LICENSE)

---

## Quick start

```bash
git clone https://github.com/0Reliance/glassy-selfhost.git
cd glassy-selfhost
cp .env.example .env
# Edit .env — fill in JWT_SECRET and API_KEY_ENCRYPTION_KEY:
#   openssl rand -hex 32   # paste each output into the matching line
docker compose up -d
```

On first boot the server seeds an **admin** account and prints the generated
password to the container log once:

```bash
docker compose logs glassy | grep -A2 "Default admin created"
```

Log in at http://localhost:3000 with username `admin` and that password, then
change it immediately in Settings. **Registration is permanently disabled** —
this is a single-owner appliance. All premium features are unlocked.

## What works differently from cloud

| Capability | Cloud (app.glassy.fyi) | Self-hosted (this) |
| --- | --- | --- |
| Notes, AI, capture, companion | Yes | Yes |
| Live Obsidian vault sync | No (server cannot reach your localhost) | Yes |
| Ollama local AI | No | Yes |
| Agent Gateway (OpenClaw, Hermes) | No (requires localhost) | Yes |
| MCP server + Second Brain | No | Yes |
| All premium features unlocked | Pro plan required | Yes — owner auto-unlocked |
| Registration | Open / admin-controlled | Permanently disabled |
| Data location | Cloud VM | Your machine (`glassy-data` volume) |

## Configuration

All variables live in `.env` (see `.env.example`). Required variables are
called out below; everything else has a safe default.

### Required

| Variable | Description |
| --- | --- |
| `JWT_SECRET` | Session token signing key. Generate with `openssl rand -hex 32`. |
| `API_KEY_ENCRYPTION_KEY` | Encrypts stored API keys. Generate with `openssl rand -hex 32`. |

### Single-user defaults (already set in `.env.example`)

| Variable | Default | Description |
| --- | --- | --- |
| `INSTANCE_ACCESS_MODE_DEFAULT` | `private` | Hides all public surfaces from logged-out visitors. An admin account is seeded automatically on first boot. |
| `DEPLOYMENT_LOCALITY` | `local` | Tells the app it's running locally (hides the cloud-limitation banner in Obsidian settings). |
| `ENABLE_MCP_SERVER` | `true` | Enables MCP server + Second Brain features. |
| `ENABLE_AGENT_GATEWAY` | `true` | Enables OpenClaw / Hermes Agent Gateway (self-host-appropriate). |

> **Registration is permanently disabled.** The server enforces this at the
> route level regardless of any env var or admin setting. The seeded `admin`
> account is the owner. Sub-accounts (multiple workspaces under the one owner)
> are fully supported via Settings → Accounts.

### Optional

| Variable | Default | Description |
| --- | --- | --- |
| `GLASSY_TAG` | `latest` | Image tag to pull from GHCR. Pin a version for reproducibility. |
| `APP_URL` | `http://localhost:3000` | Base URL for OAuth + email links. **Set this if you access via Tailscale or a domain** — see [Multi-device access](#multi-device-access-tailscale--cloudflare-tunnel--netbird). |
| `CORS_ORIGINS` | `http://localhost:3000` | Comma-separated origins allowed to call the API. **Must include any additional origin you use** (Tailscale hostname, LAN IP, domain). |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama endpoint for local AI. Already reachable via `host.docker.internal`. |
| `TRUST_PROXY` | unset | Set to `1` if behind a single reverse proxy. |

> **Cloud AI keys** (`GEMINI_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`) are not read from `.env` on the appliance. Add your own key in-app at **Settings → API Keys** (BYOK) — stored encrypted per-account.

> **Email is disabled on the appliance.** Nothing leaves the machine. Lost-password recovery uses local paths (admin reset or secret recovery key) — see [SELF_HOSTED_DEPLOYMENT.md § Account recovery](SELF_HOSTED_DEPLOYMENT.md).

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
docker run --rm -v glassy-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/glassy-backup.tar.gz -C /data .
```

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

## Further reading

- [SELF_HOSTED_DEPLOYMENT.md](SELF_HOSTED_DEPLOYMENT.md) — operational deep-dive:
  sub-accounts, account recovery, AI / BYOK, Obsidian live sync, security hardening, troubleshooting.
- [glassy-companion](https://github.com/0Reliance/glassy-companion) — browser extension for capture + Obsidian sync.
- [glassy-docs](https://github.com/0Reliance/glassy-docs) — documentation site.
