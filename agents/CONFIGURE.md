# Set up a new Glassy

**Goal:** the person can sign in, you are connected under your own name, and AI runs where they chose.
**Done when:** you have written one note with your own key, found it again by search, and given the hand-back in step 7.
**Before you start:** Glassy is running (`./doctor.sh` shows no "problem" line; "attention" lines are fine). If not, do [INSTALL.md](INSTALL.md) first.

Addresses below use `http://localhost:3000`. Use the person's port if they changed it.

## 1. First sign-in

A new Glassy has one account, made from the person's email, with a one-time password. Until
that password is changed, every signed-in call answers:

```
403 {"code":"PASSWORD_CHANGE_REQUIRED", …}
```

That reply means "first sign-in isn't finished". It does not mean the install is broken.
Sign-in itself still succeeds, which is what makes this confusing.

**Recommended: the person does it.** Ask them to:

1. run `docker exec glassy cat /app/data/.initial_admin_password` (email on line one, password on line two),
2. open http://localhost:3000, sign in, and choose their own password when asked.

Then go to step 2.

**If they asked you to do it** (for example, nobody is at the machine), run this from the
Glassy folder, so the password file lands there:

```bash
BASE=http://localhost:3000
EMAIL=$(docker exec glassy sed -n 1p /app/data/.initial_admin_password)
FIRST=$(docker exec glassy sed -n 2p /app/data/.initial_admin_password)

# A strong starting password for the person, saved where only they can read it.
umask 077
NEW="Glassy-$(openssl rand -hex 8)-Aa1"
printf '%s\n' "$NEW" > glassy-first-password.txt

TOKEN=$(curl -s -X POST $BASE/api/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$FIRST\"}" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')

curl -s -X POST $BASE/api/auth/change-password \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"currentPassword\":\"$FIRST\",\"newPassword\":\"$NEW\"}"
```

Expected: `{"message":"Password updated successfully."}`. The sign-in token you hold keeps
working; you do not need to sign in again. The one-time password file inside Glassy is
removed at that moment, so read it before you change anything.

| Reply to the password change | It means |
|---|---|
| `400` | A field is missing, or the new password is too weak (at least 8 characters with an upper-case letter, a lower-case letter and a digit) |
| `401` | You are not signed in; get a token first |
| `403` | The current password you sent is wrong. This is a different 403 from the one above: read the body. |

You now hold the person's password. Tell them where the file is, ask them to change the
password under Settings → Account → Security, and to delete the file. Never put the password
in a reply or a note. `glassy-first-password.txt` is ignored by git.

## 2. Get your own key

Glassy tells people and agents apart by who wrote each thing. For that you need a **named
agent key**: one key, for you, carrying your name.

**Recommended: the person makes it.** Settings → Connections & data → Agent access (MCP) →
Named agent keys (`http://localhost:3000/#/settings?g=data&s=mcp`). They choose your app,
give the key your name, tick "Read-only" if you should never write, choose "Create key", and
hand you the key.

**If you did the first sign-in for them,** make it with the token from step 1:

```bash
curl -s -X POST $BASE/api/mcp-keys \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"agentName":"<your name>"}'
# → {"id":"mk_…","key":"gky_mcp_…","agentName":"<your name>","scopes":["read","write"]}
```

Send `"scopes":["read"]` as well for a key that can only read. The key is shown once.

Choose a name the person will recognize in their workspace: your product name, or the name
they call you. Keep the key in your own client's configuration (step 3). If you have no
configuration that lasts between sessions, save it to a file only the person can read
(`umask 077`), outside this repository, and tell them where it is. Do not store it in a note
or a document, and never show it in a reply.

One key per agent. If two agents share a key, Glassy cannot tell their work apart.

## 3. Connect

The endpoint is `http://localhost:3000/mcp` with the header `Authorization: Bearer <key>`.

- **Claude Code:**
  `claude mcp add --transport http glassy http://localhost:3000/mcp --header "Authorization: Bearer gky_mcp_..."`
- **Cursor** (`mcp.json`):
  `{"mcpServers": {"glassy": {"url": "http://localhost:3000/mcp", "headers": {"Authorization": "Bearer gky_mcp_..."}}}}`
- **Claude Desktop** starts local servers only, so it reaches Glassy through `mcp-remote`
  (needs Node.js). Restart Claude Desktop after editing its config:

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

  Add `"--allow-http"` to `args` when the address is not `localhost` or `127.0.0.1`.
