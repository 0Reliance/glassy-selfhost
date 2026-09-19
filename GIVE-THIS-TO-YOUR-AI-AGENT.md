# Give This to Your AI Agent

A self-contained onboarding brief so any AI agent (Claude, Cursor, Hermes, a
custom harness — anything that speaks MCP) can start using this Glassy
self-host without a human explaining it. Verified against
**v2.36.0-beta.29** (September 11, 2026).

## What this is

A **self-hosted Glassy instance** — a private notes / knowledge
base / scheduling workspace with an AI integration layer. It ships its own
**MCP server** (29 tools, 4 prompts, 9 resources), an **Obsidian bridge**
(extension + direct REST path), a local **Ollama** inference path, and an
**agent gateway** for AI feature routing.

Everything lives on the operator's own machine. There is no cloud
dependency except a one-time license check at boot.

## The single most useful fact

**Point your MCP client at this instance and the entire workspace becomes
tool-callable.** Search notes, read/write vault files, query the knowledge
graph, capture ideas, manage schedule events — all through one endpoint.

### MCP connection

```
URL:     http://<host>:3010/mcp
Auth:    Authorization: Bearer <mcp-key>
```

The MCP key is generated in the UI: **Settings → MCP** (or **API Keys →
MCP**). It looks like `gky_mcp_…`. Revoke/rotate it from the same panel —
it is scoped to this instance only.

Claude Desktop example (the UI shows this exact snippet): paste into
`~/.config/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "glassy": {
      "url": "http://localhost:3010/mcp",
      "headers": { "Authorization": "Bearer gky_mcp_..." }
    }
  }
}
```

### The 29 tools (live-verified)

| Category | Tools |
|---|---|
| Search & retrieval | `glassy_search`, `glassy_obsidian_query`, `glassy_get_recent`, `glassy_get_backlinks`, `glassy_get_forward_links` |
| Notes | `glassy_list_notes`, `glassy_read_note`, `glassy_note_create`, `glassy_note_update`, `glassy_note_delete` |
| Vault (live Obsidian files) | `glassy_vault_read`, `glassy_vault_append` |
| Knowledge graph | `glassy_graph_context`, `glassy_find_paths`, `glassy_get_orphans`, `glassy_get_central_notes`, `glassy_graph_stats` |
| Captures | `glassy_add_capture`, `glassy_capture_voice` |
| Bookmarks | `glassy_bookmark_update`, `glassy_bookmark_delete` |
| Schedule | `glassy_get_schedule`, `glassy_create_event`, `glassy_update_event`, `glassy_delete_event`, `glassy_find_free_slots` |
| Tags / folders | `glassy_get_tags`, `glassy_get_folders` |
| Proxy | `glassy_obsidian_proxy` |

`glassy_obsidian_query` and `glassy_obsidian_proxy` reach the operator's
Obsidian vault through the local REST API plugin — they work even when the
Glassy UI is not focused.

Read access is the default posture; write tools are available but the
operator controls the key.

## Obsidian bridge

Two paths exist, both verified connected in beta.29:

1. **Direct REST** — Glassy ↔ Obsidian Local REST API plugin
   (`http://127.0.0.1:27123` by default). Fast, works when Obsidian is
   running.
2. **Extension bridge** — Chrome extension (Companion v2.18.x) proxies
   requests through an offscreen document. This is the path used when the
   operator browses Glassy in the browser and reaches Obsidian from the
   UI.

As an agent you don't need to care about the transport — call the Glassy
tools and the server picks the path.

## What was broken and is now fixed (beta.29)

This brief assumes beta.29, which shipped fixes for a wave of self-host
findings filed on GitHub (0Reliance/glassy #24–#34):

- **#30** Local AI model downloads now work — CSP + service-worker routes
  include HuggingFace's current CDN (`us.aws.cdn.hf.co`).
- **#28** Self-host identity is baked into the build; the UI no longer
  wrongly shows "You are on the cloud" — `window.__INSTANCE__` /
  `/api/instance` report `instanceId: self_hosted`.
- **#33** Ollama BYOK: the "Local (localhost:11434)" option is visible on
  self-host and cloud validation no longer 404s.
- **#32** The API Keys panel no longer crashes on the `mcp` provider row.
- **#34** Obsidian imports normalize frontmatter `type` — a note with
  `type: project-doc` (or any custom type) imports as `text` and renders
  as markdown, not as a drawing canvas.
- **#27** "Create new document" now opens the editor immediately.

Remaining known self-host quirks worth knowing:

- **#31** Monthly Obsidian periodic requests can 400 if the bridge token
  doesn't match the plugin (see Settings → Obsidian); refresh the token
  from the panel if you see `400 Invalid token`.
- **#25** `check-url`/fetch validation rejects `localhost` targets in a
  few legacy call sites on self-host; use `127.0.0.1` or the tailnet host
  where possible.
- Cloud sync is intentionally OFF unless `GLASSY_SYNC_TOKEN` is set
  (`/api/sync-token` reports `envTokenSet: false`).

## Connecting an agent to the Agent Gateway (live-verified recipe, beta.40)

Settings → Agent connections → add a **Hermes** connection. Two fields trip
everyone up:

1. **baseUrl** must be reachable *from the Glassy container*, not from your
   browser: `http://host.docker.internal:<port>` where `<port>` is the agent
   gateway's `api_server.port` (Hermes default-profile: 8642; profile
   installs commonly differ, e.g. 8643). `localhost` resolves to the
   container itself, and LAN IPs are blocked from the Docker bridge on WSL
   mirrored networking — both silently fail.
