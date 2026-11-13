# Set up your Glassy

Everything here is optional. Glassy works as soon as you sign in. Do these when you want them.

- [Choose where AI runs](#choose-where-ai-runs)
- [Connect an AI assistant](#connect-an-ai-assistant)
- [Link your Obsidian vault](#link-your-obsidian-vault)
- [Use Glassy on other devices](#use-glassy-on-other-devices)
- [Keep a second copy in sync](#keep-a-second-copy-in-sync)
- [Settings in `.env`](#settings-in-env)

## Choose where AI runs

Glassy on your machine uses AI you bring. You can mix three places:

| Where | What it costs you | How |
|---|---|---|
| **This device**: models that run in your browser | Nothing | Settings → Workspace → Local AI models |
| **Your own server**: Ollama | Nothing | Install [Ollama](https://ollama.com), or start the bundled one with `./install.sh --with-ollama` |
| **Your own key**: a provider you have an account with | That provider's bill | Settings → Workspace → API keys |

Not sure? Start with your own Ollama if this machine has a recent graphics card or plenty of
memory, and with this device otherwise. You can change your mind later. Details in
[AI on your Glassy](ai.md).

## Connect an AI assistant

Your assistants can read and write in Glassy under their own names.

1. Open **Settings → Connections & data → Agent access (MCP)**.
2. Under **Named agent keys**, choose the app, give the key the assistant's name, and tick
   **Read-only** if it should never write. Choose **Create key**.
3. Copy the setup the panel shows for that app and paste it into the assistant.

Make one key per assistant. That is how Glassy shows you who wrote what, and how you can
switch one off without touching the others. More in [Agents in your Glassy](agents.md).

## Link your Obsidian vault

Keep writing in Obsidian. Glassy reads your vault, searches it, and can write back to it.
Steps in [Obsidian](obsidian.md).

## Use Glassy on other devices

Reach your Glassy from your phone or another computer, privately, without opening it to the
internet. Steps in [Reach it from other devices](reach-it-from-other-devices.md).

## Keep a second copy in sync

Cloud Sync keeps this Glassy and another one in step: your Glassy cloud account, or a second
Glassy you run yourself. Steps in [Cloud Sync](cloud-sync.md).

## Settings in `.env`

Glassy reads its settings from `.env` in the Glassy folder. After changing it, run
`docker compose up -d`.

### The six that matter

| Setting | What it is |
|---|---|
| `GLASSY_TAG` | The released version to run. `.env.example` names the current one. Never `latest`. |
| `GLASSY_MEMBER_EMAIL` | Your Glassy account email. Any account, free included. |
| `GLASSY_SELFHOST_TOKEN` | Your pairing token, from Settings → Account → Self-hosting on your cloud account. |
| `GLASSY_VERIFY_CLOUD_URL` | Where your account lives: `https://app.glassy.fyi`, or `https://clear.glassy.fyi` for Clear. |
| `JWT_SECRET` | Signs your sign-in sessions. Made by the installer. Changing it signs everyone out. |
| `API_KEY_ENCRYPTION_KEY` | Locks the AI keys you save. Made by the installer. Don't change it, or saved keys stop working. |

### Address and port

| Setting | Default | What it is |
|---|---|---|
| `APP_PORT` | `3000` | The port Glassy answers on. |
| `APP_URL` | `http://localhost:3000` | The address you open Glassy at. |
| `CORS_ORIGINS` | `http://localhost:3000` | Every address you open Glassy at, separated by commas. |
| `TRUST_PROXY` | `0` | How many reverse proxies sit in front of Glassy. A plain install has none. Set it to `1` behind your own reverse proxy, or sign-in limits count the proxy as one caller. The HTTPS overlay sets `1` for you. |

These three must agree. If you change the port, change all of them, or use
`./install.sh --port <number>`, which does it for you.

### AI and search

| Setting | Default | What it is |
|---|---|---|
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Where your Ollama is. The default reaches Ollama on this machine. |
| `OLLAMA_MODEL` | `llama3.2` | The Ollama model for answers. Must be a name you have pulled, exactly. |
| `OLLAMA_EMBEDDING_MODEL` | chosen for you | The Ollama model for search by meaning. |
| `ENABLE_CORPUS_INDEXER` | `true` | Prepares your notes for search by meaning. Assistants' search needs it. |
| `ENABLE_CORPUS_RECONCILER` | `true` | Once an hour, adds anything search missed. |

AI provider keys are not set here. Add them in Settings → Workspace → API keys, where they are
stored locked.

### Agents

| Setting | Default | What it is |
|---|---|---|
| `ENABLE_MCP_SERVER` | `true` | Lets assistants connect at `/mcp`. |
| `ENABLE_MCP_BRIDGE` | `true` | Lets the Glassy Capture extension connect. |
| `ENABLE_AGENT_GATEWAY` | `true` | Lets Glassy hand tasks to an agent you run. |
| `ENABLE_KB_QUERY` | `true` | The search service assistants use. |

### Obsidian and Cloud Sync

| Setting | Default | What it is |
|---|---|---|
| `OBSIDIAN_NETWORK_ALLOWLIST` | empty | Extra hosts Glassy may reach Obsidian on, when Obsidian is on another machine. |
| `GLASSY_SYNC_TOKEN`, `GLASSY_SYNC_PEER_URL` | empty | A way to set up Cloud Sync before first sign-in. Normally you do this in Settings. |
| `GLASSY_SYNC_INTERVAL_MS` | `300000` | How often a full sync runs, in milliseconds. `0` turns the schedule off. |
| `GLASSY_SYNC_CHECK_MS` | `10000` | How often Glassy checks for changes waiting to be sent. |

Everything else in `.env.example` is tuning that is safe to leave alone. The full technical
list is in the [operations reference](reference/operations.md).

Email is off on a self-host: nothing leaves the machine, so password help works locally. See
[Your account](accounts.md#if-you-forget-your-password).
