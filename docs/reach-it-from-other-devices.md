# Reach Glassy from other devices

Out of the box, Glassy answers on the machine it runs on. To use it from your phone or another
computer, choose one of these.

| | Good for | Open to the internet? |
|---|---|---|
| **Tailscale** (recommended) | Your own devices, anywhere | No |
| **Netbird** | The same, if you already use it | No |
| **Cloudflare Tunnel** | A web address without opening ports | Yes, behind Cloudflare |
| **Your own domain with HTTPS** | A server with a public address | Yes |

Whichever you choose, Glassy needs to know the address you'll use. That is two lines in `.env`:

```env
APP_URL=<the address you open Glassy at>
CORS_ORIGINS=http://localhost:3000,<the same address>
```

List every address you use in `CORS_ORIGINS`, separated by commas. Then `docker compose up -d`.
If the page loads but sign-in doesn't work, this is the line to check.

## Tailscale

[Tailscale](https://tailscale.com/) links your own devices privately. No ports to open, and
nobody else can reach your Glassy.

On the machine running Glassy:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Install Tailscale on your other devices too. Then, in `.env`:

```env
APP_URL=http://<this-machine>.<your-tailnet>.ts.net:3000
CORS_ORIGINS=http://localhost:3000,http://<this-machine>.<your-tailnet>.ts.net:3000
```

Open that address from any of your devices. To run Tailscale as part of the Glassy stack
instead of on the machine, use the `docker-compose.tailscale.yml` overlay; its header explains
the settings.

## Netbird

[Netbird](https://netbird.io/) works the same way. Use its address in `APP_URL` and
`CORS_ORIGINS`.

## Cloudflare Tunnel

[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
gives Glassy an `https://` address through Cloudflare, with no ports opened on your network.
This puts your Glassy on the internet. Put Cloudflare Access in front of it if you want a
second lock.

```bash
cloudflared tunnel login
cloudflared tunnel create glassy
cloudflared tunnel route dns glassy glassy.example.com
cloudflared tunnel run glassy
```

```env
APP_URL=https://glassy.example.com
CORS_ORIGINS=https://glassy.example.com
```

## Your own domain with HTTPS

If the machine has a public address and you can point a domain at it (ports 80 and 443 open),
the Caddy overlay gets and renews a certificate for you:

```env
GLASSY_DOMAIN=glassy.example.com
APP_URL=https://glassy.example.com
CORS_ORIGINS=https://glassy.example.com
```

```bash
docker compose -f docker-compose.yml -f docker-compose.https.yml up -d
```

The overlay tells Glassy it sits behind one proxy. Behind a reverse proxy of your own, set
`TRUST_PROXY=1` in `.env` yourself.

## Before you open Glassy to the internet

Read [Security](security.md#if-you-open-glassy-to-the-internet) first. In short: use HTTPS,
turn on two-step sign-in, and know that images in your notes are served without sign-in to
anyone who has their exact address.

## The Glassy Capture extension on another device

In the extension's settings, set **Server URL** to the same address you put in `APP_URL`.
