# Troubleshooting

Start here:

```bash
./doctor.sh
```

It reads your setup, changes nothing, and tells you what is healthy and what to do about what
isn't. Most problems end there.

## Glassy won't start

| What you see | What to do |
|---|---|
| `set GLASSY_TAG…`, `set JWT_SECRET`, or another `set …` message | A setting is missing from `.env`. Run `./install.sh`; it fills what is missing and keeps the rest. |
| `The container name "/glassy" is already in use` | There is already a Glassy on this machine. `docker ps -a --filter name=glassy` shows it. Use that one, or remove it if you're sure you don't need it (`docker rm -f glassy` removes the container, not your notes). |
| `port is already allocated` | Something else uses port 3000. Run `./install.sh --port 3005` (or another free port). |
| Glassy couldn't be downloaded | Check your internet connection and try again. |

To see what Glassy itself says: `docker compose logs --tail 40 glassy`

## I can't sign in

**Where is my first password?**
`docker exec glassy cat /app/data/.initial_admin_password` shows your email and the one-time
password. If that file is gone, the password was already changed.

**I forgot my password.** See [Your account](accounts.md#if-you-forget-your-password).

**There's no way to register.** That's expected. A self-host has one account, yours.

**The page loads but signing in does nothing.** The address you're using isn't in
`CORS_ORIGINS`, or `APP_PORT`, `APP_URL` and `CORS_ORIGINS` disagree. Fix them in `.env` (see
[Settings](configure.md#address-and-port)) and run `docker compose up -d`.

### A two-step code is refused

If you're sure the code is right, the clock on this machine is probably wrong. Codes depend on
the time.

```bash
date -u
docker compose exec glassy date -u
```

Both should match the real time to within a few seconds. Fix the machine's time sync
(`timedatectl set-ntp true` on most Linux systems), then `docker compose restart glassy`.
Setting up two-step sign-in again won't help while the clock is off.

## "Glassy couldn't confirm your account"

Everything on your machine works. Glassy will ask again the next time it starts. To clear it:

1. Check `GLASSY_MEMBER_EMAIL` and `GLASSY_SELFHOST_TOKEN` in `.env`. The token is shown once
   when you make it; if you've lost it, make a new one in Settings → Account → Self-hosting on
   your cloud account.
2. If your account is on Clear, `GLASSY_VERIFY_CLOUD_URL` must be `https://clear.glassy.fyi`.
3. After several tries with a wrong token, wait 15 minutes before trying the right one.
4. `docker compose restart glassy`

## A banner says "You are on the cloud", or settings are missing

`GLASSY_TAG` in `.env` is `latest` or `main`. Set it to the version named in `.env.example`,
then:

```bash
docker compose pull && docker compose up -d
```

## Glassy looks old after an update

Close the tab and open Glassy again. If it still looks old, clear the site's data for your
Glassy address in your browser's settings.

## AI isn't answering

Glassy uses AI you bring, so check the one you chose ([AI on your Glassy](ai.md)):

- **Your own key:** Settings → Workspace → API keys. Is the key saved, and does the provider
  account have credit?
- **Ollama:** `ollama list` should show a model. If you named one in `OLLAMA_MODEL`, the name
  must match exactly.
- **This device:** Settings → Workspace → Local AI models. Is a model downloaded and turned on?

## Search doesn't find things by meaning

Search by words always works. For meaning, Settings → Connections & data → Second Brain shows
which model reads your library and what it needs. With Ollama, run
`ollama pull nomic-embed-text`.

## An assistant can't connect

See [Agents in your Glassy](agents.md), and give the assistant
[agents/TROUBLESHOOT.md](../agents/TROUBLESHOOT.md).

## Obsidian isn't connecting

See [Obsidian](obsidian.md#if-it-isnt-connecting).

## The app shows errors but Glassy says it's healthy

Check the database:

```bash
docker exec glassy node -e "const s=require('sqlite3');const d=new s.Database('/app/data/notes.db',s.OPEN_READONLY);d.get('PRAGMA integrity_check',(e,r)=>{console.log(e?e.message:Object.values(r)[0]);d.close()})"
```

It should print `ok`. If it prints a list of problems instead, restore your latest
[backup](backups.md#restore). If the command itself can't run, Glassy isn't started: see the top
of this page.

## Still stuck

Open an issue at <https://github.com/0Reliance/glassy-selfhost/issues>. Include the output of
`./doctor.sh` and the last lines of `docker compose logs --tail 40 glassy`. Remove anything
secret first.
