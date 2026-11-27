---
name: glassy-agent
description: Work well inside a person's Glassy workspace over MCP - which tool to use, where to put notes and documents, how to remember things, how to ask the person a question, working with the people on a shared Glassy, and what never to do. Use whenever you read from or write to Glassy (tools named glassy_*).
---

# Work in Glassy

Glassy is a second brain a person shares with their agents. They see who wrote each thing,
can find everything, and decide what matters. Add to their thinking without crowding it.

Full guide: `agents/USE.md`. Exact tool shapes: `agents/REFERENCE.md` (glassy-selfhost repository).

## Before your first write

Read `glassy://status`. It must show your own name with `"verified": true`. If not, you hold
the shared key: ask the person for a named key. Never write through the person's sign-in.

## Each session

1. `GET /api/capabilities` once: what this Glassy offers.
2. `glassy_recall` with `scope: "mine"` and a `query` (required) about the task: what you remembered.
3. `glassy_get_recent`: what changed.

## Where things go (`place`)

- `shared` (default): work for the person.
- `archive`: finished work worth keeping; still searchable. Set it with an update, not at creation.
- `own`: your scratch and memory; kept out of their lists, never hidden from them.

Documents without a folder land in "Agent work". Archive working papers when done.
`glassy_remember` is for what matters next time, not a transcript.

## Which tool

- Find what the person knows: `glassy_search`, then read the hit. Your own memories: `glassy_recall`.
- Short answer, checklist or capture: `glassy_note_create`. Report or anything with sections:
  `glassy_create_document`. End-of-session record: `glassy_create_digest`.
- A board (dashboard, live page): `glassy_note_create` with `type: "canvas"` and one HTML page.
  Pictures: `glassy_upload_image` gives `url` (for a note) and `canvasUrl` (for a board).
- Tidy your own finished work: update with `archived: true`. Delete only with a yes.
- The full table: `agents/REFERENCE.md`, "Choosing a tool".

## Writing

Lead with the answer. Title it so a person can scan it. Reuse their tags. Read `warnings` in
every write reply. Set `needs_review: true` (with an update) if you stop part-way.

## Finding

A search hit is a lead: read the item before relying on it. If the reply has `degraded`, say
search by meaning was not available; never report that as "nothing found". Search includes the
archive (`include_archived: false` leaves it out). `glassy_vault_*` and `glassy_obsidian_*` reach
the person's Obsidian vault, not Glassy's own notes.

## Asking

When a choice is the person's: `glassy_request_review` with a question, choices, `context`,
and `choice_notes` (a map: choice → what it leads to). Keep working; check `glassy_get_review`;
after acting, `glassy_report_review_outcome`. Ask before publishing, deleting or overwriting
their work, spending money, or sending anything outside Glassy.

`glassy_notify` is for "this is ready" with no answer needed. The question tools and notify work
on Glassy's cloud too, within the plan's limits (`agentPolicy` in `/api/capabilities`); past a
limit, write a note and say where it is. On the cloud, making something public asks the person
first: the question appears under Decisions and their answer publishes it.

## If the person uses both a Glassy they run and our cloud (Cloud Sync)

You hold one key on each; use the **same agent name** on both so your memories match. Notes,
documents, your memories, and questions with their answers travel. Your key, notices, public
status and limits stay on each Glassy: a note public at home is private on the cloud, and a
notice reaches only the Glassy you sent it on. `glassy://status` → `instance` says which one you
are on. Details: [REFERENCE.md](../../REFERENCE.md#when-the-person-uses-both-cloud-sync).

## Several people on one Glassy (self-host, seat pack)

- With **reach** (an admin sets it in People → Agents): `glassy_list_members` for the names, then
  `glassy_share`, `glassy_assign`, `glassy_notify` / `glassy_request_review` with `audience`,
  `glassy_checkin`. Pass `onBehalfOf` with the member who asked. Never read a member's private notes.
- With **admin reach** (an admin's own key): the eight `glassy_admin_*` tools invite and manage
  people. Steps: `agents/REFERENCE.md`, "Managing people, end to end".
- Use the names the admin chose; Glassy defines no kinds of people or groups.

## Never without a yes

- deleting or overwriting what the person wrote (archive instead; only they can restore a delete)
- making anything public
- `glassy_vault_append` (writes into their files, no undo)
- calendar changes they did not ask for
- bulk changes
- making someone an admin, downloading a closed account's things, deleting an account for good
  (these tools only file a request; an admin decides in People)

## End of session

Say what you made and where (links: `#/present/<kind>/<id>`), what you asked that is still
open, and what you did not do.
