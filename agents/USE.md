# Work in Glassy

How to be good company in someone's second brain. Short on purpose. The exact shape of every
tool and reply is in [REFERENCE.md](REFERENCE.md).

**Before your first write:** you have your own named key, and `glassy://status` shows
`"verified": true` for your name. If not, do [CONFIGURE.md](CONFIGURE.md) steps 2 to 4.

## The idea

Glassy is one workspace for a person and their agents. The person sees who wrote each thing,
can find everything, and decides what matters. Your job is to add to their thinking without
crowding it: put work where it belongs, sign it, ask when a choice is theirs, and tidy up.

## Start of a session

1. `GET /api/capabilities`, once. It says what this Glassy offers, its limits and its tool list.
2. `glassy_recall` with `scope: "mine"` and a `query` about the task in hand (it needs one;
   the person's name or the project works). Your own memories: the person's preferences, where
   you left off.
3. `glassy_get_recent`, to see what changed since you were last here.

Do not start by reading everything. Search for what the task needs.

## Three places

Every note and document lives in one of three places. You choose with `place`: `shared` or
`own` when you create, and `shared`, `archive` or `own` when you update.

| Place | What goes there | Who sees it |
|---|---|---|
| `shared` (the default) | Work for the person: answers, reports, drafts, things they asked for | The person, in their everyday views, and all agents |
| `archive` | Finished or set-aside work worth keeping | Still found by search, a little below current work. Out of the everyday lists. |
| `own` | Your working material: memories, scratch, run state | You and other agents. Kept out of the person's lists and search. Never secret: they see your space on the Agents page and in Settings → Agent access (MCP), and can move anything out. |

Rules of thumb:

- If the person would want to read it, `shared`. If only you need it, `own`.
- A document you create with no folder goes into "Agent work", so their own documents stay in front.
- When a working paper has done its job (a plan, a checklist, a status report), archive it.
- `glassy_remember` (`text` is required; `title` is optional) writes to your own space for you. Use it for things worth knowing next
  time: preferences, decisions, where a long task stands. Not for a transcript of the session.

## Writing

- **Notes for short things, documents for long things.** A note is a card. A document is for
  anything with sections.
- **Give it a title a person can scan.** "Car insurance: three quotes compared", not "Research output".
- **Lead with the answer.** Then how you got there, then what you did not check.
- **Tags:** lower-case, at most 20 per item. Reuse the person's tags (`glassy_get_tags`) before
  inventing new ones. A write with an invalid tag is refused whole, with `422 INVALID_TAGS`
  naming the tag.
- **Read the reply to every write.** `warnings` tells you if a field was ignored or changed.
  A `200` alone does not mean it was stored as you sent it.
- **Stopping part-way?** Set `needs_review: true` with `glassy_note_update` so the person can see it is unfinished.
- **Edit your own work freely. Edit theirs only when asked.** Your edit is recorded under your name.

## Finding

- `glassy_search` searches notes, documents, bookmarks, voice and the linked Obsidian vault by meaning and by words.
- A result is a lead, not a fact. Before you rely on one, read the item (`glassy_read_note`,
  `glassy_read_document`).
- If the reply carries `degraded`, say so. "Search by meaning isn't available right now, so
  this is by words only" is an honest answer. "Nothing found" is not.
- A memory or note written seconds ago may not be searchable by meaning yet. Read it by id.
- Search includes the archive, a little below current work. Pass `include_archived: false` to
  leave it out. `glassy_list_notes` leaves archived items out unless you pass
  `include_archived: true`; `glassy_get_recent` always leaves them out.
- "Vault" tools (`glassy_vault_read`, `glassy_vault_append`, `glassy_obsidian_*`) reach the
  person's **Obsidian** vault, not Glassy's own notes. With no Obsidian connected they fail,
  unless the person set one of their agents as the vault provider, which then answers
  `glassy_vault_read` and `glassy_vault_append`. For Glassy's own content use search, the note
  tools and the document tools.

Not sure which tool fits? The table in [REFERENCE.md](REFERENCE.md#choosing-a-tool) maps what you
want to do to the tool that does it.

## Asking

When a choice is the person's, ask. Do not guess, and do not stop everything to wait.

1. `glassy_request_review` with a `question`, two to ten `choices`, a `context` line saying why
   you are asking, and `choice_notes`, a map from each choice to what it leads to
   (`{"Book it": "€670 on your card today"}`). Link the item it is
   about with `linked_type` and `linked_id`.
2. Carry on with other work. Check `glassy_get_review` later.
3. When they answer, act on it, then `glassy_report_review_outcome` with what you did.
4. If the question stops mattering, `glassy_withdraw_review`.

The person sees your question under Decisions, on Today, with the linked item beside it. The
Agents page shows them what you wrote, how many tools you called and what you asked.

Ask about: publishing anything, deleting or overwriting their work, anything that costs money,
anything sent outside Glassy, a choice between real alternatives. Do not ask about: where to
file your own notes, wording, anything you can undo yourself.

`glassy_notify` sends a short notice to their header. Use it for "this is ready" or "this
needs you today". It is limited to ten a minute, and one a day is a better habit.

These four question tools and `glassy_notify` work on a self-host and on Glassy's cloud. On the
cloud, how many questions can wait at once and how many a minute or an hour depends on the plan;
a refusal names the number. On the cloud, publishing also asks first: `is_public` saves the item
private and puts "Publish this?" in the person's Decisions, and it goes public when they choose
Publish, unless the person has let your key publish without asking (Agent keys, on a paid plan).

If the person pairs this Glassy with our cloud (Cloud Sync), notes, your memories and questions
with their answers travel between the two; your key, notices, public status and limits do not.
Use the same agent name on both. What that changes for you:
[REFERENCE.md](REFERENCE.md#when-the-person-uses-both-cloud-sync).

## Showing

When you have made something the person should look at, give them a link, not a description:

- `http://localhost:3000/#/present/<kind>/<id>` shows one note, document or canvas with nothing
  around it. Only the signed-in person can open it.
- `http://localhost:3000/#/notes/<id>` opens the note in the workspace.

Use the address the person actually uses for Glassy if it is not `localhost`. Making a note
public (`is_public`) changes who can see it. Ask first.

## Boards and pictures

- A board is a note with `type: "canvas"` and one self-contained HTML page as its content.
  Change it by sending the whole page again with `glassy_note_update`; an open board redraws.
- For a picture, `glassy_upload_image` (self-host) gives you `url` for a note's `images` and
  `canvasUrl` for an `<img src>` on a board. On cloud, ask the person to add the picture to a note in the app.

## Several people on one Glassy

On a self-host with a seat pack, an admin can add people (the **People** screen). Glassy
defines no kinds of people or groups; use the names the admin chose.

- With **reach** (an admin turns it on for your key in People → Agents) you can list the people
  (`glassy_list_members`), share, assign, ask a group and send to people. Name the member who
  asked in `onBehalfOf`. You only see what was shared with everyone, never a member's private notes.
- With **admin reach** (only for an admin's key) you can also invite people, change their options,
  run groups and starting setups, and close the account of someone who left, with the eight
  `glassy_admin_*` tools. The steps are in
  [REFERENCE.md](REFERENCE.md#managing-people-end-to-end).
- You can only **ask** to make someone an admin, to download a closed account's things, or to
  delete an account for good: the call files a request and an admin decides in People. You never
  act as a person, set a PIN or give an agent reach.

## Tidying

- **Archive, don't delete.** You can un-archive. Only the person can restore a deleted note.
- **Clean up your tests.** Anything you wrote to try something goes in `own`, and is archived
  or removed before you finish.
- **One agent, one key.** If you start other agents, each needs its own named key from the person.

## Stop and ask

- Before deleting or overwriting anything the person wrote.
- Before making anything public.
- Before appending to their Obsidian vault (`glassy_vault_append` writes straight into their
  files, with no undo).
- Before creating, moving or deleting calendar events they did not ask for.
- Before a bulk change (more than a handful of items at once).

## When something fails

| You see | It means | Do |
|---|---|---|
| `401` on `/mcp` | No key, or the key was revoked | Ask the person for a current named key |
| `403 PASSWORD_CHANGE_REQUIRED` | First sign-in is not finished | [CONFIGURE.md](CONFIGURE.md#1-first-sign-in) |
| `scope_denied` on a write | Your key reads only | Tell the person; they can make a key that writes |
| `403 FEATURE_NOT_AVAILABLE` | This Glassy does not offer that tool (cloud) | Read `/api/capabilities`; use the note-and-tell route |
| `406` on `/mcp` | Your `Accept` header lacks `text/event-stream` | Send `Accept: application/json, text/event-stream` |
| `422 INVALID_TAGS` | A tag was refused; nothing was stored | Fix the named tag and send again |
| Anything else | | [TROUBLESHOOT.md](TROUBLESHOOT.md) |

## End of a session

Tell the person, briefly: what you made and where it is (with links), what you asked them and
is still open, and what you did not get to. If it will matter next time, `glassy_remember` it.
