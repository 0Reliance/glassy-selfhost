# Install Glassy on your machine

Ten minutes, most of it one download. When you finish, Glassy is running at
`http://localhost:3000` and stays running across restarts.

Having an AI agent do this for you? Point it at [AGENTS.md](../AGENTS.md) instead.

## What you need

- **Docker**, with Compose v2. Docker Desktop on Windows or Mac, Docker Engine on Linux.
  [Get Docker](https://docs.docker.com/get-docker/).
- **A Glassy account.** A free one is enough. [Sign up at glassy.fyi](https://glassy.fyi).
- **About 2 GB of disk** for Glassy, plus room for your notes.

## 1. Get your pairing token

Sign in to your Glassy account on the web and open
**Settings → Account → Self-hosting → Generate token**.

- Free and Pro accounts: <https://app.glassy.fyi/#/settings?g=account&s=selfhost>
- Clear accounts: <https://clear.glassy.fyi/#/settings?g=account&s=selfhost>

Copy the token. It is shown once. The token ties this Glassy to your account, so someone who
only knows your email can't set one up in your name.

## 2. Run the installer

```bash
git clone https://github.com/0Reliance/glassy-selfhost.git
cd glassy-selfhost
./install.sh
```

On Windows, in PowerShell: `.\install.ps1`

The installer checks your machine, asks for your email and token, makes the two secret keys
Glassy needs, starts Glassy and confirms it is running. It ends by telling you how to sign in.

Useful options:

| Option | What it does |
|---|---|
| `--check` | Only checks the machine. Changes nothing. |
| `--port 3005` | Use another port if 3000 is taken. |
| `--cloud clear` | Your account is on Clear. |
| `--with-ollama` | Also start Ollama, so AI can run on this machine. |

You can run the installer again at any time. It keeps every value you already set and never
touches your notes.

## 3. Sign in

The installer prints this command. It shows your email on the first line and a one-time
password on the second:

```bash
docker exec glassy cat /app/data/.initial_admin_password
```

Open <http://localhost:3000>, sign in, and choose your own password when Glassy asks. The
one-time password stops working after that.

## 4. Keep one file safe

`.env` in the Glassy folder holds your token and the two keys that unlock your data. Keep a
copy somewhere safe, and don't share it.

## Next

- [Choose where AI runs, connect an assistant, link Obsidian](configure.md)
- [Use Glassy from your phone or another computer](reach-it-from-other-devices.md)
- [Back up your notes](backups.md)
- Check on Glassy any time with `./doctor.sh`

## Installing by hand

If you would rather not run a script, this is everything it does.

```bash
git clone https://github.com/0Reliance/glassy-selfhost.git
cd glassy-selfhost
cp .env.example .env
# Edit .env — fill in six required fields:
#   GLASSY_TAG=v2.65.24                          (already set; leave it)
#   GLASSY_MEMBER_EMAIL=you@example.com          (your Glassy account email)
#   GLASSY_SELFHOST_TOKEN=<your pairing token>   (from step 1)
#   GLASSY_VERIFY_CLOUD_URL=https://app.glassy.fyi   (Clear accounts: https://clear.glassy.fyi)
#   JWT_SECRET=<run: openssl rand -hex 32>
#   API_KEY_ENCRYPTION_KEY=<run: openssl rand -hex 32>
docker compose up -d
```

Wait until `curl -s http://localhost:3000/api/health` answers `"status":"ok"`, then sign in as
in step 3.

`GLASSY_TAG` names the released version to run, and `.env.example` always names the current
one. Don't set it to `latest`: that build is made for Glassy's own cloud and hides agent
access, search settings and your own AI keys.

## If something goes wrong

Run `./doctor.sh`. It says what is healthy and what to do about what isn't.
More in [Troubleshooting](troubleshooting.md).
