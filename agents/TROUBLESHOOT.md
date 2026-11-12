# Fix a Glassy that isn't working

**Goal:** find the cause, fix it if it is safe to, and tell the person what happened.
**Done when:** `./doctor.sh` shows no "problem" line and you have told the person about any "attention" line that needs them.

## 1. Look before you touch

```bash
./doctor.sh --json
```

It only reads. Each finding has a `level` (`ok`, `attention`, `problem`), a `message` and a
`fix`. Work on the first `problem`. If there are none, go to the table that matches what the
person described.

Useful reads that change nothing:

```bash
docker compose ps
docker compose logs --tail 60 glassy
curl -s http://localhost:3000/api/health
curl -s http://localhost:3000/api/instance
```

## 2. Stop and ask

Ask before any of these. Say what it will do in one sentence.

- `docker compose down -v`, or removing a volume. It erases every note and setting.
- Restoring a backup over the current data.
- Changing `JWT_SECRET` or `API_KEY_ENCRYPTION_KEY`.
- Resetting a password.
- Changing `GLASSY_TAG` to an older version.

Safe without asking: reading logs, `docker compose restart glassy`, `docker compose up -d`,
`docker compose pull` for the version already in `.env`.

## 3. Starting and reaching Glassy

| What you see | Cause | Fix | Confirm |
|---|---|---|---|
| `set GLASSY_TAG…`, `set JWT_SECRET`, or another `set …` message from `docker compose up` | A required value is missing from `.env` | `./install.sh` fills what is missing and keeps the rest | `./doctor.sh` |
| `The container name "/glassy" is already in use` | Another Glassy exists on this machine, running or stopped | **Ask the person** which one they want. Do not remove it yourself. | `docker ps -a --filter name=glassy` |
| `port is already allocated` | Something else uses the port | Set `APP_PORT`, and set `APP_URL` and `CORS_ORIGINS` to the same port, in `.env`. Or `./install.sh --port <n>`, which does all three. Then `docker compose up -d`. | Open the new address |
| The page loads but sign-in fails or the page can't reach Glassy | `APP_PORT`, `APP_URL` and `CORS_ORIGINS` disagree, or the person uses an address not in `CORS_ORIGINS` | Make the three agree. Add each address they use to `CORS_ORIGINS`, comma-separated. `docker compose up -d`. | `./doctor.sh` |
| A banner says "You are on the cloud", or Agent access, Second Brain and API keys are missing from Settings | `GLASSY_TAG` is `latest` or `main` | Set it to the version in `.env.example`. `docker compose pull && docker compose up -d`. | `curl -s localhost:3000/api/instance` shows `"instanceId":"self_hosted"` |
| Blank or old-looking page after an update | The browser tab is still running the old app | Close and reopen the tab, or hard-refresh | The version in Settings matches `/api/health` |
| `Couldn't download Glassy` | No route to `ghcr.io` | Check the connection or proxy | `docker compose pull` |

## 4. Signing in

