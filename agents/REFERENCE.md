# Agent reference

The full contract for an agent working in Glassy: how you connect, who you are, every tool,
prompt and resource, what a write returns, and how to ask the person a question.

This is the long, precise half. If you have not read [USE.md](USE.md), read that first: it is
short and says how to behave. Come here when you need the exact shape of something.

Addresses in this file use `http://localhost:3000`, the default for a self-host. If the person
changed the port or reaches Glassy by another name, use theirs. The numbers in this file (tool,
prompt and resource counts) are checked against the code on every release, and `GET /api/capabilities`
on the running Glassy is always the final word.

> **The second brain is yours too.** Glassy is one workspace for a person and their agents. You
> get durable **memory**, your own named identity, and a way to **ask** the person a question and
> get a click back. On a self-host you are a full participant. On Glassy's cloud some things are
> withheld (named keys, notify, the question tools); that is by design, and `/api/capabilities`
> tells you which you are talking to.

## Start here — two things are called "vault", and five ways to be "an agent"

The two words that trip up the most agents are **vault** and **agent**, because each means
several different things here. Resolve both before you pick a tool.

**"Vault" means three things.** Glassy is one workspace, but "vault" is overloaded:

| When you hear "vault" | What it actually is | The tools |
|---|---|---|
| **Your Glassy Vault** (native context) | Glassy's *own* store — notes, documents, durable memory, and the searchable corpus. This is Glassy being your knowledge base, with no Obsidian anywhere. **If you use Glassy instead of Obsidian, this is your vault.** | `glassy_search`, `glassy_remember`, `glassy_recall`, `glassy_note_create`, `glassy_note_update`, `glassy_create_document` |
| **The Obsidian Vault** (external bridge) | A *separate* Obsidian vault on the operator's machine, reached through the Local REST API plugin or the Glassy Capture extension's bridge. | `glassy_vault_read`, `glassy_vault_append`, `glassy_obsidian_query`, `glassy_obsidian_proxy` |
| **The vault-provider lane** (no Obsidian) | On a self-host with no Obsidian, `glassy_vault_read`/`glassy_vault_append` dispatch to the agent the operator marked the vault provider — that agent holds the filesystem. | `glassy_vault_read`, `glassy_vault_append` (routed to the provider) |

The trap, named plainly: **`glassy_vault_read` does not read your Glassy Vault.** The
`glassy_vault_*` tools reach the *Obsidian* store (or the vault-provider agent), never
Glassy's own notes and memory. If you want Glassy's native context, use `glassy_search` /
`glassy_remember` / `glassy_recall` / the `glassy_note_*` tools — those are the "use Glassy
as your second brain" lane.

**"Agent" means five roles**, and the credential the human handed you is how you tell which
is yours:

