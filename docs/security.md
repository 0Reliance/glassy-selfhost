# Security and privacy

## What stays on your machine

Your notes, documents, bookmarks, recordings and images. Your password. Your sessions. The AI
keys you save, which are stored locked. All of it is in one Docker volume on your disk.

## What leaves your machine

| What | When | What is sent |
|---|---|---|
| The account check | When Glassy starts, at most once every 30 days when it succeeds | Your account email and pairing token. No password, no notes. |
| AI services you chose | When you use them | What you ask, to the provider whose key you added. Nothing if you use your device or your own Ollama. |
| Cloud Sync | Only if you turn it on | The kinds of items you chose, to the Glassy you paired with |
| Things you add that live elsewhere | When you use them | Calendar feeds you subscribe to, links you save, model downloads |
| Getting Glassy itself | When you install or update | Docker downloads Glassy from GitHub's registry (`ghcr.io`) |

That is the whole list. Glassy has no tracking, no usage reporting and no error reporting on
a self-host.

## Your secrets

`.env` holds your pairing token and two keys:

- `JWT_SECRET` signs your sign-in sessions. Changing it signs every browser out.
- `API_KEY_ENCRYPTION_KEY` locks the AI keys you save. If it changes, those keys can't be
  unlocked and you add them again.

Keep a copy of `.env` somewhere safe and private. The installer makes it readable only by you,
and git ignores it.

## On your own network

By default Glassy answers on port 3000 to any device on your network, and asks each one to
sign in. To keep it to this machine only, block the port in your firewall, or reach it over
Tailscale ([Reach it from other devices](reach-it-from-other-devices.md)).

Turn on two-step sign-in in Settings → Account → Security.

## If you open Glassy to the internet

You don't have to. Tailscale gives you Glassy everywhere without it. If you do:

- **Use HTTPS.** The Caddy overlay or Cloudflare Tunnel does it for you. Never put plain port
  3000 on the internet.
- **Turn on two-step sign-in.**
- **Know how images are served.** Images and files inside your notes are served from
  `/uploads/…` without sign-in, to anyone who has the exact address of a file. Nothing lists
  those addresses, but they are not locked. On a private network that doesn't matter. On the
  internet, decide whether it does.
- **Keep Glassy updated.** See [Update Glassy](upgrade.md).

A self-host is private by default: pages you publish are shown to people signed in to your
Glassy, not to the public.

## Agents

Each assistant gets its own key, which you can make read-only and can revoke at any time in
Settings → Connections & data → Agent access (MCP). A key works only on this Glassy. See
[Agents in your Glassy](agents.md).

## Report a security problem

Please don't open a public issue. See [SECURITY.md](../.github/SECURITY.md).
