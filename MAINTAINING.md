# Maintaining the Self-Host Installer

This document describes the relationship between the `glassy` repo (the
main application) and the `glassy-selfhost` repo (the installer that users
clone), and the process for keeping them in sync.

## The two repos

| Repo | Purpose | What lives here |
|------|---------|-----------------|
| `0Reliance/glassy` | Main application | All server code, frontend, tests, Dockerfile, CI workflows. Contains `deploy/selfhost/` as the **source of truth** for installer files. |
| `0Reliance/glassy-selfhost` | Installer repo (what users clone) | `.env.example`, `docker-compose*.yml`, `README.md`, `SELF_HOSTED_DEPLOYMENT.md`, `Caddyfile`, `screenshots/`. No server code. |

Users run:
```bash
git clone https://github.com/0Reliance/glassy-selfhost.git
```

The installer repo's `docker-compose.yml` pulls the GHCR image
`ghcr.io/0reliance/glassy-dash:${GLASSY_TAG:?…}`. **`GLASSY_TAG` is required and
must name a released version** (e.g. `v2.36.0-beta.31`): compose refuses to start
without it, and `latest` is the wrong value.

### Which tag to reference: `latest` is the hosted build, not the appliance

Two workflows publish images, and they do **not** build the same thing:

| Workflow | Trigger | Tags | Self-host build flags |
|---|---|---|---|
| `publish-image.yml` | version tag | `v2.36.0-beta.N` | **yes** — `INSTANCE_ID=self_hosted` + all four `VITE_ENABLE_*` |
| `release-image.yml` | every push to `main` | `latest`, `main` | **no** — built without them |

So `:latest` and `:main` move constantly and always carry the *hosted* bundle.
Pointing an appliance at them hides **AI tools (MCP)**, **Second Brain**, **Agent
connections** and **API keys (BYOK)**, and shows a "You are on the cloud" banner on
the user's own hardware. Versioned tags are the appliance build. `Dockerfile`
asserts the baked marker and fails the build if the two variants converge, and the
installer compose encodes `${GLASSY_TAG:?…}` so a missing pin is a startup error
rather than a degraded install.

If you are reading this to debug a "features are missing" report, the first
question is always `grep GLASSY_TAG .env`.

## Source of truth

**`glassy/deploy/selfhost/` is the source of truth** for:
- `.env.example`
- `docker-compose.yml`
- `docker-compose.https.yml`
- `docker-compose.ollama.yml`
- `docker-compose.tailscale.yml`
- `docker-compose.watchtower.yml`
- `Caddyfile`

These files must be **byte-identical** between the two repos. After any
change to these files in the `glassy` repo, you must sync them to
`glassy-selfhost` and push. The `release-image.yml` workflow auto-syncs most of
this on every push to `main`: `.env.example`, the base `docker-compose.yml`,
three of the four overlays (`https`, `ollama`, `watchtower`), `Caddyfile` and
`SELF_HOSTED_DEPLOYMENT.md`. **`docker-compose.tailscale.yml` is not copied by
CI** (it exists only in the installer repo), so sync that one by hand.

**`glassy-selfhost` owns its own versions** of:
- `README.md` — has badges, screenshots, and a different presentation
  style than the main repo's `deploy/selfhost/README.md`. Content must
  be consistent but formatting differs.
- `screenshots/` — only in the installer repo.
- `LICENSE` — only in the installer repo.

`SELF_HOSTED_DEPLOYMENT.md` is **not** installer-owned: CI copies
`docs/SELF_HOSTED_DEPLOYMENT.md` verbatim on every `main` push, so edit it in
the `glassy` repo and let the sync carry it over.

## Sync checklist

When you change anything in `glassy/deploy/selfhost/`:

1. **Commit and push** the change to `glassy` repo `main`.
2. **Wait** for the `release-image.yml` GHCR build to complete (watch
   the Actions tab or `gh run list --workflow=release-image.yml`).
3. **Clone or pull** `glassy-selfhost` repo.
4. **Copy the changed files** from `glassy/deploy/selfhost/` to the
   `glassy-selfhost` repo root:
   ```bash
   cp glassy/deploy/selfhost/.env.example glassy-selfhost/.env.example
   cp glassy/deploy/selfhost/docker-compose.yml glassy-selfhost/docker-compose.yml
   cp glassy/deploy/selfhost/docker-compose.https.yml glassy-selfhost/docker-compose.https.yml
   cp glassy/deploy/selfhost/docker-compose.ollama.yml glassy-selfhost/docker-compose.ollama.yml
   cp glassy/deploy/selfhost/docker-compose.tailscale.yml glassy-selfhost/docker-compose.tailscale.yml
   cp glassy/deploy/selfhost/docker-compose.watchtower.yml glassy-selfhost/docker-compose.watchtower.yml
   cp glassy/deploy/selfhost/Caddyfile glassy-selfhost/Caddyfile
   ```
5. **Update README.md** in `glassy-selfhost` if the change affects user-
   facing env vars, quick start instructions, or configuration. Keep the
   installer repo's badge/screenshot formatting.
6. **`SELF_HOSTED_DEPLOYMENT.md`** lives in the `glassy` repo at
   `docs/SELF_HOSTED_DEPLOYMENT.md` and is copied verbatim by CI — no manual
   sync needed. If you edited it locally, just commit and push `glassy`.