| You were given | You are | Your section |
|---|---|---|
| A `gky_mcp_…` key + `http://localhost:3000/mcp` | An MCP client — you call *into* Glassy | [MCP connection](#mcp-connection) |
| A dispatch connection the owner added under Settings → Agent dispatch | A dispatch target — Glassy calls *you* over a harness transport | [Connecting an agent as a dispatch target](#connecting-an-agent-as-a-dispatch-target) |
| The owner flipped "Set vault provider" on your connection | The vault provider — you hold the files | [No-Obsidian operators](#the-42-tools) |
| A named agent key, on `GET /api/*` (and writes to notes and documents) | A REST script | [The same named key also reads the REST API](#the-same-named-key-also-reads-the-rest-api) |
| The first password, or you're installing | Acting for the owner | [INSTALL.md](INSTALL.md), then [CONFIGURE.md](CONFIGURE.md) |

Whichever you are, read `GET /api/capabilities` first — it names what *this* instance
actually serves, so the machine tells you your boundary instead of you guessing it from
prose.
## What this is

A **self-hosted Glassy instance** — a private notes / knowledge
base / scheduling workspace with an AI integration layer. It ships its own
**MCP server** with three surfaces, not one:

- **42 tools** — 37 registered everywhere; `glassy_notify` and the four review
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
dependency except one check of the person's Glassy account when it starts (cached for 30 days).

## First sign-in on a new install

A new self-host refuses every signed-in call with `403 PASSWORD_CHANGE_REQUIRED` until the first
password is changed. The steps, and what to do when you are the one installing, are in
[CONFIGURE.md](CONFIGURE.md#1-first-sign-in).

## The single most useful fact

**Point your MCP client at this instance and the entire workspace becomes
tool-callable.** Search notes, read/write vault files, query the knowledge
graph, capture ideas, manage schedule events — all through one endpoint.

### MCP connection

```
URL:     http://localhost:3000/mcp
Auth:    Authorization: Bearer <mcp-key>
```

Both kinds of key live in **one** panel: **Settings → Connections & data → Agent
access (MCP)**. ("Connections & data" is the group; "Agent access (MCP)" is the panel.) The
instance key is at the top, named agent keys below it. Either can be revoked from
there, and both are scoped to this instance only.

### Two origins — appliance (full power) and cloud (the on-the-go lane)

The same MCP server serves **two origins** with deliberately different shapes.
`GET /api/capabilities` tells you which one you are talking to (`mcp.mounted`,
`mcp.cloudGatedTools`, `agentIdentity.mode`) — read it before assuming.

| | **Appliance** (`http://localhost:3000/mcp`) | **Cloud** (`https://app.glassy.fyi/mcp`, `https://clear.glassy.fyi/mcp`) |
|---|---|---|
| Key model | Named per-agent keys + instance key — ask for a named key if you will write | **Single user-scoped key** — the account owner's own key, minted in Settings → Agent access (MCP). Named keys are not offered here |
| Identity | Named keys are pinned and verified; the instance key is self-declared | Self-declared (`identityMode: "self-declared"`, `verified: false`) — you act as the account owner's MCP client |
| Tools | All 42 | 37 — `glassy_notify` and the review-queue tools are withheld (403 `FEATURE_NOT_AVAILABLE` if you try; the manifest names them in `cloudGatedTools`) |
| Budget | No tool-call budget — the owner's hardware | Tier-rated by `mcpTierLimiter`: free accounts 120 calls/hour, paid accounts 1,200/hour |
| Search corpus | The owner's corpus, locally indexed | The owner's corpus, searched with the search model that workspace declared, or by words alone if it has none |

The cloud lane exists so an agent you run while traveling can reach the same
workspace from any machine — not as a second identity. One key per account,
replacing on re-mint; if the owner rotates it, your calls fail auth until they
hand you the new key.

### Two kinds of key — and only one makes you a principal

Both look like `gky_mcp_…`. **They are the same shape** — both come from the same
generator (`generateMcpKey()`), so you cannot tell which you were given by looking
at it. Ask the instance instead; see below.

| | **Named agent key** | **Instance key** |
|---|---|---|
| Minted by | The owner, in the panel's *Named agent keys* section — or by the Glassy Capture extension (v2.19.0+) for itself | The owner, at the top of the same panel |
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

**A named key may be read-only (W-2).** The operator can mint a key with scope
`read` — it can query, search, list and recall, but every write tool answers a
machine-readable `scope_denied` (`errorClass: "scope_denied"`). `glassy://status`
reports the scope. A read-only principal is the right choice for an agent the owner is
still getting to know; a full key (`read` + `write`) is the default and unchanged.

**The config snippet prefers the named key.** The snippet the operator pastes
into your client (`GET /api/agents/:id/config`) used to always carry the anonymous
instance key; it now prefers the operator's named key, accepts `?agentName=` to pin a
specific one, and reports `key: named|legacy` (plus `agentName` when named) so the
operator can see which principal you'll actually be. If the snippet says `key: legacy`,
ask for a named key before writing anything — your writes will otherwise be attributed
to "MCP agent" and `glassy_recall {scope:"mine"}` will come back empty.

### The same named key also reads the REST API

On a **self-host** instance a named key authenticates `GET /api/*` directly, so a
script no longer has to log in with the owner's email and password to get a JWT:

```bash
curl -s http://localhost:3000/api/notes \
  -H "Authorization: Bearer gky_mcp_..."      # the same key you use for /mcp
```

The boundary is deliberate and narrow — learn it once and stop probing for it:

- **Writes: notes and documents only (2.64.0).** `POST`/`PUT`/`PATCH`/`DELETE` under
  `/api/notes` and `/api/documents` work with a key that has write access, and the item is
  recorded as written by you (your agent name, `created_by_kind: "agent"`), exactly as
  through MCP. Both lanes write through the same services (`noteService`,
  `documentService`), so a field cannot mean one thing on REST and another on MCP. A document you create without a folder goes into "Agent work". Every
  other surface refuses a write with `403 {"code":"AGENT_KEY_READ_ONLY"}`, and so does a
  key made read-only. Before 2.64.0 the whole lane was read-only, which pushed agents
  onto the owner's sign-in for REST writes and recorded their work as the owner's: never
  do that.
- **Self-host only.** `GET /api/capabilities` → `agentIdentity.restReadLanes` says
  whether this instance has the lane. On cloud it is `false` and the lane is not
  attempted at all, so a key there gets the ordinary `401 AUTH_TOKEN_INVALID`.
- **Your account is pinned.** The key resolves into the account it was minted under,
  exactly as it does on MCP, and an `X-Account-Id` header will NOT move it. You cannot
  roam accounts by editing a header.
- **Every gate still applies.** `password_must_change` (the first-boot wall), the
  inactivity lock and the account PIN lock are all enforced on this lane, so a key is
  never a way around them.
- **You are attributed.** Reads carry `auth_via: "named-key"` and your agent name
  server-side, which is the point: your traffic is distinguishable from the owner's
  instead of wearing their identity, and your writes are credited to you.
- **Header only.** A key in a query string is never accepted — it would land in every
  access log and proxy log on the way.

What this replaces, and why it matters operationally: a JWT dies whenever the install
rotates `JWT_SECRET`, which every clean install does, so scripted integrations used to
break all at once and fall back to re-authenticating with the owner's raw password. A
named key is rotated deliberately, one agent at a time, and revoking it does not touch
anyone else.

Client setup — each client takes a different shape (the settings panel shows all three):

- **Claude Desktop** launches local (stdio) servers only; a `url` entry in
  `claude_desktop_config.json` is ignored. Reach Glassy through the `mcp-remote` bridge
  (Node.js required); the key goes in an env var because Claude Desktop on Windows does not
  escape spaces inside `args`. Add `"--allow-http"` to `args` for a plain-http appliance
  reached by anything other than `localhost`/`127.0.0.1`. Restart Claude Desktop after editing.

```json
{
  "mcpServers": {
    "glassy": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://localhost:3000/mcp", "--header", "Authorization:${GLASSY_AUTH}"],
      "env": { "GLASSY_AUTH": "Bearer gky_mcp_..." }
    }
  }
}
```

- **Claude Code:** `claude mcp add --transport http glassy http://localhost:3000/mcp --header "Authorization: Bearer gky_mcp_..."`
- **Cursor** reads `url` + `headers` directly:
  `{"mcpServers": {"glassy": {"url": "http://localhost:3000/mcp", "headers": {"Authorization": "Bearer gky_mcp_..."}}}}`

### The 42 tools

The count and the names are the **instance's**, not this document's — read them live with
`GET /mcp/status` (or `capabilities.mcp.tools`) and treat any number written here as
approximate. This table is checked against the tool registry on every release.

| Category | Tools |
|---|---|
| Search & retrieval | `glassy_search`, `glassy_obsidian_query`, `glassy_get_recent`, `glassy_get_backlinks`, `glassy_get_forward_links` |
| Memory (durable, yours) | `glassy_remember`, `glassy_recall` |
| Notes | `glassy_list_notes`, `glassy_read_note`, `glassy_note_create`, `glassy_note_update`, `glassy_note_delete` |
| Documents (long-form) | `glassy_list_documents`, `glassy_read_document`, `glassy_create_document`, `glassy_update_document`, `glassy_delete_document` |
| Ask the owner | `glassy_request_review`, `glassy_get_review`, `glassy_withdraw_review`, `glassy_report_review_outcome` (self-host only) |
| Obsidian Vault (live files) | `glassy_vault_read`, `glassy_vault_append` |
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

**Reference codes.** Every note and document has a short, human-readable `ref`
(an 8-character code like `7K3MQPZ2`) alongside its full `id`. The owner can
click-to-copy it from the card's hover badge and hand it to you. Wherever a
tool takes an `id` for a note or document — `glassy_read_note`,
`glassy_read_document`, `glassy_note_update`, `glassy_update_document` — you
may pass the `ref` instead (bare, or `note:`/`doc:`-prefixed, e.g.
`note:7K3MQPZ2`). List/read/recall responses surface the `ref` so you can cite
the short code back to the owner rather than the full UUID.

**No-Obsidian operators (an agent as the vault provider).** On a self-host, the
operator may declare one dispatch connection the *vault provider*
(`config_json.vaultProvider: true`). Then `glassy_vault_read` / `glassy_vault_append`
dispatch to that agent — which holds the filesystem — instead of failing on the missing
Obsidian stack. The contract is deterministic: a `[glassy-vault-provider]` instruction
naming the path and verb, answered with the file contents (read) or `OK`/an error (write),
`NOT_FOUND` when absent. `glassy_obsidian_proxy` still requires the FULL Obsidian stack and
does not use the provider. If you are told to reach a vault on such a setup, use
`glassy_vault_read`/`glassy_vault_append` and let the provider agent do the filesystem
work — do not invent a stand-in MCP server behind `obsidian_url`. `GET /api/capabilities` reports
`agentIdentity.agentVaultProvider` so you can check rather than guess.

**Memory:** `glassy_remember` stores a durable memory (a note tagged
`agent-memory`, authored by YOUR pinned identity, in your own space); `glassy_recall` retrieves it
(`scope: 'mine'` is your memories only; `scope: 'all-agents'` sees every agent's).
Recall before acting on a long-running task — the owner's preferences and
project state live there. **The lifecycle facts that keep the store usable**
(all measured in the field; none of them said in the tools' names):

- **A just-written memory is not instantly searchable.** Embedding is
  asynchronous, so there is a short window where the write succeeded and
  `glassy_search` does not return it. A search that misses a memory you just
  committed is a timing fact, not a reliability defect — wait for the embed
  and search again before concluding it is gone. On 2.46.0+ a silently-failed
  embed also HEALS within the hour: the corpus reconciler sweeps anything a
  write path missed at :15 past each hour (operator opt-out:
  `ENABLE_CORPUS_RECONCILER=false`), so a search that keeps missing committed
  content is worth one retry after the next pass.
- **Write as yourself, never through the person's login (2.64.0).** Glassy is
  one workspace for a person and their agents, and it tells them apart by who
  wrote each item. Anything you file through the owner's session or password is
  recorded as *them*: their search bar's "me" chip shows it as their own work,
  and no agent's `exclude_mine` can leave it out. Write with your named key, through
  MCP or the REST lane for notes and documents.
- **Your documents go into "Agent work" (2.64.0).** `glassy_create_document`
  (or a REST `POST /api/documents` with your key) without a `folder_id` files the
  document in the workspace's "Agent work" folder, made on first use, so the person's own documents stay in front in
  Docs. Name a folder when the document belongs with the person's own work.
- **Three places: shared, archive, your own (lanes, 2.65.0).** Every note and
  document lives in one of them, and you choose with `place` on
  `glassy_note_create` / `glassy_create_document` (`"shared"` | `"own"`) and on
  `glassy_note_update` / `glassy_update_document` (`"shared"` | `"archive"` | `"own"`;
  send `place` or `archived`, not both). Over REST: `POST /api/notes/:id/place` and
  `POST /api/documents/:id/place` with `{"place": …}`.
  - **shared** — the working space. Work the person should see: reports, replies,
    documents written for them. The default for everything except memories.
  - **archive** — filed away and still searched, by the person, by you and by the AI
    assistant, a little below current work that matches as well.
  - **own** — your own space: memories (`glassy_remember` writes here), scratch, run
    state. Kept out of the person's notes, documents, search and AI assistant so it
    never crowds their work. Agents still see it (`glassy_search`, `glassy_recall`,
    your key's lists), and it is **never secret**: the person sees each agent's own
    space in Settings → Agent access (MCP) and can move anything into their workspace.
- **Archive your working papers when their job is done** — plans, receipts,
  checklists, staging and release reports. Search and the AI assistant still find
  archived items (labelled, a little below current work that matches as well);
  the everyday lists leave them out.
- **Archive rather than delete your own output.** `archived` is a reversible
  flag you can clear yourself (`{archived: false}`); delete moves the note to
  the bin and **restore is owner-only** — from your side a delete is
  permanent. This asymmetry is the whole reason to prefer archive for tidying.
- **Namespace fixtures, and tear them down in the same session.** A store
  that accumulated 295 of 332 fixture notes in the field degraded search
  ranking for the real entries. Tag test/dogfooding memories distinctly
  (`walk-*`-style names) and delete/archive them before you finish.
- **A ranked hit is a candidate, not a fact.** As of v2.45.0 `glassy_search`
  drops candidates whose backing row is gone and merges same-source hits that
  both legs labeled differently — but citing a source as evidence
  still costs one `glassy_read_note` / `glassy_vault_read` to confirm it
  exists and says what the snippet claimed.

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
| `glassy://vault/{path}` | A note from the **live** Obsidian vault, by vault-relative path — e.g. `glassy://vault/Notes/OAuth.md`. Needs Obsidian running or the Glassy Capture extension's bridge. |
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

### Present your work through the Public Window

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

### Hand over one artifact with no chrome

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
curl -s http://localhost:3000/api/capabilities | jq '.capabilities.presentation'
```
Un-publish any time with `glassy_note_update { is_public: false }`.

### Hand over a LIVE note to a chat surface (render lane)

The deep links above require an owner session, and a desktop host (a chat
transcript, an MCP host UI) often has a `file://` renderer origin that can never
satisfy CORS. For those, the instance exposes a **read-only render lane**: a
scoped, revocable, expiry-bounded token that serves ONE note's sanitized rendered
HTML, frameable by any surface.

- The owner's host mints a token with owner credentials:
  `POST /api/render-token/note/:id` → `{ token, expiresAt, url }` (the raw token is
  shown once; only its hash is stored).
- The host frames `GET /widget/render/<token>`. It is GET-only, script-free
  (`script-src 'none'`), strips scripts/media and external images (an IP-leak
  guard), and carries no frame-ancestors/X-Frame-Options so an opaque-origin frame
  can show it.
- Revoke with `DELETE /api/render-token/note/:id`.

As an agent, you do not usually mint this yourself — you hand the owner the deep
link and the owner's host mints the render token. If you must show content in a
surface that cannot host a live fetch, the blessed fallback is a **mirror file**:
write a local HTML copy of the note and render it through the host's own
authenticated file bridge. Prefer the render lane when you can; it is the LIVE note,
not a copy.

### The parameterized deep links an agent needs

The screen-level route map (`#/notes`, `#/today`, …) cannot express the three
parameterized families an agent hands an owner most often. They are published
under `capabilities.navigation.deepLinks` (read from the same map the app uses):

```bash
curl -s http://localhost:3000/api/capabilities | jq '.capabilities.navigation.deepLinks'
# { "#/notes/:id": "…", "#/present/:kind/:id": "…", "#/w/:slug/:id": "…" }
```

Read them from the manifest rather than hardcoding — that is how you avoid re-asking
for a route that already shipped.

### Before you file an issue

Run a **premise-check** first: confirm the behaviour against the live manifest and
the brief before filing, and say which surface you measured and what you expected. A
report that a feature "does not exist" when it is merely undiscoverable re-opens
already-shipped work; a "bug" that is a working-as-designed boundary is a design
question, not a defect — name which it is.

## The Obsidian Vault bridge (external, optional)

This is the lane for reaching an *external* **Obsidian Vault** — the operator's own
Obsidian files. It is **not** your Glassy Vault: Glassy's native notes, memory and corpus
are a separate store you reach with `glassy_search` / `glassy_remember` / `glassy_recall` /
`glassy_note_*`. Use this section only when the operator already lives in Obsidian; if you
are using Glassy *instead of* Obsidian, skip it — your vault is Glassy itself.

Two paths exist, both verified connected in beta.42:

1. **Direct REST** — Glassy ↔ Obsidian Local REST API plugin
   (`http://127.0.0.1:27123` by default). Fast, works when Obsidian is
   running.
2. **Extension bridge** — the Glassy Capture browser extension (v2.18 or newer) proxies
   requests through an offscreen document. This is the path used when the
   operator browses Glassy in the browser and reaches Obsidian from the
   UI.

As an agent you don't need to care about the transport — call the Glassy
tools and the server picks the path.

## Write-path contract

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

### A write tells you which fields it ignored — and which values it changed

`warnings` on a note write response carries **four** codes, and they mean different things:

| code | what it says |
|---|---|
| `STRIPPED_AT_RENDER` | the content **was stored**, and the note-body renderer will remove that tag |
| `CANVAS_ORIGIN_BLOCKED` | the content **was stored**, and the canvas renderer will refuse the page over that origin |
| `IGNORED_FIELD` | the field **was not stored** — this endpoint does not write it |
| `VALUE_COERCED` | the field **was stored as a default** — the value you sent was not a valid option |

`IGNORED_FIELD` exists because `PATCH /api/notes/:id {"archived": true}` used to answer
`200 {"ok":true,"warnings":[]}` and change nothing: `archived` has its own route, and the
handler builds its patch from a fixed list, so any other key simply never existed. The
message names the door that does work — for `archived`, both `POST /api/notes/:id/archive`
and `glassy_note_update {archived}`. `id` in a body is exempt (it is the path parameter).

`VALUE_COERCED` (2.43.0) is the same honesty rule applied to *values* instead of *keys*:
`transparency`, `border_style` and `content_format` are enumerated, and a value outside the
enum (e.g. `transparency: "glasss"`) is **normalized to a default** — not rejected, so old
rows and sync upserts survive — but the response now *says so* instead of silently storing
the default. The valid enums are published at `capabilities.notes.contentFormats` and the
message names the allowed set.

**Over MCP this is loud too now (2.43.0).** The `glassy_note_update` /
`glassy_update_document` schemas are `.passthrough()` with `openWorldHint: true`, so an
unknown key reaches the handler and is reported as `IGNORED_FIELD` instead of being
stripped by zod into a confident `success: true`. The fields a tool advertises are the
fields it writes — `GET /mcp/tools` is still the authoritative list, but a key that is
*not* advertised now comes back as a warning rather than vanishing.

### The read lane has its own honesty channel: `degraded[]`

Writes carry `warnings[]` (above); **reads degrade visibly too.** When the embedding
(semantic) lane returns less trust than it intended, the response reports it in-band
instead of silently thinning out: `glassy_search` carries a `degraded[]` array
(present only when something degraded; absence means the lane was healthy), and `POST /api/kb/query` returns the same shape as
`diagnostics.degraded`. The recorded live example:

```json
"degraded": [{
  "leg": "semantic",
  "code": "SEMANTIC_GATE_COLLAPSE",
  "detail": "only 3 of 56 candidate chunks survived the semantic gate at minScore 0.4 (5.4% kept).",
  "minScore": 0.4, "requestedMinScore": 0.4, "gateAdapted": false,
  "hint": "This is a gate problem, not a \"nothing matched\" problem. The cosine floor is
           an absolute value and cosine ranges differ per embedding model, so a model
           change or runtime change can move the whole distribution below a fixed
           cutoff. Check OLLAMA_EMBEDDING_MODEL / the active embedding provider…"
}]
```

A thin result set with a non-empty `degraded[]` is **a gate problem, not a 'nothing
matched' problem** — read the `hint`, check `/api/monitoring/ready` →
`embeddingHealth`, and report both facts. Never summarize a degraded search as a
plain "no results".

### Which fields an agent can write

`glassy_note_update` accepts the full organisational field set REST PATCH writes — `title`,
`content`, `tags`, `color`, `images`, `items`, `pinned`, `timestamp`, `show_border`,
`border_style`, `transparency`, `content_format`, `is_public`, `is_hidden`,
`reminder_at`, `background_image`, `needs_review`, `archived`. Three REST columns are
deliberately **not** reachable over MCP, and each now surfaces as `IGNORED_FIELD` with a
hint rather than a silent drop: `type` and `position` (PUT-only) and `is_announcement`
(admin-gated — an owner-scoped agent lane carries no admin identity). `glassy_update_document`
accepts `cover_image` and `transparency` in addition to its earlier fields. A new guard
(`mcpFieldParityGuard`) fails CI if this list and the service column list ever drift apart
again.


## Read what the instance can do before you write

`GET /api/capabilities` describes the deployment: note types, limits, the
renderer allowlists **per surface**, what each renderer silently drops, accepted
upload types, the embedding chunk size and dimensions, the review-loop limits,
the live MCP tool list, the valid `contentFormats`/`transparency`/`border_style`
enums, and — since 2.43.0 — a `navigation` block (`routes` → section key,
`sections` → header title) that publishes the app's own section names so you can
reason about where your work belongs without reverse-engineering the bundle.
Read it instead of probing — every fact you cannot read is a fact you discover
by getting a 201 that does nothing.

## Canvas pages — publishing a live surface

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

**Opening a link from a canvas (service-launcher tiles).** The canvas sandbox has no
`allow-popups`, so `target="_blank"`/`window.open()` inside the canvas is blocked and a
plain `<a href>` self-navigates (loads the target inside the board). To open a URL in a
new tab, post a message to the host and let it open the tab through the same origin
allowlist:

```html
<a onclick="parent.postMessage({type:'glassy-canvas-link-out', url:'https://dash.local'},'*')">Launch</a>
```

The host verifies the message came from THIS canvas and that the URL's hostname is on
`CANVAS_EMBED_ORIGINS`, then opens it with `noopener,noreferrer`. Non-allowlisted and
non-http(s) URLs are refused.

**Showing the appliance's own images in a canvas.** `/uploads/*` carries
`Cross-Origin-Resource-Policy: same-origin`, which an opaque-origin canvas can never
satisfy — so a first-party image fails to decode inside a canvas. Use the
`/widget/image/<path>` lane for the appliance's own stored images (read-only, image
files only, `CORP: cross-origin` so the canvas can decode them) instead of base64-embedding
a copy.

So do not put credentials, internal hostnames, raw connection strings or unredacted
diagnostics in a canvas you intend to publish, and check whether the instance you are
on is public before assuming the window is private.

```bash
curl -s http://localhost:3000/api/capabilities | jq '.capabilities.renderers | keys'
# [ "ai-assistant-preview", "canvas", "help-article", "keep", "note", "window", "writing" ]
curl -s http://localhost:3000/api/capabilities | jq '.capabilities.renderers.keep'
curl -s http://localhost:3000/api/capabilities | jq '.capabilities.renderers.canvas.allowedOrigins'
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
warning, the content was live and the warning was wrong.

**What a canvas can and cannot do (2.40.7, all of it measured in a browser).** "Not stripped" is
not the same as "will render" — a canvas renders inside `srcDoc` under
`sandbox="allow-scripts allow-forms"`, deliberately *without* `allow-same-origin`, so its document
has an **opaque origin** and inherits the app's CSP. That combination once blocked canvas scripts and frames; both
are fixed:

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
  `data:` URIs all render.
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

## Asking the owner a question

**Self-host only.** All four review tools are gated: on cloud they are absent from
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

### Saying what each choice means

Two optional fields exist so the owner is not guessing:

- **`context`** — *why* you are asking: the situation, what you already tried, what is at
  stake. It renders under the question in its own space, so the reasoning no longer has to be
  folded into the same 2000 characters as the question.
- **`choice_notes`** — a map of choice label to the one-line consequence of picking it:

  ```json
  { "publish": "goes live on the public window immediately",
    "hold": "I keep editing; nothing is shown to anyone" }
  ```

  Each note renders **inside its own button**, so it cannot be read against the wrong choice.
  The map may be partial — label the choices where the outcome actually differs and leave the
  obvious ones alone. A consequence is capped at 200 characters on purpose: past that it has
  stopped being a consequence and become a second question.

Keys must be offered choices. A note for a label you did not put in `choices` is **refused**
(`INVALID_CHOICE_NOTES`, listing what you sent against what is offered) rather than dropped —
so a typo reaches you instead of vanishing between your tool call and the owner's screen. Both
fields are additive: omit them and the card renders exactly as before, and `glassy_get_review`
now returns `context` and `choice_notes` alongside what you sent.

Prefer a consequence line over a longer question. "Ship the draft?" with `hold`/`publish` asks
the owner to guess what each answer does; the same request with `choice_notes` filled in is a
decision they can actually make.

### Deadline and outcome — the closed loop

Two additions let a review carry a time dimension and close the loop in *history*:

- **`deadline`** — an ISO 8601 datetime by which the decision is needed (e.g.
  `"2026-10-07T23:59:00Z"`). Optional; absent means "whenever". The owner's card shows it
  and flags it overdue once passed. "Should I ship tonight or wait?" is not answerable as
  posed without one.
- **`glassy_report_review_outcome`** — after the owner answers, report what you then DID
  with `{ id, outcome }`, so the review reads as a closed control loop ("I said 'publish',
  the agent published note X") rather than a one-way feedback queue. Refused
  (`NOT_ANSWERED`) until the owner has answered; a second call overwrites the previous
  outcome (you changed what you did). This is self-reported on purpose — the independent
  record of your tool calls already lives in `mcp_tool_activity` — but the outcome is the
  one place the *decision* and the *action it caused* are shown together.

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
but it does record who filed it, so the owner can see that an agent did.

**The bin is excluded from every read lane (2.40.7).** Once you have soft-deleted a note it is not
returned by `glassy_list_notes`, `glassy_read_note`, `glassy_search`, `glassy_recall` or
`glassy_get_recent`, nor by REST `/api/notes`. `glassy_get_recent` was the last lane that leaked
binned notes — it filtered `archived` but not `deleted_at`, which are two different flags — so a
daily brief could resurrect notes you had already cleaned up. Note that `archived` and
deleted are **not** the same state: an archived note is live and readable, a deleted one is in the
bin. Bookmarks have only one flag, `is_archived`, which *is* their trash. (`glassy_search` holds
the same guarantee against the corpus index: a deletion may leave an embedding row behind, so the
READ path now re-checks every candidate's backing row and drops any whose note/document/bookmark is
deleted or orphaned — the old "deleting also removes its embeddings, so nothing is left to match"
explanation was optimistic, and field measurement proved leftovers do accumulate.)

**Archived vs. search — the contract, stated once.** `glassy_search` excludes **archived**
sources by default, consistent with `glassy_list_notes` / `glassy_get_recent` /
`glassy_recall`, and takes `include_archived: true` as an explicit opt-in when you
deliberately want filed-away context — the same opt-in the list tools already expose.
Archived items keep their content, id and embeddings (readable via `glassy_read_note`),
so the opt-in is a strong, deliberate door into them, not an accident. Deleted items are
always excluded, on both the text leg and the semantic leg, regardless of the flag.

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
notes that did not carry it.


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

### The unfinished-work flag (`needs_review`)

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

## Known quirks

- Obsidian periodic notes: a **disabled** period (monthly/quarterly/
  yearly switched off in the plugin) now answers `200 {exists:false, periodEnabled:false}`
  instead of a hard `400` — a config state, not a failure. A `400 Invalid token` still
  means the bridge token doesn't match the plugin (see Settings → Obsidian); refresh the
  token from the panel.
- `check-url`/fetch validation rejects `localhost` targets in a
  few legacy call sites on self-host; use `127.0.0.1` or the tailnet host
  where possible.
- Cloud sync is intentionally OFF until a credential exists: the peer-minted
  sync token pasted in Settings → Cloud Sync (stored **encrypted** on the
  `sync_peers` row, resolved per cycle — no restart) or the bootstrap/legacy
  `GLASSY_SYNC_TOKEN` env var. `/api/sync-token/settings` reports `hasToken`
  and `GET /api/sync-token/health` reports `credentialSource: settings | env |
  null` (never a value); the S2S budget's unit is a CYCLE — the peer's
  `syncLane` manifest fields (`cycleHeader`, `freeCyclesPerHour`,
  `maxRequestsPerCycle`, `SYNC_CYCLE_TOO_LARGE`) describe it, and a 429 always
  carries `Retry-After` plus `retry_after_ms`.

## Connecting an agent as a dispatch target

Dispatch is the opposite direction from MCP: Glassy starts a session on you,
sends a turn, and consumes normalized events. The catalog is
`GET /api/agents/harnesses`. A harness has a
**role** (knowledge, dispatch, or both), a **transport**, a **placement**, and an
**approval boundary**.

| Transport | What the owner selects | What you must expose |
|---|---|---|
| `agents-api` | Claude Managed Agents, OpenAgentCore/OpenAI Agents API | `POST /v1/sessions` + `POST /v1/sessions/:id/events` + SSE (Anthropic), or `/v1/agents/sessions` (OpenAI shape) |
| `acp` | OpenCode ACP, MiniMax `mcode acp` | JSON-RPC stdio: `initialize`, `session/new`, `session/prompt`, permission requests |
| `app-server` | Codex App Server | JSON-RPC stdio: `initialize`, `thread/start`, `turn/start`, notifications, approvals |
| `http` | OpenCode `serve`, Hermes, OpenClaw, Gemini API | The provider's HTTP session/message endpoint |
| `cli` | Claude Code, `codex exec`, `mcode exec`, `gemini -p` | A headless executable on the server's `PATH`; no shell |

The session API (all owner-scoped, under `/api/agents`):

```bash
# 1. create a session on the connection's transport
POST /api/agents/:connectionId/sessions   {"title":"…"}
# 2. send a turn
POST /api/agents/sessions/:sessionId/turns {"input":"…","options":{…}}
# 3. read it back
GET  /api/agents/sessions/:sessionId            # session + events + approvals
GET  /api/agents/sessions/:sessionId/events     # JSON; add ?stream=1 for SSE
POST /api/agents/sessions/:sessionId/approvals/:approvalId {"decision":"approve"|"deny"}
POST /api/agents/sessions/:sessionId/cancel
```

A turn returns `200` when it completes. If an `acp` or `app-server` transport
asks for permission, it returns **`202` with `pendingApproval: true`**: the
`approval.requested` event is already persisted, the prompt continues in the
background, and the owner decides in the panel. A transport that cannot do
interactive approvals reports `approvals: false`; do not wait for a card that
will never arrive.

For Claude Managed Agents (`agents-api`), *which* tools pause for approval is set in
the **agent definition at Anthropic**, not in Glassy: give the tool a permission
policy of `always_ask` (agent update is `POST /v1/agents/{agent_id}`). Glassy stores
no per-tool policy; it relays the provider's `requires_action` as the approval card.

Normalized event types: `session.created`, `turn.started`, `message.delta`,
`message.completed`, `tool.call`, `tool.result`, `approval.requested`,
`approval.resolved`, `turn.completed`, `session.idle`, `error`.

Placement is part of the contract: `local` transports (`acp`, `app-server`,
`cli`) are refused on every hosted instance (Clear included); `self_hosted_sandbox`
and `cloud` go through `agents-api`. The executable and argv of a local transport
come from Glassy's own harness catalog, never from request config, and the child
receives an allowlisted environment rather than the server's. The
`GET /api/agents/harnesses` response is the authoritative catalog, and
`GET /api/capabilities` carries the `agentGateway` block.

### Legacy HTTP gateways (Hermes / OpenClaw)

Settings → Agent dispatch → add a **Hermes** or **OpenClaw** connection. Two
fields trip everyone up:

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
The legacy one-shot is `POST /api/agents/:id/task` with body `{"task": "…"}` —
the key is `task`, not `prompt`. Prefer the session API above; the one-shot now
creates a real session for stateful transports. `GET /api/agents/discover` is a
convenience probe, not the dispatch path: a configured connection can dispatch
while discovery reports "not reachable".

Facts that make the recipe work, in case the fields are already filled oddly:

- **`host.docker.internal` only resolves because the compose maps it**
  (`extra_hosts: ['host.docker.internal:host-gateway']`). The bundled appliance
  compose has it; **the Tailscale overlay does not** — on `docker-compose.tailscale.yml`
  use the host's tailnet name or IP instead.
- **Ports by harness:** Hermes `8642` (default profile; profile installs often
  `8643`), OpenClaw `18789`, OpenCode `4096` with `opencode serve`. Codex
  App Server and `mcode acp` speak stdio and need no port. Antigravity is the
  legacy Gemini API adapter — a cloud model API, not a full harness.
- **`GET /api/agents/activity`** is where the dispatch log lives (action,
  `task_text`, `response_text`, timestamp); the Agents workspace renders the same
  history as a session timeline. A dispatch that "did nothing" is usually an
  `error` row there with the upstream message.
- **The response's `sessionId` is a session KEY, not a receipt**. Send it
  back as `{"task":"…","options":{"sessionId":"<that value>"}}` to continue the
  same conversation. It used to carry the provider's per-call completion id
  (`chatcmpl-…`) instead, so echoing it back handed the gateway a key it had
  never issued: every turn started a fresh session and re-seeded the gateway's
  full system prompt, which reads from outside as "dispatch is stateless and
  re-pays its whole context each turn". The per-call id now lives in
  `metadata.completionId`, and antigravity/Gemini returns `sessionId: null`
  because that transport has no sessions to resume. Whether your gateway really
  resumes context from a key is a property of the gateway, not of Glassy — but
  measure it with a key Glassy gave you, or you are measuring the wrong thing.
- **`resumeId` is a SEPARATE resume handle when the gateway has one.** On
  Hermes the gateway exposes two headers: `X-Hermes-Session-Key` (scopes long-term
  memory — this is what `sessionId` carries) and `X-Hermes-Session-Id` (actually resumes
  the conversation; the gateway returns it in the response header). The adapter reads it
  out and returns it as `resumeId`, and you pass it back as
  `{"task":"…","options":{"sessionId":"…","resumeId":"<that value>"}}`. Passing back only
  the key resumes nothing AND lets memory accumulate under that key (an earlier field
  measurement saw 5.3× cost at turn 2, but it did NOT reproduce on v2.42.0 — treat it as
  unverified); forwarding the id is flat at 1.0×. OpenClaw and
  Antigravity return `resumeId: null` — for OpenClaw the `sessionId` IS the resume handle
  (the `user` field), and Antigravity has no sessions.
- **How to actually verify resume:** "pass the handles back and see whether the agent
  continues" does NOT discriminate — recall is also served by the gateway's long-term memory,
  so a dispatch with an EMPTY `options` object (or `{sessionId}` alone) still recalls. To prove
  the resume lane works, plant a fresh random code that only the session could carry (not in any
  durable memory), forward the handles, and check the agent reproduces that exact code on the next
  turn. A green from "it remembered something" proves memory, not resume.
- **`options` is validated, and what it refuses it tells you.** `timeout`
  (positive ms, capped), `model`, `sessionId` and `resumeId` are the recognized keys;
  anything else — or a `timeout` of `"30s"`, which used to coerce to an
  immediate abort — comes back as a `warnings[]` entry with
  `code: "IGNORED_OPTION"` naming the key and the reason. The dispatch still
  runs; nothing is dropped silently.
- **SSRF posture differs by instance, deliberately:** the hosted tier accepts only
  `localhost`, `127.0.0.1`, `::1`, `host.docker.internal`; a **self-hosted**
  instance accepts any host,
  which is what allows a LAN or Tailscale address. Don't "fix" a self-host baseUrl
  to loopback to satisfy a validator — that is the bug, not the fix.
- **The catalog is data, not a hardcoded vendor list.** Read
  `GET /api/agents/harnesses` to see the
  harnesses, their roles, transports and placements. A GUI-only editor may have
  knowledge access and no dispatch entry — that is the honest state, not a
  missing adapter.

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

**Sync is a state channel, not a restore path.** Reinstalling, or re-syncing a
fresh install, does **not** pull an account's cloud content back down — sync
propagates *new* changes in both directions, it does not rehydrate history.
To recover content on a device, use the owner's export/import (the sync engine's
`sync/reset` re-snapshot + `sync-data/import` is the cloud-side answer, and only
for a *confirmed* loss — see [Cloud Sync](../docs/cloud-sync.md)). If a pull row was
force-acked after three failed applies, it used to vanish silently while health
still read green; that loss is now a cumulative **`pullDeadLetter`** count in the
sync health, so a nonzero value is the thing to look at before concluding
"content disappeared with no record".

## Ops facts an agent should know

- **Health:** `GET /api/health` → `{"status":"ok", "version":"…"}`;
  `GET /api/monitoring/ready` → `{"status":"ready"}`.
- **Instance:** `GET /__instance-config.js`, `GET /api/instance` →
  `{accessMode: private, instanceId: self_hosted, deploymentLocality: local}`.
- **Auth for REST probes:** the UI uses a JWT (`Authorization: Bearer`);
  a named agent key works on `/mcp` and, on a self-host, on the REST API too
  (see [above](#the-same-named-key-also-reads-the-rest-api)).
- **Local LLM:** server-side Ollama at `http://host.docker.internal:11434`
  when the person runs Ollama — used by AI features; WebGPU local models download through
  the browser.
- **Data + backups:** SQLite at `/app/data/notes.db` inside the container. The
  appliance runs its OWN backup schedule — a daily dump at **02:00** (files named
  `notes-<date>T02-00-00.db`) plus on-demand dumps (fully timestamped names), all in
  `/app/data/backups/`, ~7 days retained. Restore is
  `docker compose exec glassy node server/utils/backup.js --restore <backup-file>`
  (see [Backups](../docs/backups.md)). `/app/data/backups` lives in the **same** Docker volume as the live
  database, so a volume-level failure takes both together; the operator's off-volume
  copy is their own unit/job, and a dead one looks identical to a green one to a
  byte-level drift check — verify the artifact landed, not just that the schedule
  ran. The Import/Export settings panel is the operator's separate *manual* snapshot
  lane, not this schedule.
- **Port:** 3000 unless the person set `APP_PORT`. Inside the container the app listens on 8080; you never call that from outside.
- **Updates:** pinned `GLASSY_TAG` (the release named at the top of this brief); do not float
  `latest` on self-host (it is the hosted build and omits self-host
  features). **Three version numbers have no image and must
  never be pinned:** `v2.36.0-beta.41` (its tag push landed inside a transient
  Actions outage, and beta.42 contains all of beta.41's work plus the TOTP
  fix), `v2.39.0` (prepared as a release and deliberately not launched — its
  canvas and bulk-ingest work shipped in `v2.40.0`) and `v2.40.1` (never tagged;
  its work shipped in `v2.40.2`). Pin a version the registry actually has; `.env.example` always names one.
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
- **Two ways to put something in front of a human, and they are not interchangeable.**
  `#/w/<slug>/<noteId>` is the Public Window: it renders every note type including
  `canvas` (2.40.7), and it is the surface for when *other people* should see the work.
  On a self-hosted appliance it is forced members-only at boot, so "public" means the
  owner and any members — not the internet. `#/present/<kind>/<id>` is chrome-free and
  owner-only: one artifact, no sidebar, no Save button, `Esc` to leave. Use it for review
  handoff. Read `capabilities.presentation.kinds` for the valid kinds rather than
  hardcoding them.

## If the person asks about the Zero Reliance Pair

The Pair is two Glassys the person runs themselves, a home one and one on their own server,
syncing with each other with no Glassy server in between.

- It is a one-time purchase, made in the store on their Glassy cloud account. A pair that is set
  up keeps running whatever happens to a membership.
- The setup steps are in [PAIRING.md](../PAIRING.md), and in the app under Settings → Zero Reliance Pair.
- It does not change how the account is confirmed at start. One setting names the Glassy to sync
  with; a different one names where the account lives.
- For the price, send them to the store or https://glassy.fyi/pricing. Do not quote one.

## Reporting a problem

Report problems at https://github.com/0Reliance/glassy-selfhost/issues using the "Agent report"
form. One finding per issue. A useful report has:

1. the exact call (the `/api/...` path or tool name, and what you sent);
2. the reply, word for word;
3. what you expected, and which file and section in this repo led you to expect it;
4. the output of `GET /api/health`, `GET /api/instance` and `GET /api/capabilities`;
5. steps that someone else can repeat on a fresh install.

Before you file, check the behavior against `/api/capabilities` and this file. Something that is
hard to find is not missing, and a limit that works as designed is a question, not a bug. Say
which you think it is. Never include a key, password or token.