| What you see | Cause | Fix |
|---|---|---|
| Every call answers `403 PASSWORD_CHANGE_REQUIRED` | First sign-in is not finished | [CONFIGURE.md](CONFIGURE.md#1-first-sign-in) |
| No first password in the log | The log only shows it on the very first start | `docker exec glassy cat /app/data/.initial_admin_password`. If that file is gone, the password was already changed. |
| "Registration is closed" | Expected. A self-host has one account unless the person has a seat pack. | Sign in with the existing account |
| The person forgot their password | | [../docs/accounts.md](../docs/accounts.md#if-you-forget-your-password). Ask before resetting. |
| A two-step code is refused though it is right | The machine's clock is off | Compare `date -u` with `docker compose exec glassy date -u` and a trusted clock. Fix the machine's time sync, restart Glassy. Do not re-enrol first. |
| `note  Glassy couldn't confirm your account` | The email or pairing token does not match, the wrong cloud address is set, or the cloud could not be reached | Glassy works regardless. Check `GLASSY_MEMBER_EMAIL`, `GLASSY_SELFHOST_TOKEN`, and `GLASSY_VERIFY_CLOUD_URL` (`https://clear.glassy.fyi` for Clear accounts) with the person. After a wrong token, wait 15 minutes before trying a corrected one, then `docker compose restart glassy`. |

## 5. Agents

| What you see | Cause | Fix |
|---|---|---|
| `401 {"error":"Authorization header required"}` on `/mcp` | No key sent | Send `Authorization: Bearer <key>` |
| `401` with a key | The key was revoked or mistyped | Ask the person for a current one |
| `406` on `/mcp` | `Accept` lacks `text/event-stream` | `Accept: application/json, text/event-stream` |
| `503` on `/mcp` | Agent access is off or did not start | `./doctor.sh`; remove `ENABLE_MCP_SERVER=false` from `.env` if present; check the log for the reason |
| Your writes show as "MCP agent", and `glassy_recall` with `scope: "mine"` is empty | You are using the shared instance key | Ask for a named key ([CONFIGURE.md](CONFIGURE.md#2-get-your-own-key)) |
| `409 AGENT_NAME_EXISTS` when making a key | A key with that name exists, or existed and was revoked. A revoked key's name stays taken. | Choose another name, for example with a number after it |
| Claude Desktop does not show Glassy | It ignores `url` entries | Use the `mcp-remote` form in [CONFIGURE.md](CONFIGURE.md#3-connect), then restart Claude Desktop |
| `glassy_vault_read` or `glassy_vault_append` fails | No Obsidian vault is connected | These reach Obsidian only. For Glassy's own content use search and the note tools. |
| A tool "doesn't exist" | It may not be offered on this Glassy | `GET /api/capabilities` lists the tools it serves |

## 6. Search and AI

| What you see | Cause | Fix |
|---|---|---|
| Search results carry `degraded` with `"leg":"semantic"` | No search model is reachable. Search is working by words. | Tell the person. They choose where AI runs: [CONFIGURE.md](CONFIGURE.md#5-where-ai-runs). |
| "No AI provider configured" | Nothing is set up for AI yet | The same choice |
| Ollama is installed but Glassy does not see it | Inside the container `localhost` is the container | Leave `OLLAMA_BASE_URL` at its default (`http://host.docker.internal:11434`). On Linux, make sure Ollama listens on more than loopback. |
| An Ollama model answers 404 | The model name in `OLLAMA_MODEL` is not one they pulled | `ollama list`, then set the exact name |
| Search got worse after changing the search model | Old and new models can't be compared | Settings → Connections & data → Second Brain rebuilds the index. See [../docs/ai.md](../docs/ai.md#search-by-meaning). |

## 7. Data

| What you see | Cause | Fix |
|---|---|---|
| Notes missing after a reinstall | `docker compose down -v` erased the volume, or this is a new folder with a new volume | Ask about backups: [../docs/backups.md](../docs/backups.md). Cloud Sync does not bring old content back by itself. |
| "The app shows errors but the container is healthy" | Possibly a damaged database | Run the check in [../docs/troubleshooting.md](../docs/troubleshooting.md#the-app-shows-errors-but-glassy-says-its-healthy). It should print `ok`. If it prints problems, stop and tell the person; restoring a backup is their call. |
| Sync seems slow | Changes travel within about a minute by design | Wait. Then Settings → Account → Cloud Sync → Sync now. [../docs/cloud-sync.md](../docs/cloud-sync.md) |

## 8. Tell the person

> What was wrong: [one sentence, plain words].
> What I did: [the change, or "nothing yet"].
> What I checked afterwards: [doctor result].
> What needs you: [a decision or an action, or "nothing"].

If you could not find the cause, say so, give the `./doctor.sh` output and the last lines of the
log (with secrets removed), and suggest an issue at
https://github.com/0Reliance/glassy-selfhost/issues.
