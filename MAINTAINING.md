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
must name a released version** (e.g. `v2.36.0-beta.42`): compose refuses to start
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
- `docker-compose.watchtower.yml`
- `Caddyfile`

Plus two files that live elsewhere upstream:
- `SELF_HOSTED_DEPLOYMENT.md` ← `glassy/docs/SELF_HOSTED_DEPLOYMENT.md`
- `GIVE-THIS-TO-YOUR-AI-AGENT.md` ← `glassy/GIVE-THIS-TO-YOUR-AI-AGENT.md`

These files must be **byte-identical** between the two repos. After any
change to them in the `glassy` repo, you must sync them to
`glassy-selfhost` and push. The `release-image.yml` workflow auto-syncs all of
the above on every push to `main`: `.env.example`, the base `docker-compose.yml`,
three of the four overlays (`https`, `ollama`, `watchtower`), `Caddyfile`,
`SELF_HOSTED_DEPLOYMENT.md` and `GIVE-THIS-TO-YOUR-AI-AGENT.md`.

**`docker-compose.tailscale.yml` is the one exception.** It *does* exist upstream
at `glassy/deploy/selfhost/docker-compose.tailscale.yml` and the two copies are
kept identical, but **no workflow copies it** — `check-selfhost-sync.js` lists it
as mirror-owned and never compares it, so a divergence there is silent. If you
change it, `cp` it by hand and say so in the commit. (Earlier revisions of this
file claimed it "exists only in the installer repo"; it does not.)

**`glassy-selfhost` owns its own versions** of:
- `README.md` — has badges, screenshots, and a different presentation
  style than the main repo's `deploy/selfhost/README.md`. Content must
  be consistent but formatting differs.
- `MAINTAINING.md` — this file. The upstream `deploy/selfhost/MAINTAINING.md`
  is a pointer, not a copy; do not maintain two.
- `screenshots/` — only in the installer repo.
- `LICENSE` — only in the installer repo.

