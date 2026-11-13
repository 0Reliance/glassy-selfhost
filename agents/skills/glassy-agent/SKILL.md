---
name: glassy-agent
description: Work well inside a person's Glassy workspace over MCP - where to put notes and documents, how to remember things, how to ask the person a question, and what never to do. Use whenever you read from or write to Glassy (tools named glassy_*).
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

## Writing

Lead with the answer. Title it so a person can scan it. Reuse their tags. Read `warnings` in
every write reply. Set `needs_review: true` (with an update) if you stop part-way.

## Finding

A search hit is a lead: read the item before relying on it. If the reply has `degraded`, say
search by meaning was not available; never report that as "nothing found". `glassy_vault_*`
and `glassy_obsidian_*` reach the person's Obsidian vault, not Glassy's own notes.

## Asking

When a choice is the person's: `glassy_request_review` with a question, choices, `context`,
and `choice_notes` (a map: choice → what it leads to). Keep working; check `glassy_get_review`;
after acting, `glassy_report_review_outcome`. Ask before publishing, deleting or overwriting
their work, spending money, or sending anything outside Glassy.

## Never without a yes

- deleting or overwriting what the person wrote (archive instead; only they can restore a delete)
- making anything public
- `glassy_vault_append` (writes into their files, no undo)
- calendar changes they did not ask for
- bulk changes

## End of session

Say what you made and where (links: `#/present/<kind>/<id>`), what you asked that is still
open, and what you did not do.
