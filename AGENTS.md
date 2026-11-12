# For AI agents

You are reading the Glassy Self-Host repository. Glassy is a second brain that a person shares
with their agents: notes, documents, bookmarks, voice, calendars and boards in one workspace,
running on the person's own machine. You can install it for them, set it up, and then work in
it under your own name.

Find your job below and read that one file. Each is a complete set of steps. If the request
covers more than one job ("install it and connect yourself"), do them in the order of the table
and give the person one hand-back at the end, from the last job you did.

| The person asked you to… | Read | It ends when |
|---|---|---|
| Install Glassy on this machine | [agents/INSTALL.md](agents/INSTALL.md) | Glassy is running and you have shown it is healthy |
| Set it up: first sign-in, connect yourself, choose where AI runs | [agents/CONFIGURE.md](agents/CONFIGURE.md) | You have written a note under your own name and found it again |
| Work in Glassy: read, write, remember, ask them things | [agents/USE.md](agents/USE.md) | (ongoing) |
| Fix something that isn't working | [agents/TROUBLESHOOT.md](agents/TROUBLESHOOT.md) | `./doctor.sh` shows no "problem" lines |

The exact shape of every tool, reply and limit is in [agents/REFERENCE.md](agents/REFERENCE.md).
It is long. Open it when you need a detail, not before.

## Six rules that hold in every job

1. **The person decides.** Ask before anything that erases data, opens Glassy to the internet,
   changes a password or key, or spends their money. Each file lists its own stop points.
2. **Never show a secret.** Passwords, the pairing token, keys and the contents of `.env` stay
   out of your replies, your notes and your logs. Say where a secret is, not what it is.
3. **Work under your own name.** Use your own named agent key. Never write through the
   person's sign-in: it files your work as theirs.
4. **Read what this Glassy can do before you assume.** `GET /api/capabilities` describes the
   running install. When it and a document disagree, it is right.
5. **Archive, don't delete.** Archiving can be undone by you. A delete can only be undone by
   the person.
6. **Say what you did and what you didn't.** End each job with the short hand-back the file
   gives you. If you could not check something, say so.

## Facts you will need in every job

- **Address:** `http://localhost:3000` unless the person chose another port (`APP_PORT` in `.env`).
- **Health:** `GET /api/health` needs no sign-in. Its reply includes `"status":"ok"` and a
  `"version"` written without a leading `v` (`.env` and the scripts write it with one).
- **Agent endpoint (MCP):** `http://localhost:3000/mcp`, with `Authorization: Bearer <your key>`.
- **One command that checks everything:** `./doctor.sh` (add `--json` to read it yourself).
- **Problems with these instructions:** report them at
  https://github.com/0Reliance/glassy-selfhost/issues with the "Agent report" form.

Prefer skills? The same steps are packaged in [agents/skills/](agents/skills/).