- **Any other client, or plain HTTP:** MCP over streamable HTTP. Send both content types in
  `Accept`, or Glassy answers `406`:

  ```bash
  curl -s -X POST http://localhost:3000/mcp \
    -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
  ```

  Replies arrive as `event: message` followed by a `data: {…}` line holding the JSON.

Settings → Connections & data → Agent access (MCP) shows the same setup for each app with the
address filled in. The person can see everything you do on the Agents page.

## 4. Prove it

Three checks. Do all three.

1. **You are who you think you are.** Read the resource `glassy://status`. Expected:
   `"agent": {"name": "<your name>", "verified": true, "identityMode": "named-key"}`.
   If `verified` is `false`, you were given the shared instance key. Ask for a named one before
   you write anything.
2. **You can write.** Call `glassy_note_create` with a `title` and a line of `content`.
   Expected: a reply with an `id` and `"place": "shared"`.
3. **It can be found, and it is credited to you.** Call `glassy_search` with a `query` from the
   note. Expected: your note, with `"createdBy": "<your name>"`.

Through an MCP client these are a resource read and two tool calls. Over plain HTTP, with the
headers from step 3 (no `initialize` call is needed first):

```bash
-d '{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"glassy://status"}}'
-d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"glassy_note_create","arguments":{"title":"Hello","content":"A first note."}}}'
-d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"glassy_search","arguments":{"query":"first note"}}}'
```

If search returns the note with a `degraded` entry for the `semantic` leg, search is working by
words and no model for search by meaning is reachable yet. That is expected until step 5, and
is not a fault. `./doctor.sh` says the same thing in an `ok` line.

Then archive the test note (`glassy_note_update` with `archived: true`) unless the person asked
for it.

## 5. Where AI runs

Glassy on a person's machine uses AI they bring. There are three places, and they can mix them:

| Where | Cost to them | Set up |
|---|---|---|
| **Their device**: models that run in the browser | Free | Settings → Workspace → Local AI models. Works while Glassy is open in a tab. |
| **Their own server**: Ollama | Free | If Ollama runs on this machine, Glassy finds it. For search by meaning, `ollama pull nomic-embed-text`. No Ollama? Start the bundled one: `./install.sh --with-ollama`. |
| **Their own key**: a provider they have an account with | That provider's bill | They add the key in Settings → Workspace → API keys. |

With both a server and a key, Glassy asks their own server first and uses the key when the
server isn't answering. "Answer with" in Settings → Workspace → AI assistant changes that.

Ask which they want. Recommend starting with their own Ollama if this machine has one, and
their device otherwise. Say what each costs. Do not add a provider key yourself unless they
hand you one for that purpose, and never put a key in `.env`: Glassy does not read AI keys
from there.

Settings → Connections & data → Second Brain shows which model reads the library for search,
how much is ready, and what it needs if it paused. Search by words always works.

## 6. Optional, when they ask

| They want | Read |
|---|---|
| Their Obsidian vault in Glassy | [../docs/obsidian.md](../docs/obsidian.md) |
| Glassy on their phone or another computer | [../docs/reach-it-from-other-devices.md](../docs/reach-it-from-other-devices.md) |
| The same notes on a Glassy cloud account, or a second Glassy of their own | [../docs/cloud-sync.md](../docs/cloud-sync.md), [../PAIRING.md](../PAIRING.md) |
| Glassy to hand work to you (dispatch), not only you calling Glassy | [REFERENCE.md](REFERENCE.md#connecting-an-agent-as-a-dispatch-target) |

Each of these changes what leaves the machine or who can reach it. Do them only on request.

## Stop and ask

- Before changing the person's password a second time, or turning on two-step sign-in.
- Before making a key for another agent, or revoking any key.
- Before adding an AI provider key, or pointing Glassy at an AI service that bills them.
- Before anything in step 6.

## 7. Tell the person

> You're set up. I'm connected to your Glassy as "<your name>", with a key that can
> [read and write / only read]. You can see or revoke it in Settings → Connections & data →
> Agent access (MCP).
>
> AI: [what they chose, and what it costs], or "not set up yet; search works by words until it is."
>
> [Only if you did the first sign-in:] Your starting password is in `glassy-first-password.txt`
> in the Glassy folder. Please sign in, change it under Settings → Account → Security, and
> delete that file.
>
> I checked: my identity shows as verified, I wrote a test note and found it by search, then
> archived it. I did not check: [what you did not].

**Next:** [USE.md](USE.md) is how to work here day to day.