`SELF_HOSTED_DEPLOYMENT.md` and `GIVE-THIS-TO-YOUR-AI-AGENT.md` are **not**
installer-owned: CI copies them verbatim on every `main` push, so edit them in
the `glassy` repo and let the sync carry them over. The agent brief joined this
list on 2026-09-21 — before that it was dual-maintained by hand in both repos
and drifted on every factual correction (see the "Editing the installer repo
directly" section below for what that cost).

## Sync checklist

CI does the copying. Your job is to change the right file upstream and then
**verify** — not to `cp` and commit here by hand. A human commit that touches a
CI-owned file is rejected by `guard-source-of-truth.yml`, so following the old
"copy the files across yourself" version of this checklist now fails on purpose.

1. **Edit upstream, in `glassy`.** Installer files live in
   `glassy/deploy/selfhost/`; `SELF_HOSTED_DEPLOYMENT.md` lives in
   `glassy/docs/`; `GIVE-THIS-TO-YOUR-AI-AGENT.md` lives at the `glassy` repo
   root. `docker-compose.tailscale.yml` is the one file CI never copies — edit it
   upstream *and* `cp` it here by hand (see the exception note above).
2. **Commit and push** to `glassy` `main` (or push a version tag).
3. **Wait** for `release-image.yml` (every `main` push) or `publish-image.yml`
   (every version tag). Watch the Actions tab or
   `gh run list --workflow=release-image.yml`. The sync job is
   `sync-installer`; it commits here as `actions@github.com` with the message
   `chore: auto-sync from glassy@<sha>`.
4. **Pull this repo and verify identity** rather than trusting the log:
   ```bash
   cd glassy && node scripts/check-selfhost-sync.js . ../glassy-selfhost
   # → "[selfhost-sync] ✓ all 8 CI-owned installer files byte-identical"
   ```
   That is the same check the sync job runs before it copies, so it reports
   exactly what CI sees. It exits 1 only if a manifest file is unreadable;
   forward drift (mirror behind) is reported, not fatal, and is normal between
   a push and its sync.
5. **Update `README.md` here** if the change affects user-facing env vars, the
   quick start, or configuration. `README.md` is mirror-owned and deliberately
   *not* synced (`release-image.yml` says so inline), so it is the one file where
   a hand edit in this repo is correct — and the one that silently falls behind
   if you forget.
6. **Verify the published image** — and verify the *versioned* tag, not `:main`.
   `:main` and `:latest` are **hosted** builds without the self-host feature
   flags, so a green check against them proves nothing about the appliance:
   ```bash
   TAG=v2.36.0-beta.42   # the release you just published
   docker pull "ghcr.io/0reliance/glassy-dash:${TAG}"
   docker inspect "ghcr.io/0reliance/glassy-dash:${TAG}" \
     --format '{{index .Config.Labels "org.opencontainers.image.revision"}}'
   # Should match the glassy commit the tag points at.
   ```
   Anonymous pulls work — the package is public, no `docker login` needed. An
   anonymous manifest fetch returning HTTP 200 with a real layer list is enough
   to prove a tag is pullable without downloading it.

## When to update the installer repo

| Change in `glassy` repo | Sync to `glassy-selfhost`? |
|------------------------|---------------------------|
| `deploy/selfhost/.env.example` | ✅ Copied by CI |
| `deploy/selfhost/docker-compose.yml` + `https`/`ollama`/`watchtower` overlays | ✅ Copied by CI |
| `deploy/selfhost/Caddyfile` | ✅ Copied by CI |
| `docs/SELF_HOSTED_DEPLOYMENT.md` | ✅ Copied by CI **verbatim** — not "different formatting"; edit upstream only |
| `GIVE-THIS-TO-YOUR-AI-AGENT.md` (repo root) | ✅ Copied by CI **verbatim** — edit upstream only |
| `deploy/selfhost/docker-compose.tailscale.yml` | ⚠️ **By hand** — no workflow copies it, and the drift checker never compares it |
| `deploy/selfhost/README.md` | ⚠️ Update content in the installer `README.md` by hand (different formatting; installer owns its copy) |
| `server/index.js` (selfhost verification logic) | ❌ No file copy needed — code is in the GHCR image |
| `server/routes/userRoutes.js` (token routes) | ❌ No file copy needed — code is in the GHCR image |
| `.github/workflows/release-image.yml` | ❌ No file copy needed — workflow runs on glassy repo |
| `Dockerfile` or `Dockerfile.deps` | ❌ No file copy needed — image is built from glassy repo |

If you add a row to the ✅-by-CI set, three places must move together or the
ratchet goes red: `SYNC_PAIRS` in `scripts/check-selfhost-sync.js`, the `cp` line
in **both** `release-image.yml` and `publish-image.yml`, and `CI_OWNED` in this
repo's `guard-source-of-truth.yml`. `server/tests/selfhostSync.test.js` checks
the first two against each other — including that each `cp` reads from the
manifest's declared source, so a right destination with a wrong source fails.

## How to verify the image has your changes

After pushing to `glassy` `main` and the GHCR build completes:

```bash
# The appliance build is the VERSIONED tag. :main / :latest are the hosted
# variant and omit the self-host feature flags — checking them proves nothing.
TAG=v2.36.0-beta.42
docker pull "ghcr.io/0reliance/glassy-dash:${TAG}"

# Check the revision label matches the commit you pushed
docker inspect "ghcr.io/0reliance/glassy-dash:${TAG}" \
  --format '{{index .Config.Labels "org.opencontainers.image.revision"}}'

# Verify a specific line exists in the running image
docker run --rm --entrypoint grep \
  "ghcr.io/0reliance/glassy-dash:${TAG}" \
  -n "GLASSY_VERIFY_CLOUD_URL" /app/server/index.js
```

For a floating `main` build (hosted variant only), the same commands work with
`:main` substituted for `${TAG}` — just do not use one to make a claim about the
other.

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
`watchtower` overlays, `Caddyfile`, `.env.example`, `SELF_HOSTED_DEPLOYMENT.md`
and `GIVE-THIS-TO-YOUR-AI-AGENT.md` are generated: `release-image.yml`
blind-copies them over this repo on **every push to `glassy/main`**, and
`publish-image.yml` does it on every version tag. A `cp` has no merge step, so a
correct, tested, reviewed fix committed here vanishes at the next sync — and
nothing fails when it does.

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
`deploy/selfhost/` (or `docs/SELF_HOSTED_DEPLOYMENT.md`, or the root
`GIVE-THIS-TO-YOUR-AI-AGENT.md`), and push there. The auto-sync lands it here
within minutes. If you genuinely need a local change first, make it in `glassy`
on a branch and tag — do not hand-edit the mirror.

Files this repo owns, and which are always safe to edit here: `README.md`,
`MAINTAINING.md`, `screenshots/`, `LICENSE`, `docker-compose.tailscale.yml`.

`GIVE-THIS-TO-YOUR-AI-AGENT.md` **moved off this list on 2026-09-21.** It had
been dual-maintained by hand in both repos, and the split cost exactly what the
OLLAMA_MODEL clobber cost, in slow motion: upstream corrected the MCP resource
count and the Settings path for #60 (`3538f4ff`) and the published copy here kept
advertising the wrong ones; upstream added the beta.36 Public Window recipe and
this copy never got it; this copy gained beta.40 validation notes that upstream
lacked until someone hand-merged them back (`3c5105b2`). It stayed pinned at
"verified against beta.29" thirteen releases later. It is now CI-synced from the
`glassy` repo root, because every claim in it is a claim about the server.

### The one ordering rule when a file JOINS the CI-owned set

The guard reads `CI_OWNED` **as of the pushed HEAD** and then looks for non-bot
commits touching those files anywhere in the pushed range. So a single push
containing both a human edit to a newly-owned file *and* the commit that adds it
to `CI_OWNED` fails — the guard judges the older commit by the newer rule.

Push upstream first and let the bot deliver the file:

1. Push `glassy`. `release-image.yml` copies the file here as
   `actions@github.com` within a few minutes.
2. `git pull` this repo, *then* commit and push the mirror-owned changes
   (`README.md`, `MAINTAINING.md`) and the `CI_OWNED` addition.

Never hand-commit the newly-owned file here to "save a step". Either it is
byte-identical to upstream, in which case the bot was about to write it anyway, or
it is not, in which case you have just reintroduced the drift the sync exists to
prevent — and the next bot run silently erases your version.

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