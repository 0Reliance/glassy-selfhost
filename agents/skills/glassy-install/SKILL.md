---
name: glassy-install
description: Install Glassy Self-Host on a person's machine with Docker. Use when someone asks you to install, set up or get Glassy running locally, or hands you the glassy-selfhost repository.
---

# Install Glassy for a person

Full steps, with every error and its fix: `agents/INSTALL.md` in the glassy-selfhost
repository (https://github.com/0Reliance/glassy-selfhost). This is the short form.

## Do this

1. **Check, changing nothing:** `./install.sh --check` in the repository folder
   (Windows PowerShell: `.\install.ps1 -Check`). Exit 10: Docker is missing or stopped, tell
   the person. Exit 11: pick a free port and pass `--port`. Exit 13: another Glassy already
   exists on this machine; stop and ask.
2. **Ask the person, in one message:**
   - their Glassy account email, and whether the account is on glassy.fyi or Clear (a free
     account is enough);
   - to make a pairing token at Settings → Account → Self-hosting on their cloud account and
     save it to a file, then tell you the path (not paste it in chat);
   - whether AI should also run on this machine (default: not now);
   - whether they will do the first sign-in themselves (default: yes).
3. **Install:** `./install.sh --email <email> --token-file <path> --yes`
   (add `--cloud clear`, `--port <n>`, `--with-ollama` as answered).
4. **Prove it:** `./doctor.sh`. Right after an install, one "attention" line about nobody
   having signed in yet is correct. Any "problem" line is not.
5. **Tell the person:** the address, the command that shows their one-time password
   (`docker exec glassy cat /app/data/.initial_admin_password`), to keep a copy of `.env`, what
   you checked and what you did not. Never show the password, the token or `.env`.

## Never without a yes

- `docker compose down -v` or removing a volume (erases every note)
- stopping or replacing another Glassy
- changing `JWT_SECRET` or `API_KEY_ENCRYPTION_KEY` in an existing `.env`
- setting `GLASSY_TAG` to `latest` or `main`
- opening Glassy to the internet
- installing Docker or other system software

## Know this

- "Glassy couldn't confirm your account" is not a failed install. Glassy works; check the
  email and token with the person.
- Glassy never provides AI on a self-host. Do not promise it.
