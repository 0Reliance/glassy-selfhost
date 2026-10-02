# Give This to Your AI Agent

A self-contained onboarding brief so any AI agent (Claude, Cursor, Hermes, a
custom harness — anything that speaks MCP) can start using this Glassy
self-host without a human explaining it. Verified against
**v2.40.7** (September 30, 2026). The numbers and surfaces in this brief are
machine-checked rather than hand-trusted: `scripts/check-doc-tool-counts.js` and
`scripts/check-mcp-claims.sh` compare every tool / prompt / resource count
against the code, and
`server/tests/guards/docClaimFreshnessGuard.test.js` fails the build if a canvas
surface the manifest publishes is not documented here.

> **The second brain is yours too.** Glassy is one workspace for the human AND
> their agents: you get durable **memory** (notes authored by your pinned
> identity), a surfaced **pairing** loop (dispatch results ride the event and
> your work lands as real notes), and a structured **approval** loop (ask, the
> owner clicks, the artifact carries the state). The capability split,
> stated plainly: the self-host build carries the capability, the cloud build carries
> the restriction — on a self-hosted appliance you are a principal; on cloud
> some surfaces (multi-key identity, notify, external corpora) are withheld,
> and that is the design, not a bug.

The rest of this brief is the practical detail.

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
**MCP server** with three surfaces, not one:

- **40 tools** — 36 registered everywhere; `glassy_notify` and the three review
  tools are self-host only, because the review queue and owner inbox they
  terminate in are not served on cloud. Full table below.