7. **Verify file identity**:
   ```bash
   diff glassy/deploy/selfhost/.env.example glassy-selfhost/.env.example
   diff glassy/deploy/selfhost/docker-compose.yml glassy-selfhost/docker-compose.yml
   ```
   Both must produce no output (identical).
8. **Commit and push** to `glassy-selfhost` `main`.
9. **Verify the GHCR image** has the new code:
   ```bash
   docker pull ghcr.io/0reliance/glassy-dash:main
   docker inspect ghcr.io/0reliance/glassy-dash:main \
     --format '{{index .Config.Labels "org.opencontainers.image.revision"}}'
   # Should match the glassy repo HEAD SHA
   ```

## When to update the installer repo

| Change in `glassy` repo | Sync to `glassy-selfhost`? |
|------------------------|---------------------------|
| `deploy/selfhost/.env.example` | ✅ Copy file |
| `deploy/selfhost/docker-compose*.yml` | ✅ Copy file(s) |
| `deploy/selfhost/Caddyfile` | ✅ Copy file |
| `deploy/selfhost/README.md` | ⚠️ Update content in installer README (different formatting) |
| `docs/SELF_HOSTED_DEPLOYMENT.md` | ⚠️ Update content in installer's copy (different formatting) |
| `server/index.js` (selfhost verification logic) | ❌ No file copy needed — code is in the GHCR image |
| `server/routes/userRoutes.js` (token routes) | ❌ No file copy needed — code is in the GHCR image |
| `.github/workflows/release-image.yml` | ❌ No file copy needed — workflow runs on glassy repo |
| `Dockerfile` or `Dockerfile.deps` | ❌ No file copy needed — image is built from glassy repo |

## How to verify the image has your changes

After pushing to `glassy` repo `main` and the GHCR build completes:

```bash
docker pull ghcr.io/0reliance/glassy-dash:main

# Check the revision label matches the commit you pushed
docker inspect ghcr.io/0reliance/glassy-dash:main \
  --format '{{index .Config.Labels "org.opencontainers.image.revision"}}'

# Verify a specific line exists in the running image
docker run --rm --entrypoint grep \
  ghcr.io/0reliance/glassy-dash:main \
  -n "GLASSY_VERIFY_CLOUD_URL" /app/server/index.js
```

## Common pitfalls

### Forgetting to sync the installer repo

The most common failure: a change is made to `deploy/selfhost/` in the
`glassy` repo, the GHCR image is rebuilt, but the `glassy-selfhost`
installer repo is never updated. Users who clone the installer repo will
not see the new env var or instructions, even though the image supports
it. **Always run through the sync checklist above.**

### Stale cached image

Users may have an old image cached locally. The installer README
instructs users to run `docker compose pull` before starting. If a user
reports a hardcoded URL or missing feature, first ask them to pull the
latest image:

```bash
docker compose pull && docker compose up -d
```

### Editing the installer repo directly (your change will be deleted)

**Do not fix these files here.** `docker-compose.yml`, the `https`/`ollama`/
`watchtower` overlays, `Caddyfile`, `.env.example` and
`SELF_HOSTED_DEPLOYMENT.md` are generated: `release-image.yml` blind-copies them
over this repo on **every push to `glassy/main`**, and `publish-image.yml` does it
on every version tag. A `cp` has no merge step, so a correct, tested, reviewed fix
committed here vanishes at the next sync — and nothing fails when it does.

This already happened once:

```
1606c9f  2026-09-11  fix(compose): forward OLLAMA_MODEL env into the glassy container
1001ecb  two commits later, "chore: auto-sync from glassy@346d6f3"
                   -> deleted that line, because upstream was never changed
```

The documented remedy for a live user-facing bug (0Reliance/glassy#35) sat reverted
for two days before anyone noticed.

The rule is enforced in two places now:

- `guard-source-of-truth.yml` (this repo) fails any non-bot commit touching a
  CI-owned file, so the mistake is caught at the moment it is pushed.
- `scripts/check-selfhost-sync.js` (`glassy` repo) reports drift in both directions
  and runs in `glassy`'s CI plus before both sync `cp` steps.

**The correct workflow:** open `0Reliance/glassy`, edit the matching file under
`deploy/selfhost/` (or `docs/SELF_HOSTED_DEPLOYMENT.md`), and push. The auto-sync
lands it here within minutes. If you genuinely need a local change first, make it in
`glassy` on a branch and tag — do not hand-edit the mirror.

Files this repo owns, and which are always safe to edit here: `README.md`,
`MAINTAINING.md`, `screenshots/`, `LICENSE`, `docker-compose.tailscale.yml`.

### Env var not passed to container

`docker-compose.yml` declares `env_file: [.env]`, which forwards **every** variable
in `.env` into the container — a var does **not** need an `environment:` entry to
reach the process. (Verified: `env_file` alone delivers `OLLAMA_MODEL=…` to
`docker compose run … env`, and `environment:` only takes precedence for keys it
also names.)

Add an explicit `environment:` entry anyway for important vars, for two reasons
that are about operability rather than reachability: it appears in `docker inspect`
output when support is debugging a live box, and it gives the var a working default
if the user deletes the line from `.env`. Do not add one believing the var is
otherwise invisible to the container — that misconception sent the #35 triage down
the wrong path first.