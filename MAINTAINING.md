# Maintaining the Self-Host Installer

This document describes the relationship between the `glassy` repo (the
main application) and the `glassy-selfhost` repo (this installer that
users clone), and the process for keeping them in sync.

## The two repos

| Repo | Purpose | What lives here |
|------|---------|-----------------|
| `0Reliance/glassy` | Main application | All server code, frontend, tests, Dockerfile, CI workflows. Contains `deploy/selfhost/` as the **source of truth** for installer files. |
| `0Reliance/glassy-selfhost` | Installer repo (this repo, what users clone) | `.env.example`, `docker-compose*.yml`, `README.md`, `SELF_HOSTED_DEPLOYMENT.md`, `Caddyfile`, `screenshots/`. No server code. |

Users run:
```bash
git clone https://github.com/0Reliance/glassy-selfhost.git
```

The installer repo's `docker-compose.yml` pulls the GHCR image
(`ghcr.io/0reliance/glassy-dash:main`), which is built from the `glassy`
repo by the `release-image.yml` workflow.

## Source of truth

**`glassy/deploy/selfhost/` is the source of truth** for:
- `.env.example`
- `docker-compose.yml`
- `docker-compose.https.yml`
- `docker-compose.ollama.yml`
- `docker-compose.watchtower.yml`
- `Caddyfile`

These files must be **byte-identical** between the two repos. After any
change to these files in the `glassy` repo, sync them here and push.

**This repo (`glassy-selfhost`) owns its own versions** of:
- `README.md` — has badges, screenshots, and a different presentation
  style than the main repo's `deploy/selfhost/README.md`. Content must
  be consistent but formatting differs.
- `SELF_HOSTED_DEPLOYMENT.md` — same situation as README.md.
- `screenshots/` — only in this repo.
- `LICENSE` — only in this repo.

## Sync checklist

When a change is made to `glassy/deploy/selfhost/`:

1. **Commit and push** the change to `glassy` repo `main`.
2. **Wait** for the `release-image.yml` GHCR build to complete.
3. **Pull** this repo (`glassy-selfhost`).
4. **Copy the changed files** from `glassy/deploy/selfhost/` to the
   this repo's root:
   ```bash
   cp glassy/deploy/selfhost/.env.example glassy-selfhost/.env.example
   cp glassy/deploy/selfhost/docker-compose.yml glassy-selfhost/docker-compose.yml
   cp glassy/deploy/selfhost/docker-compose.https.yml glassy-selfhost/docker-compose.https.yml
   cp glassy/deploy/selfhost/docker-compose.ollama.yml glassy-selfhost/docker-compose.ollama.yml
   cp glassy/deploy/selfhost/docker-compose.watchtower.yml glassy-selfhost/docker-compose.watchtower.yml
   cp glassy/deploy/selfhost/Caddyfile glassy-selfhost/Caddyfile
   ```
5. **Update README.md** if the change affects user-facing env vars,
   quick start instructions, or configuration. Keep the badge/screenshot
   formatting that is unique to this repo.
6. **Update SELF_HOSTED_DEPLOYMENT.md** if the change affects the
   verification flow, architecture, or security model.
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

## When to update this repo

| Change in `glassy` repo | Sync to this repo? |
|------------------------|---------------------------|
| `deploy/selfhost/.env.example` | ✅ Copy file |
| `deploy/selfhost/docker-compose*.yml` | ✅ Copy file(s) |
| `deploy/selfhost/Caddyfile` | ✅ Copy file |
| `deploy/selfhost/README.md` | ⚠️ Update content here (different formatting) |
| `docs/SELF_HOSTED_DEPLOYMENT.md` | ⚠️ Update content in this repo's copy |
| `server/index.js` (selfhost verification logic) | ❌ No file copy — code is in the GHCR image |
| `server/routes/userRoutes.js` (token routes) | ❌ No file copy — code is in the GHCR image |
| `.github/workflows/release-image.yml` | ❌ No file copy — workflow runs on glassy repo |
| `Dockerfile` or `Dockerfile.deps` | ❌ No file copy — image is built from glassy repo |

## Common pitfalls

### Forgetting to sync the installer repo

The most common failure: a change is made to `deploy/selfhost/` in the
`glassy` repo, the GHCR image is rebuilt, but this installer repo is
never updated. Users who clone this repo will not see the new env var
or instructions, even though the image supports it. **Always run
through the sync checklist above.**

### Stale cached image

Users may have an old image cached locally. The README instructs users
to run `docker compose pull` before starting. If a user reports a
hardcoded URL or missing feature, first ask them to pull the latest
image:

```bash
docker compose pull && docker compose up -d
```

### Env var not passed to container

`docker-compose.yml` uses `env_file: [.env]` which passes all vars in
`.env` to the container. However, for critical vars we also add an
explicit `environment:` entry with a default. This makes the var
visible in `docker inspect` output and ensures it works even if the
user accidentally removes it from `.env`. Always add an explicit
`environment:` entry for any new required or important env var.