- **4 prompts** — server-authored instruction templates. Named and explained in
  [*Prompts*](#the-4-prompts-a-separate-surface-from-tools) below.
- **9 resources** — 3 static (these are all `resources/list` returns) plus **6 URI
  templates that discovery will never show you**. Named in
  [*Resources*](#the-9-resources-6-are-not-discoverable) below.

…plus an **Obsidian bridge** (extension + direct REST path), a local **Ollama**
inference path, and an **agent gateway** for AI feature routing.

> **Read this before you assume the tool table is the whole system.** Two of the
> three MCP surfaces are invisible to the way most agents explore: `prompts/list`
> and `resources/list` are separate calls from `tools/list`, and six of the nine
> resources are URI templates that `resources/list` deliberately does not return.
> An agent that only reads `tools/list` will use a third of this instance.

Everything lives on the operator's own machine. There is no cloud
dependency except a one-time license check at boot.

## First boot as an agent (a clean self-host install)

**Do this before any verification probe, or you will misdiagnose a working install as broken.**

On a fresh self-hosted install the seeded owner account carries `password_must_change = 1`, and
the server refuses **every** authenticated `/api/*` call until that flag is cleared:

```
403 {"error":"This account must change its password before it can use the API.",
     "code":"PASSWORD_CHANGE_REQUIRED","password_must_change":true}
```

`/api/auth/change-password` is the only exempt path. `POST /api/auth/login` is **not** behind the
wall, so login still succeeds and hands you a perfectly good token — and then every call you make
with it 403s. That is the trap: an agent that sees `200` from login and `403` from `/api/notes`
reasonably concludes the install is broken. It isn't.

The sequence, in order:

```bash
# 1. The generated password exists for exactly one purpose, and only until step 3.
docker exec glassy cat /app/data/.initial_admin_password

# 2. Log in (this works even with the flag set).
curl -s -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"<from the seed file>","password":"<from the seed file>"}'   # -> { token, user }

# 3. Clear the wall. Both fields required; the new password must be >=8 chars with
#    an uppercase, a lowercase, and a digit.
curl -s -X POST http://localhost:8080/api/auth/change-password \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"currentPassword":"<seed>","newPassword":"<yours>"}'
```

What the responses mean: `200 {"message":"Password updated successfully."}` and you are done;
`400` means a field is missing or the new password is too weak; `401` means you are not
authenticated; `403` here means the **current password you sent was wrong**, not the wall — the
two are different 403s, so read the body rather than the status.

Three details that will otherwise cost you an hour:

- **Your existing token stays valid after the change.** Nothing is revoked: `auth` verifies only
  the JWT signature and expiry (`server/middleware/auth.js:376`), and there is no token version
  or `jti` blocklist, so a password change does not invalidate issued tokens. **No re-login is
  required** — if you read elsewhere that it is, that is wrong. (Re-login anyway if you want a
  clean identity, but nothing forces it.)
- **The seed file is deleted by step 3.** `clearInitialPasswordFile()` runs on success, so a
  recovery script cannot re-read it afterwards. Capture it once, before you change anything.
- **You do not have to wait 15 seconds for the wall to drop.** The user row is cached for
  `USER_CACHE_TTL_MS`, which would otherwise keep you getting `PASSWORD_CHANGE_REQUIRED` after a
  successful change; the route calls `auth.invalidateUser()` so the clear takes effect
  immediately.

On the appliance this is a one-time thing for the owner, and it is deliberately strict: a rule
that was displayed but not enforced was the original defect. If you are scripting an install,
budget for it as step zero rather than discovering it as a wall of 403s.

## The single most useful fact

**Point your MCP client at this instance and the entire workspace becomes
tool-callable.** Search notes, read/write vault files, query the knowledge
graph, capture ideas, manage schedule events — all through one endpoint.

### MCP connection

```
URL:     http://<host>:3010/mcp
Auth:    Authorization: Bearer <mcp-key>
```

Both kinds of key live in **one** panel: **Settings → Connections & data → AI tools
(MCP)**. ("Connections & data" is the group; "AI tools (MCP)" is the panel.) The
instance key is at the top, named agent keys below it. Either can be revoked from
there, and both are scoped to this instance only.

### Two kinds of key — and only one makes you a principal

Both look like `gky_mcp_…`. **They are the same shape** — both come from the same
generator (`generateMcpKey()`), so you cannot tell which you were given by looking
at it. Ask the instance instead; see below.

| | **Named agent key** | **Instance key** |
|---|---|---|
| Minted by | The owner, in the panel's *Named agent keys* section — or by Companion v2.19.0+ for itself | The owner, at the top of the same panel |
| Your identity | **Pinned and verified.** `agent: { name: "<your name>", verified: true, identityMode: "named-key" }` | Self-declared from your MCP handshake `clientInfo.name`; `verified: false`, `identityMode: "self-declared"` |
| What that buys | Your note edits are attributed to *you*; `glassy_recall { scope: "mine" }` returns only your memories; `glassy_notify` and digests are signed with your name | Everything works, but authorship reads "MCP agent" and memory scope is coarse — one shared key, one identity for every client using it |
| Availability | Self-host only (cloud answers 403 `FEATURE_NOT_AVAILABLE`) | Everywhere |

**Ask for a named key if you will write anything.** Then verify what you actually
got — do not assume you are verified because you set a client name, and do not
infer it from the key's prefix, which cannot distinguish the two. Read the
`glassy://status` resource; it carries:

```json
{ "agent": { "name": "Hermes", "verified": true, "identityMode": "named-key" } }
```

`verified: false` means the instance is trusting a name you declared about yourself.
That is fine for reading; it is why your writes are attributed to "MCP agent" rather
than to you.

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

### The 40 tools

The count and the names are the **instance's**, not this document's — read them live with
`GET /mcp/status` (or `capabilities.mcp.tools`) and treat any number written here as
approximate. `scripts/check-mcp-claims.sh` fails CI when this file and the live registry
part, which is why the heading no longer carries a version stamp: it carried one pinned to
v2.40.4 and stayed on the page three releases later, and a stale stamp reads as a fresh
guarantee.

| Category | Tools |
|---|---|
| Search & retrieval | `glassy_search`, `glassy_obsidian_query`, `glassy_get_recent`, `glassy_get_backlinks`, `glassy_get_forward_links` |
| Memory (durable, yours) | `glassy_remember`, `glassy_recall` |
| Notes | `glassy_list_notes`, `glassy_read_note`, `glassy_note_create`, `glassy_note_update`, `glassy_note_delete` |
| Documents (long-form) | `glassy_list_documents`, `glassy_read_document`, `glassy_create_document`, `glassy_update_document` |
| Ask the owner | `glassy_request_review`, `glassy_get_review`, `glassy_withdraw_review` (self-host only) |
| Vault (live Obsidian files) | `glassy_vault_read`, `glassy_vault_append` |
| Knowledge graph | `glassy_graph_context`, `glassy_find_paths`, `glassy_get_orphans`, `glassy_get_central_notes`, `glassy_graph_stats` |
| Captures | `glassy_add_capture`, `glassy_capture_voice` |
| Bookmarks | `glassy_bookmark_update`, `glassy_bookmark_delete` |
| Schedule | `glassy_get_schedule`, `glassy_create_event`, `glassy_update_event`, `glassy_delete_event`, `glassy_find_free_slots` |
| Tags / folders | `glassy_get_tags`, `glassy_get_folders` |
| Proxy | `glassy_obsidian_proxy` |
| Awareness & digests | `glassy_notify` (self-host only, ≤10/min), `glassy_create_digest` |

`glassy_obsidian_query` and `glassy_obsidian_proxy` reach the operator's
Obsidian vault through the local REST API plugin — they work even when the
Glassy UI is not focused.

**Memory:** `glassy_remember` stores a durable memory (a note tagged
`agent-memory`, authored by YOUR pinned identity); `glassy_recall` retrieves it
(`scope: 'mine'` is your memories only; `scope: 'all-agents'` sees every agent's).
Recall before acting on a long-running task — the owner's preferences and
project state live there.

Read access is the default posture; write tools are available but the
operator controls the key.

### The 4 prompts (a separate surface from tools)

`prompts/list` is a **different call** from `tools/list`. A prompt is not a
function you invoke — it is an instruction template this server authors and hands
your client via `prompts/get`, which returns *messages* rather than data. Three
consequences worth knowing:

- **They cost nothing.** No model call happens on this instance, so a prompt
  never touches the operator's AI budget or the vault.
- **They cannot fail against your data.** A prompt returns text even if the vault
  is offline, the corpus is mid-reindex, or a note ID is wrong.
- **Two of them steer you back into the tools.** `glassy_daily_brief` and
  `glassy_daily_briefing` return instructions that tell you to call
  `glassy_get_recent` and `glassy_get_schedule` — they are scaffolding for a
  multi-step loop, not endpoints.

| Prompt | Arguments | Use it when |
|---|---|---|
| `glassy_summarize` | `text` (required, ≤50 000 chars), `format` ∈ `bullet` \| `paragraph` \| `tweet` \| `title` (default `paragraph`), `maxLength` (20–500 words, default 200) | You need a *consistent* summarization instruction rather than improvising one. `title` caps at 10 words; `tweet` at 280 chars. |
| `glassy_capture_prompt` | `url` (required, must parse as a URL), `contentType` ∈ `article` \| `video` \| `repo` \| `bookmark` (default `bookmark`) | You are about to save a URL and want the right extraction per type — `repo` asks for language/stars/license, `video` for creator and duration, `article` for thesis and 3–5 tags. |
| `glassy_daily_brief` | `date` (`YYYY-MM-DD`, defaults to today), `focus` ∈ `all` \| `bookmarks` \| `notes` \| `vault` (default `all`) | End-of-day review. Returns instructions to fetch the day's items via `glassy_get_recent`, group by topic, and suggest connections. |
| `glassy_daily_briefing` | `focus` (free text ≤500 chars, optional) | The owner wants their *day*, not their notes: a 5-line time briefing — meeting count, conflicts, first free block ≥30 min, one suggestion. Explicitly forbids inventing events. |

Note the near-duplicate names: **`glassy_daily_brief`** is about your knowledge
base, **`glassy_daily_briefing`** is about your calendar. They are different
prompts with different `focus` enums — `all|bookmarks|notes|vault` versus free
text. Calling the wrong one is the one mistake this table exists to prevent.

### The 9 resources (6 are not discoverable)

A resource is read **by URI**, with no tool call and no argument schema — useful
when you already know the identifier and want the payload. `resources/list`
returns **only the three static URIs**. The other six are `ResourceTemplate`s
registered with `list: undefined`, which means discovery will never surface them
and **you have to know the shape to use them**. This section is the only place
that shape is written down.

**Listable (returned by `resources/list`):**

| URI | Returns |
|---|---|
| `glassy://tags` | Unified tag cloud across notes, bookmarks, documents and voice — each tag with its count and source types. |
| `glassy://folders` | Bookmark collections and document folders with item counts: the owner's organizational hierarchy. |
| `glassy://status` | Knowledge-base health — corpus indexing progress, embedding counts, sync status. **Read this first when search results look thin**; a partially indexed corpus is a data problem, not a query problem. |

**URI templates (NOT returned by `resources/list` — construct them yourself):**

| URI shape | Returns |
|---|---|
| `glassy://notes/{id}` | One note: full content, tags and metadata as JSON. |
| `glassy://recent/{sourceType}` | Most recent items. `sourceType` ∈ `bookmarks`, `notes`, `all`. |
| `glassy://kb/search/{query}` | Ranked search results across every source type. |
| `glassy://vault/{path}` | A note from the **live** Obsidian vault, by vault-relative path — e.g. `glassy://vault/Notes/OAuth.md`. Needs Obsidian running or the Companion bridge. |
| `glassy://graph/note/{path}` | The **2-hop** knowledge-graph neighborhood of a vault note — links *and* backlinks — as JSON, served from the indexed corpus. |
| `glassy://calendar/today` | Today's events for visible calendars, as JSON. |

Two subtleties that cost real debugging time:

1. **`glassy://calendar/today` has no placeholder** but is still a template, so
   it is absent from `resources/list` alongside the parameterized six. "It isn't
   listed" never means "it doesn't exist" on this instance.
2. **`glassy://vault/{path}` and `glassy://graph/note/{path}` are different
   sources.** `vault` reads the *live* file through the Obsidian REST plugin and
   fails when Obsidian is closed; `graph/note` reads the *indexed* corpus and
   works offline but reflects the last reindex. For an edit you just made, use
   `vault`. For link structure, use `graph/note`.

Prefer the equivalent **tool** when you need filtering, pagination, or a write —
resources are read-only and take no options beyond the URI.

### Present your work through the Public Window (beta.36)

The intended loop when you produce an artifact the operator must LOOK at —
a design doc, a diagnostic report, a code-review summary:

1. `glassy_note_create` with `is_public: true` (same paid entitlement as the
   app's own publish button — on this appliance it is always allowed).
2. Open the browser AT the note: `#/w/<owner-slug>/<noteId>`. The signed-in
   owner lands directly on your work (beta.36 fixed the private-instance
   owner-view); an anonymous visitor is redirected to sign-in first and
   returned to the note afterwards.

A `canvas` note renders on this route as of **2.40.7** — before that the window
returned the canvas content and then rendered only the title and tags, so an agent
following an older brief may have concluded the window was broken. A canvas that
embeds an origin outside the instance's allowlist renders a refusal naming the
offender rather than the page; check `renderers.canvas.allowedOrigins` first.

No file archaeology for the operator, no "I wrote something somewhere" —
you put the artifact in front of them, already inside their knowledge layer.

### Hand over one artifact with no chrome (2.40.7)

When the owner needs to LOOK at exactly one thing — the report you just wrote, the
dashboard you just built — hand them `#/present/<kind>/<id>`, where `<kind>` is
`note`, `canvas` or `document`. It renders the artifact and nothing else: no sidebar,
no header, no back-link, no editor toolbar, no Save button to mis-click, no share or
report affordances. `Esc` (or the small `×`) leaves.

It is **owner-only**: a signed-out visitor is sent to sign in and returned to the
artifact afterwards. That is the difference from `#/w/<slug>/<noteId>`, which is the
public surface — use the window when someone else should see it, `#/present/` when the
owner should.

Read the kinds from the manifest instead of hardcoding them, because the manifest and
the route parser read the same file:

```bash
curl -s https://app.glassy.fyi/api/capabilities | jq '.capabilities.presentation'
```
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

### A write tells you which fields it ignored (2.40.7)

`warnings` on a note write response carries three codes, and they mean different things:

| code | what it says |
|---|---|
| `STRIPPED_AT_RENDER` | the content **was stored**, and the note-body renderer will remove that tag |
| `CANVAS_ORIGIN_BLOCKED` | the content **was stored**, and the canvas renderer will refuse the page over that origin |
| `IGNORED_FIELD` | the field **was not stored** — this endpoint does not write it |

The third is new, and it exists because `PATCH /api/notes/:id {"archived": true}` used
to answer `200 {"ok":true,"warnings":[]}` and change nothing: `archived` has its own
route, and the handler builds its patch from a fixed list, so any other key simply never
existed. A 200 that quietly dropped a field is the same class as a 201 that stores a tag
no renderer will show. The message names the door that does work — for `archived`, both
`POST /api/notes/:id/archive` and `glassy_note_update {archived}`. `id` in a body is
exempt: it is the path parameter echoed back, not a lost write.

**Over MCP the gap is still silent — read the schema.** An MCP tool's arguments are
validated by a zod schema that *strips unknown keys*, so a field `glassy_note_update`
does not advertise is discarded before the handler sees it and the tool answers
`success: true`. Making that loud is scoped as Task 1.3 of
`docs/superpowers/plans/2026-09-24-surface-contract-integrity.md` and is not built yet.
Until it is: the fields a tool advertises are the fields it writes, and
`GET /mcp/tools` is where to check (#109 and #112 were both this bug).


## Read what the instance can do before you write (2.38.0)

`GET /api/capabilities` describes the deployment: note types, limits, the
renderer allowlists **per surface**, what each renderer silently drops, accepted
upload types, the embedding chunk size and dimensions, the review-loop limits,
and the live MCP tool list. Read it instead of probing — every fact you cannot
read is a fact you discover by getting a 201 that does nothing.

## Canvas pages — publishing a live surface (2.39.0)

A `canvas` note is the one surface that may embed live content (dashboards,
charts, build logs) — normal notes cannot: their renderer strips `iframe`/`script`.
Create one with `glassy_note_create {type:"canvas", content:"<html…>"}` (the content
is HTML, not markdown). It renders on **four** surfaces, all through the same
renderer under the same embed policy: `#/canvas/<id>` for full-screen, the note
modal from Notes, and — since 2.40.7 — the Public Window at
`#/w/<owner-slug>/<noteId>` once the note is `is_public: true`, and the chrome-free
`#/present/canvas/<id>`. List them with `glassy_list_notes {type:"canvas"}`, read
with `glassy_read_note`.

The embed policy is an **origin allowlist**, and it is per-instance: self-host
defaults to LAN hostnames (`localhost`, `127.0.0.1`, `host.docker.internal`), cloud
is locked until an admin lists origins (`CANVAS_EMBED_ORIGINS`). A canvas that
references a non-allowlisted host refuses to render and names the offender — so
check `renderers.canvas.allowedOrigins` in the capabilities manifest before you
embed a third-party origin, and don't expect an arbitrary public URL to render.

**Publishing a canvas widens its audience — how much depends on the instance.** On
the hosted cloud product the window is unauthenticated, so your canvas script runs in
a stranger's browser. On a **self-hosted appliance** it does not: the appliance forces
`instanceAccessMode: 'private'` / `publicWindowsMode: 'members_only'` at boot, and an
anonymous visitor to `#/w/…` is redirected to sign in, so the audience is the owner and
any members they added.

Whichever instance you are on, your canvas keeps an **opaque origin** — no cookies, no
`localStorage`, no access to the parent page — and its `<script>` does execute (2.40.7
stamps the page's CSP nonce into the sandboxed document). Measured consequence worth
knowing: because the origin is `null`, a `fetch()` from your canvas to a Glassy API
path is **blocked by CORS**, so canvas script cannot call the instance's API. Embed a
`/widget/*` URL for live first-party data instead.

So do not put credentials, internal hostnames, raw connection strings or unredacted
diagnostics in a canvas you intend to publish, and check whether the instance you are
on is public before assuming the window is private.

```bash
curl -s https://app.glassy.fyi/api/capabilities | jq '.capabilities.renderers | keys'
# [ "ai-assistant-preview", "canvas", "help-article", "keep", "note", "window", "writing" ]
curl -s https://app.glassy.fyi/api/capabilities | jq '.capabilities.renderers.keep'
curl -s https://app.glassy.fyi/api/capabilities | jq '.capabilities.renderers.canvas.allowedOrigins'
```

**Seven** renderer configs exist in this product — do not assume the note
renderer's allowlist applies to the keep/bookmark render (that assumption has
cost real debugging time), and do not assume the note renderer's allowlist
applies to *canvas* either, which is the point of this section. Each entry
carries `allowTags`, `allowAttrs`, `discardBehavior` (`silent-drop` = the tag
vanishes at render after a successful write; `prompt-only` = it constrains model
output), `stripsAtRender`, `warnsAtWrite`, and `warnCodes` — the warning codes that
surface can put on a write response. **Two surfaces warn, each about its own policy:**
`note` emits `STRIPPED_AT_RENDER` (the tag allowlist), and `canvas` emits
`CANVAS_ORIGIN_BLOCKED` (the origin allowlist) — see the canvas section above. `keep`
also distinguishes validated embeds (`embeds: ["youtube","vimeo"]`) from user
`<iframe>`s, which are stripped.

`canvas` is the exception that proves the rule, and the reason the count is seven
and not six: it has **empty** `allowTags`/`allowAttrs` because there is no tag
allowlist to have — a canvas renders the operator's own raw HTML inside a
sandboxed iframe, gated on `originPolicy: "allowlist"` instead, and it is the
**one** surface with `userIframes: true`. The manifest attaches its *effective*
per-instance allowlist as `renderers.canvas.allowedOrigins` (plus `locked` and
`configured`), because that list depends on this deployment and cannot be frozen
into the module.

**What a canvas write warns about (2.40.7).** A canvas is *not* a note body, so it
does **not** get `STRIPPED_AT_RENDER` — that code describes the note renderer's tag
allowlist, which never reads canvas content. No sanitizer strips your `<script>` or
`<iframe>`. What a canvas *is* warned about is the
gate that really applies: if the content references an absolute origin outside
`renderers.canvas.allowedOrigins`, the write response carries
`{code: "CANVAS_ORIGIN_BLOCKED", field: "content"}` naming the hosts, because the
renderer then refuses the **whole page** rather than dropping one embed. Before 2.40.7
a canvas write got the note body's warning instead, which said the opposite of the
truth ("the note will not show it") while the manifest said `warnsAtWrite: false` —
if you built tooling that deleted "invisible" canvas content on the strength of that
warning, the content was live and the warning was wrong (#138).

**What a canvas can and cannot do (2.40.7, all of it measured in a browser).** "Not stripped" is
not the same as "will render" — a canvas renders inside `srcDoc` under
`sandbox="allow-scripts allow-forms"`, deliberately *without* `allow-same-origin`, so its document
has an **opaque origin** and inherits the app's CSP. That combination produced #140, and both halves
are now fixed:

- **Your inline `<script>` executes.** The server mints a CSP nonce per response and the renderer
  stamps it on your script tags automatically — you write plain `<script>`, you do not need to know
  the nonce. Before 2.40.7 every canvas script was silently dropped (`script-src` allows inline
  script only by hash or nonce, and no hash can be precomputed for content authored at runtime).
- **You can frame appliance data through `/widget/*`.** A canvas cannot frame an ordinary Glassy
  endpoint: those responses say `frame-ancestors 'self'`, and an opaque origin is not `self` — no
  CSP value can name one (`frame-ancestors *` does not work either; `*` matches only network-scheme
  URLs). `/widget/health` and `/widget/instance` are the frameable surface: public, read-only,
  script-free, no user data. Read the list from
  `capabilities.renderers.canvas.frameableWidgets` rather than hardcoding it. A *relative* URL
  (`src="/widget/health"`) always passes the origin gate; an absolute one must be on
  `renderers.canvas.allowedOrigins`.
- **First-party images work** — relative `/uploads/...`, absolute `http://<host>/uploads/...` and
  `data:` URIs all render. (#140 reported these broken; that layer did not reproduce, and the brief
  said so rather than quietly dropping it.)
- **What you still cannot do:** frame an arbitrary `/api/*` endpoint (use `/widget/*`, or fetch and
  render it yourself now that script runs), and reach anything outside the canvas. The sandbox is
  unchanged, so from inside a canvas `window.parent.localStorage` throws `SecurityError` — no JWT, no
  cookies, no parent DOM — and `postMessage` to the app is rejected, because both of the app's
  message listeners compare origins and an opaque origin matches neither. `capabilities.renderers.canvas.inlineScript`
  publishes all of this, including `sandboxOrigin: "opaque"`.

If you designed around the 2.40.6 behaviour — baked-in snapshots because script would not run — that
workaround still works, but it is no longer required.

> **Corrected 2026-09-29:** this section previously understated the renderer
> count and printed a `keys` example without `canvas` — inside the very section
> about canvas, directly above the instruction to check
> `renderers.canvas.allowedOrigins`. The live manifest always returned the true
> set; only the prose and the example were wrong. If a `jq` output in this file
> disagrees with your instance, **believe your instance** and re-run the command.

Every value is read from the module that enforces it, and the renderer mirror is
checked against the browser's own config by test, so the manifest cannot drift
away from what the app actually does.

## Asking the owner a question (2.38.0)

**Self-host only.** All three review tools are gated: on cloud they are absent from
`tools/list` and answer `403 FEATURE_NOT_AVAILABLE` if called by name, because the queue
they terminate in is not served there and an owner cannot open it. On cloud, write the note
and tell the owner where to look instead.

Do not guess when a decision is the owner's. Ask, and keep working elsewhere
while you wait:

1. `glassy_request_review` with `question`, optional `choices` (2–10 distinct
   strings; default `["yes","no"]`), and — when the question is about a specific
   item — `linked_type` (`note`|`document`|`canvas`) plus `linked_id`. The owner sees the
   item rendered next to your question. A canvas is addressed by its note id; the link
   opens the canvas surface rather than the note editor.
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

**Prefer archive when you are tidying your own output (2.40.7).** `glassy_note_update
{id, archived: true}` files a note away and is fully reversible with
`{archived: false}` — the note keeps its content, its id and its embeddings, stays
readable with `glassy_read_note`, and simply stops appearing in `glassy_list_notes`
unless you pass `include_archived: true`. Over REST the same flag is
`POST /api/notes/:id/archive {"archived": true|false}`, and archived notes are listed
by `GET /api/notes/archived`. This is the lane that was missing before 2.40.7: MCP
could read the flag and could soft-delete, but the only cleanup an agent could perform
was destructive and had no agent-reachable undo. Archiving is a state transition, not
an edit — it does not re-embed the note and does not count against a content change —
but it does record who filed it, so the owner can see that an agent did (#137).

**The bin is excluded from every read lane (2.40.7).** Once you have soft-deleted a note it is not
returned by `glassy_list_notes`, `glassy_read_note`, `glassy_search`, `glassy_recall` or
`glassy_get_recent`, nor by REST `/api/notes`. `glassy_get_recent` was the last lane that leaked
binned notes — it filtered `archived` but not `deleted_at`, which are two different flags — so a
daily brief could resurrect notes you had already cleaned up (#139). Note that `archived` and
deleted are **not** the same state: an archived note is live and readable, a deleted one is in the
bin. Bookmarks have only one flag, `is_archived`, which *is* their trash. (`glassy_search` excludes
binned notes by a different mechanism: deleting a note also removes its embeddings, so there is
nothing left for the corpus index to match.)

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

**Filtering by tag is an EXACT whole-tag match (2.40.7).** `glassy_list_notes
{tag: "…"}` matches a tag in full — case-insensitive, whitespace trimmed — so
`tag:"memo"` returns the notes tagged `memo` and **not** the ones tagged
`agent-memory`. Before 2.40.7 the match was a substring test applied in JS to the
newest `limit×4` rows, which made the filter wrong in both directions at once: it
over-returned (`tag:"pen"` answered every note tagged `open`; `tag:"memo"` answered
26 rows when 17 carried it) and it under-returned (a matching note older than that
window was invisible, and `hasMore:false` reported the bounded search as a complete
answer). The predicate is in SQL now, so the window is gone and `hasMore` describes
the query. **If you relied on prefix matching, enumerate tags with `glassy_get_tags`
and filter on the values that exist** — a fragment that used to "work" was returning
notes that did not carry it (#136).


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

Facts that make the recipe work, in case the fields are already filled oddly:

- **`host.docker.internal` only resolves because the compose maps it**
  (`extra_hosts: ['host.docker.internal:host-gateway']`). The bundled appliance
  compose has it; **the Tailscale overlay does not** — on `docker-compose.tailscale.yml`
  use the host's tailnet name or IP instead.
- **Ports by framework:** Hermes `8642` (default profile; profile installs often
  `8643`), OpenClaw `18789`. Antigravity is the cloud framework — it needs a
  Google API key and no local gateway at all.
- **`GET /api/agents/activity`** is where the dispatch log lives (action,
  `task_text`, `response_text`, timestamp). A dispatch that "did nothing" is
  usually visible there as an `error` row with the upstream message.
- **SSRF posture differs by instance, deliberately:** the hosted tier accepts only
  `localhost`, `127.0.0.1`, `::1`, `host.docker.internal`; a **self-hosted**
  instance accepts any host (`getAgentSsrfOptions`, `server/utils/urlValidator.js`),
  which is what allows a LAN or Tailscale address. Don't "fix" a self-host baseUrl
  to loopback to satisfy a validator — that is the bug, not the fix.
- **From 2.39.0** the appliance's framework selector offers OpenClaw and Hermes.
  Before that they were gated on the Clear instance identity, which an appliance
  never reports, so only Antigravity was selectable (#85).

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
- **Updates:** pinned `GLASSY_TAG` (currently `v2.40.4`); do not float
  `latest` on self-host (it is the hosted build and omits self-host
  features). **Three versions in `CHANGELOG.md` have no GHCR image and must
  never be pinned:** `v2.36.0-beta.41` (its tag push landed inside a transient
  Actions outage, and beta.42 contains all of beta.41's work plus the TOTP
  fix), `v2.39.0` (prepared as a release and deliberately not launched — its
  canvas and bulk-ingest work shipped in `v2.40.0`) and `v2.40.1` (never tagged;
  its work shipped in `v2.40.2`). Those headers are annotated in the changelog
  itself, and `scripts/version-check.js` now fails a build that adds another one
  silently. Pin a version the registry actually has.
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
- **Two ways to put something in front of a human, and they are not interchangeable.**
  `#/w/<slug>/<noteId>` is the Public Window: it renders every note type including
  `canvas` (2.40.7), and it is the surface for when *other people* should see the work.
  On a self-hosted appliance it is forced members-only at boot, so "public" means the
  owner and any members — not the internet. `#/present/<kind>/<id>` is chrome-free and
  owner-only: one artifact, no sidebar, no Save button, `Esc` to leave. Use it for review
  handoff. Read `capabilities.presentation.kinds` for the valid kinds rather than
  hardcoding them.

## Suggested first actions for an agent

1. `glassy_search` the operator's workspace ("README", "VAULT POLICY").
2. `glassy_get_tags` + `glassy_get_folders` to map the namespace.
3. `glassy_vault_read` a file the operator references.
4. For scheduling work: `glassy_get_schedule` before proposing an event.
5. When you have produced something the operator must LOOK at, hand over a URL rather
   than a description: `#/present/<kind>/<id>` for one artifact with no chrome, or
   publish it (`is_public: true`) and use `#/w/<slug>/<noteId>` when the audience is
   wider than the owner.

Be careful with `glassy_note_delete` / `glassy_bookmark_delete` /
`glassy_vault_append` — they mutate the operator's real data. Prefer
create/update and confirm destructive intent with the operator *before* the call:
a note delete is recoverable (soft-delete to the bin) but only the **owner** can
restore it, and a `vault_append` writes straight into the operator's Obsidian
files with no bin at all.

## Reporting a defect

You are expected to file defects, and your reports are triaged against source — not
against a summary. File **one issue per finding** in `0Reliance/glassy` and include
all five of:

1. the exact surface (`/api/...` path or MCP tool name) and the exact request;
2. the observed response, **verbatim** — copy the body, do not paraphrase it;
3. the expected response and **which document or schema promised it**, with file and
   line. "This brief says X" is the most useful sentence you can write: it turns a bug
   into contract drift, which is a faster and more complete fix;
4. `GET /api/instance` and `GET /api/capabilities` output — a self-host-only defect and
   a cloud one are different defects;
5. reproduction steps that do not depend on your own state. Seed what you used.

If it concerns the appliance-only capability set (named keys, memory, notifications,
external corpora), run `scripts/verify-selfhost-capabilities.sh` from the repo and paste
its output. Sixteen checks with evidence lines beats a paragraph of prose, and it
establishes immediately whether your instance is in the posture you think it is.

You will get a verdict — **CONFIRMED / NOT CONFIRMED / WITHDRAWN / UNVERIFIED** — citing
the source it was checked against. If you were wrong, say so in the issue: the correction
is kept and dated, because that is what makes the next report believable. The full
contract is
`docs/investigations/2026-09-23-two-agent-field-intake-protocol.md` in the Glassy source repository.
