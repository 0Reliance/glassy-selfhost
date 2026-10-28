# Pairing your home appliance to your own private instance

> The **Zero Reliance Pair** — *"Link your home Glassy to your own private cloud
> instance — fully yours, no Glassy servers in the loop."*
>
> This is the walkthrough behind Settings → Zero Reliance Pair on the cloud.
> Any Glassy account can do this: since D3 (2026-10-24) the **pairing token is
> the anchor, not the membership** — no tier is checked anywhere on the sync
> path. (The cloud Settings *pane* is shown to Pair holders, active Clear
> members, and — since 2026-10-27 — lapsed Clear members now see a courtesy
> card there instead of the row silently vanishing: a pair already configured
> keeps running, and the card names both restoration paths. The manual steps
> below need no entitlement at all.)

## What you are building

Two Glassy instances talking **only to each other**:

```
┌────────────────────┐         sync (TLS)        ┌──────────────────────────┐
│  Home appliance    │  ←──────────────────────→  │  Your VPS instance       │
│  (your hardware)   │    your token, your data   │  (your VM, your domain)  │
└────────────────────┘                            └──────────────────────────┘
```

No Glassy servers are in the loop. The membership check your appliance already
performs (its cloud account) is a separate relationship and stays as it is.
Once paired, the sync path is yours: we cannot see it, throttle it, or switch
it off — and neither can anyone else.

## Before you start

- A Glassy account — free is fine (Settings → Self-hosting mints the token; see
  step 2).
- A small VPS (1 vCPU / 1 GB is plenty) with Docker and a domain you control.
- ~15 minutes.

## Step 1 — Stand up your own instance

On the VPS, run the same installer your home appliance ran:

```bash
git clone https://github.com/0Reliance/glassy-selfhost.git
cd glassy-selfhost
cp .env.example .env
# set GLASSY_MEMBER_EMAIL to YOUR Glassy account email (free accounts work),
# GLASSY_SELFHOST_TOKEN (Settings → Self-hosting on the cloud),
# and the HTTPS overlay for your domain:
docker compose -f docker-compose.yml -f docker-compose.https.yml up -d
```

Your instance now runs at `https://<your-domain>` — the same software, your
hardware, your data volume.

## Step 2 — Mint the VPS instance's sync token

Sign in to **your new instance** (not the cloud) as its owner:

```
https://<your-domain>/#/settings?g=account&s=cloud-sync
```

Generate the sync token there. This token pairs the two machines **to each
other**; it never reaches Glassy's servers.

## Step 2b — Give that token to your home appliance

This is the step the walkthrough used to leave out, and without it every cycle
fails with `401 SYNC_AUTH_INVALID`.

The **home appliance presents the token; the VPS validates it.** Two ways, newest
first (2026-10-27):

- **Settings → Cloud Sync → "Pair token" on the home appliance** — paste the
  token and choose **Save Cloud Sync settings**. It is stored **encrypted**,
  resolved at every cycle, and the automated scheduler starts itself:
  **no restart, no .env.**
- **`.env` (bootstrap/recovery)**: set `GLASSY_SYNC_TOKEN=<the token>` and
  restart the appliance container. The token is read at boot there — editing
  `.env` alone does nothing until the restart. (A token saved in Settings WINS
  over the env value from its next cycle.)

Rotating later means minting a new token on the VPS and repeating whichever
path you used.

## Step 3 — Point your home appliance at your instance

On your **home appliance**, either:

- **Settings → Cloud Sync → "Syncs to"** — enter `https://<your-domain>`
  (the URL is resolved per cycle, so this applies from the next one, no
  restart), or
- **`.env`**: set `GLASSY_SYNC_PEER_URL=https://<your-domain>` and restart the
  container.

The membership-verification var (`GLASSY_VERIFY_CLOUD_URL`) is untouched — one
variable names the peer, the other names the oracle.

> **Two credentials, two lifetimes.** The peer URL is per-cycle (Settings works,
> no restart). The pair token is per-cycle now TOO (Settings, stored encrypted,
> no restart); only the `.env` fallback path is boot-time (`.env` + restart).
> Confusing the two is what makes a correct-looking pairing fail every cycle.

## Step 4 — Verify

- Home appliance → Settings → Cloud Sync → **Sync now** — it should cycle
  green against your instance.
- Change a note on either side; it appears on the other within seconds
  (push) to five minutes (pull).
- The Cloud Sync panel (backed by `GET /api/sync-token/health`) shows the peer,
  the last cycle's status and the per-type cursors. `GET /api/capabilities`
  reports the lane's protection in `syncLane` (`freeCyclesPerHour: null` on an
  appliance — owned hardware carries no throttle).

## If something goes wrong

- **Sync cycles fail after pointing at the VPS** — the token was minted on the
  wrong instance, or the VPS's HTTPS certificate is not trusted yet. Re-mint on
  the VPS instance and re-paste; check `docker compose logs glassy`.
- **You want to go back to cloud sync** — clear the "Syncs to" field (or
  remove `GLASSY_SYNC_PEER_URL`) and the appliance falls back to your cloud
  account. Nothing is deleted on either side.
- **The membership check broke** — that is a different relationship entirely;
  see the main README's troubleshooting section.

## The honest part

- **Perpetual for beta and v1 buyers.** Future sales of the Pair may be
  term-licensed after v1. Existing grants are never revoked and never touched.
- **We never reach into running systems.** A pair you have configured keeps
  running whether or not your membership is active — we cannot stop it and we
  would not.
- **Support scope:** product bugs are ours; your VPS is yours. We will help
  with Glassy's behavior on it; the VM itself is your machine.