2. **token** is the agent gateway's **`api_server.key`** — for Hermes this
   lives in the agent's profile `config.yaml` under `api_server.key` (not in
   `.env`). Paste it into the connection's Token field.

Verify from inside the container before dispatching:
`curl -4 http://host.docker.internal:<port>/health` → `{"status":"ok",…}`.
Dispatch is `POST /api/agents/:id/task` with body `{"task": "…"}` — the key
is `task`, not `prompt`. Note `GET /api/agents/discover` probes a hardcoded
`127.0.0.1:8642` and may report "not reachable" even when your configured
connection dispatches fine (#84).

## Embeddings: switching models and the reindex recovery path

- The embedding health oracle is `GET /api/monitoring/ready` →
  `embeddingHealth` (`ok`, `totalRows`, `offReferenceRows`, `staleRows`,
  `runtimeMismatchedRows`). Check it after any model change.
- Changing `OLLAMA_EMBEDDING_MODEL` orphans stored vectors (dimension drift;
  beta.37's write guard answers such writes with 409
  `EMBEDDING_DIMENSION_MISMATCH`). The recovery is one call:
  `POST /api/kb/backfill/reindex` with body `{"confirm": true}` — clears all
  embedding tables + the sync ledger and rebuilds. Live result on a real
  instance: 269 items backfilled, 0 errors, index 78 → 1,643 vectors.
- Requires `ENABLE_CORPUS_INDEXER=true` (compose default).

## Cloud sync latency expectation

Push latency is up to ~40 seconds by design: the sync scheduler's 30-second
minimum cycle gap (`MIN_CYCLE_GAP_MS`) overrides the 10-second fast-check.
It is latency, not data loss — the 5-minute full cycle is the backstop.
Don't file "sync is broken" because a write didn't appear within 10s.

## Ops facts an agent should know

- **Health:** `GET /api/health` → `{"status":"ok", "version":"…"}`;
  `GET /api/monitoring/ready` → `{"status":"ready"}`.
- **Instance:** `GET /__instance-config.js`, `GET /api/instance` →
  `{accessMode: private, instanceId: self_hosted, deploymentLocality: local}`.
- **Auth for REST probes:** the UI uses a JWT (`Authorization: Bearer`);
  the MCP key is separate and scoped to `/mcp`.
- **Local LLM:** server-side Ollama at `http://host.docker.internal:11434`
  (10 models) — used by AI features; WebGPU local models download through
  the browser (now that #30 is fixed).
- **Data:** SQLite at `/app/data/notes.db` inside the container; backups
  are operator-managed via the Import/Export settings panel.
- **Ports:** 3010 (HTTP app) in this deployment.
- **Updates:** pinned GLASSY_TAG (`v2.36.0-beta.29` here); do not float
  `latest` on self-host (it is the hosted build and omits self-host
  features).
- **After any upgrade, close and reopen the Glassy tab (or hard-refresh).**
  The PWA service worker + cached shell live in the browser, not the
  container — an already-open tab keeps enforcing the OLD page's security
  policy until it reloads. Stale-shell symptom: fetches (model downloads,
  etc.) blocked by CSP violations listing hosts the server no longer
  blocks, or the old UI showing. Clear site data only if it persists.
  Tracked upstream: 0Reliance/glassy#36.

## Suggested first actions for an agent

1. `glassy_search` the operator's workspace ("README", "VAULT POLICY").
2. `glassy_get_tags` + `glassy_get_folders` to map the namespace.
3. `glassy_vault_read` a file the operator references.
4. For scheduling work: `glassy_get_schedule` before proposing an event.

Be careful with `glassy_note_delete` / `glassy_bookmark_delete` /
`glassy_vault_append` — they mutate the operator's real data. Prefer
create/update and confirm destructive intent with the operator.
