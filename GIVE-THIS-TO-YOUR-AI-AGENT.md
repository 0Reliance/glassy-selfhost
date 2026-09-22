# Give This to Your AI Agent

A self-contained onboarding brief so any AI agent (Claude, Cursor, Hermes, a
custom harness — anything that speaks MCP) can start using this Glassy
self-host without a human explaining it. Verified against
**v2.36.0-beta.42** (September 21, 2026).

> **Read this first if you were briefed on an older appliance.** beta.41 put
> every note write behind one service, which changed four things an agent can
> observe: your edits are now **attributed**, `glassy_note_delete`
> **soft-deletes**, bookmark tags follow the **canonical note tag policy**, and
> invalid tags are **rejected with a 422 that names the offender** instead of
> being silently rewritten. Details in
> [Write-path contract (beta.41+)](#write-path-contract-beta41) — the tag
> change is the one that breaks assumptions.

## What this is

A **self-hosted Glassy instance** — a private notes / knowledge
base / scheduling workspace with an AI integration layer. It ships its own
**MCP server** (29 tools, 4 prompts, 3 listed resources + 6 URI templates — `resources/list` returns the three static ones: `glassy://tags`, `glassy://folders`, `glassy://status`; the rest are addressable templates like `glassy://notes/{id}`), an **Obsidian bridge**
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

The MCP key is generated in the UI: **Settings → Connections & data** (the
MCP key panel — the same section as API keys and corpus health). It looks like `gky_mcp_…`. Revoke/rotate it from the same panel —
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

### The 36 tools (live-verified)

| Category | Tools |
|---|---|
| Search & retrieval | `glassy_search`, `glassy_obsidian_query`, `glassy_get_recent`, `glassy_get_backlinks`, `glassy_get_forward_links` |
| Notes | `glassy_list_notes`, `glassy_read_note`, `glassy_note_create`, `glassy_note_update`, `glassy_note_delete` |
| Documents (long-form) | `glassy_list_documents`, `glassy_read_document`, `glassy_create_document`, `glassy_update_document` |
| Ask the owner | `glassy_request_review`, `glassy_get_review`, `glassy_withdraw_review` |
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

### Present your work through the Public Window (beta.36)

The intended loop when you produce an artifact the operator must LOOK at —
a design doc, a diagnostic report, a code-review summary:

1. `glassy_note_create` with `is_public: true` (same paid entitlement as the
   app's own publish button — on this appliance it is always allowed).
2. Open the browser AT the note: `#/w/<owner-slug>/<noteId>`. The signed-in
   owner lands directly on your work (beta.36 fixed the private-instance
   owner-view); an anonymous visitor is redirected to sign-in first and
   returned to the note afterwards.

No file archaeology for the operator, no "I wrote something somewhere" —
you put the artifact in front of them, already inside their knowledge layer.
Un-publish any time with `glassy_note_update { is_public: false }`.

## Obsidian bridge

Two paths exist, both verified connected in beta.42:

1. **Direct REST** — Glassy ↔ Obsidian Local REST API plugin
   (`http://127.0.0.1:27123` by default). Fast, works when Obsidian is
   running.
2. **Extension bridge** — Chrome extension (Companion v2.18.x) proxies
   requests through an offscreen document. This is the path used when the
   operator browses Glassy in the browser and reaches Obsidian from the
   UI.

As an agent you don't need to care about the transport — call the Glassy
tools and the server picks the path.

## Write-path contract (beta.41+)

Every note create and every note content update now goes through one server
service (`noteService`). For an agent this is not internal tidiness — it changed
observable behaviour in four ways.

### 1. Your edits are attributed

`glassy_note_update` stamps `last_edited_by` with **`MCP agent`**. Before beta.41
an agent's edit was indistinguishable from the operator's own, so a human would
open a note and find prose they did not write with no way to tell where it came
from. If you are asked "who changed this?", the answer is now on the row.

Publishing is deliberately **not** attributed: `is_public` toggles (yours or a
moderator's) move the flag and the sync cursor only, so a takedown never credits
the administrator as the note's last editor.

**Documents share this contract** (2.38.0). `glassy_create_document` and
`glassy_update_document` write through `documentService`, so `created_by` /
`last_edited_by` carry your client name exactly as they do for notes, the tag
policy is the same 422 envelope (with `scope: "entire-write"`), the storage cap
is checked before the write, and a content update is what re-embeds the document
into the memory lane. Use documents for long-form work — journals, plans,
drafts — and notes for short captures; a document you update is searchable by
your own later `glassy_search`.

## Read what the instance can do before you write (2.38.0)

`GET /api/capabilities` describes the deployment: note types, limits, the
renderer allowlists, what render silently drops, accepted upload types, the
embedding chunk size and dimensions, the review-loop limits, and the live MCP
tool list. Read it instead of probing — every fact you cannot read is a fact you
discover by getting a 201 that does nothing.

```bash
curl -s https://app.glassy.fyi/api/capabilities | jq '.capabilities.notes.renderer.droppedAtRender'
# ["video","audio","iframe","script","style","object","embed","form"]  <- do not write these
```

Every value is read from the module that enforces it, and the renderer mirror is
checked against the browser's own config by test, so the manifest cannot drift
away from what the app actually does.

## Asking the owner a question (2.38.0)

Do not guess when a decision is the owner's. Ask, and keep working elsewhere
while you wait:

1. `glassy_request_review` with `question`, optional `choices` (2–10 distinct
   strings; default `["yes","no"]`), and — when the question is about a specific
   item — `linked_type` (`note`|`document`) plus `linked_id`. The owner sees the
   item rendered next to your question.
2. Poll `glassy_get_review` with the returned `id`. `status` stays `open` until
   the owner clicks a choice; then it is `answered` with `answer_choice`,
   `answer_comment` (optional), `answered_by` and `answered_at`.
3. `glassy_withdraw_review` if the question no longer stands. Once the owner has
   answered, withdrawal is refused (`NOT_OPEN`) — their answer stands.

The choices are stored and enforced: the owner's answer must be one you offered,
so `answer_choice` is always one of your strings. A question with one option is
refused (`INVALID_CHOICES`) — that is a statement, not a decision.

### 2. `glassy_note_delete` soft-deletes

The note goes to the bin; it is not destroyed, and its embeddings are cleaned up.
Two consequences worth designing around:

- **Delete is idempotent for already-binned notes.** Deleting a note that is
  already in the trash returns **quiet success** — `structuredContent.status`
  is `"already"` — so a retry after a timeout is safe. The original trash
  timestamp is preserved; a repeated call does not move it. An id that never
  existed (or belongs to someone else) still returns `isError` — `status` is
  `"deleted"` on the first successful call, `"already"` on a safe retry. The
  same distinction holds over REST: already-binned is `200 {ok:true}`, a
  missing note is `404`.
- **Restore is owner-only** and says so with a `403`, not a hollow `{ok:true}`.
  You cannot undo a delete you were not entitled to make. Confirm destructive
  intent with the operator *before* the call, not after.

A **collaborator's** delete is an *unfollow*, not a delete: the creator's note is
untouched and only that user's access is removed. One intent, one call — the old
`403 "use the other endpoint"` is gone.

### 3. Tags follow one canonical policy — this is the breaking one

Bookmark tags adopted the note tag policy. The old bookmark/MCP helper stripped
non-alphanumerics and capped at 50 characters while its own schema advertised 64;
the AI auto-tag lane had a third, different policy again. Now there is one:

| Rule | Value |
|---|---|
| Max tags per item | **20** |
| Max tag length | **64** characters |
| Case | lowercased (`AI` and `ai` are the same tag) |
| Surrounding whitespace | trimmed |
| Accents, spaces, punctuation inside a tag | **preserved** |
| Control characters / newlines | rejected |
| Empty after trimming | rejected |

So `Résumé` stays `résumé` — it no longer becomes `rsum` — and `release notes`
keeps its space instead of becoming `releasenotes`. **If your agent
pre-normalised tags to survive the old stripper, stop:** double-normalising is
harmless for case but you may now be mangling tags that would have survived
intact.

### 4. Invalid tags are refused, not silently rewritten

A write carrying a bad tag returns **`422 INVALID_TAGS`** with a body that names
every offender and why, so one error path handles notes, captures and the
extension endpoints alike:

```json
{
  "error": "INVALID_TAGS",
  "scope": "entire-write",
  "message": "The entire write was refused — nothing was stored. Fix or remove the rejected tags and retry.",
  "rejected": [{ "value": "…", "reason": "longer than 64 characters" }],
  "accepted": ["the", "tags", "that", "passed"],
  "limits": { "maxTags": 20, "maxLength": 64 },
  "hint": "Tags must be non-empty strings without control characters. Case and surrounding whitespace are normalised automatically."
}
```

The `scope` field is the important one: the refusal is **whole-write** — one bad
tag refuses the note, its title, its body and its images. Nothing is stored, and
`scope: "entire-write"` says so explicitly.

Read `rejected` and fix the input. Do **not** treat a `200` as "my tags were
stored as sent" without reading back — and note that a scope mismatch is now
distinguishable from success rather than reporting a hollow `updated: 1`.

### 5. New notes are visible to incremental sync immediately
`createNote` stamps `updated_at`. Before beta.41 a freshly created note had a
NULL `updated_at`, so it was invisible to `updated_at > @since` delta queries and
sorted last in every "recently updated" read path. Two further write sites stored
SQLite's `datetime('now')` (space-separated) into an ISO-`T` column, and a space
sorts before `T` — those notes read as *older* than same-day ISO stamps. If your
agent polls for recent changes, a note created seconds ago now appears.

### The unfinished-work flag (`needs_review`, 2.38.0)

An agent that leaves a note half-done can say so, and the owner sees it in the
UI without reading the note:

```json
// glassy_note_update
{ "id": "note-123", "needs_review": true }
```

`needs_review` is `0` or `1` on every note row and every note-shaped response,
always present (a missing key means an old server, never "not flagged"). Raise
it when you stop before the work is finished; the owner clears it through
PATCH/PUT `{ "needs_review": false }` or the flag control in the UI. `PUT`
keeps the stored value when you omit the field, and `PATCH` only writes what you
send, so an unrelated edit never clears or sets it. `glassy_list_notes` and
`glassy_read_note` return it as `needsReview`, so you can find your own
unfinished notes later.

### Storage headroom is checked *before* the write

Capture, the extension's note/document endpoints and the notes POST/PUT/PATCH
paths gate on remaining storage headroom rather than writing first and accounting
after. On a full instance you get a clear refusal at write time instead of a
silent over-quota row. Bookmarks are deliberately ungated — they cost no storage.

### Admin-only: `is_announcement` on import

`POST /api/notes/import` accepted `is_announcement` from any caller, so a
non-admin could publish a note to every user on the instance. It is now gated on
`is_admin`. If your import payload sets it and you are not an admin, that is the
reason it stopped working — and it was a privilege escalation, not a feature.

## Previously fixed (beta.29 wave)

Historical context for findings filed as 0Reliance/glassy #24–#34. All are fixed
in any current appliance; kept because agents still encounter them in old issue
threads and stale briefs:

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
- **Updates:** pinned `GLASSY_TAG` (currently `v2.36.0-beta.42`); do not float
  `latest` on self-host (it is the hosted build and omits self-host
  features). **`v2.36.0-beta.41` has no GHCR image and needs none** — its tag
  push landed inside a transient Actions outage, and beta.42 contains all of
  beta.41's work plus the TOTP fix. Never point a pin at beta.41.
- **Sign-in with 2FA:** beta.42 widened TOTP acceptance from the exact 30-second
  step to ±1 step, so a code stays valid ~90s. Before beta.42 a *correct* code
  was rejected whenever the step boundary fell between reading it and submitting
  it. If you drive a browser login against an older appliance and see "Invalid
  verification code" for a code you just read, that is the bug — wait for the
  next code rather than concluding the secret is wrong.
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
create/update and confirm destructive intent with the operator *before* the call:
a note delete is recoverable (soft-delete to the bin) but only the **owner** can
restore it, and a `vault_append` writes straight into the operator's Obsidian
files with no bin at all.
