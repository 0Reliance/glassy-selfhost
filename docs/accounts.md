# Your account

## Why Glassy asks you to sign in

This Glassy is yours and runs on your machine. Signing in keeps your notes private from
anyone else who can reach the machine or your network.

Your sign-in is local. Glassy checks your email and password against its own database on your
machine. Nothing about your notes, your password or your sessions is sent anywhere.

## What Glassy checks with your account

When Glassy starts, it asks the Glassy cloud one question: does this account exist, and is
this its pairing token? It sends your email and the token. It sends no password and no notes.

- The answer is kept for 30 days, so Glassy works offline within that time.
- If Glassy can't confirm your account, it starts anyway and everything on your machine
  works. It asks again at the next start.
- Any account works, free included. The check is not about what you pay.

That check, and any AI service you choose yourself, are the only times this Glassy contacts
another server. There is no tracking and no usage reporting.

## One person by default

A self-host starts with one account: yours, made from your account email at first start.
Nobody else can register.

- **More workspaces for you** are free. Add them in Settings → Account → Workspaces. Each has
  its own notes and settings, and you switch between them without signing out.
- **More people** come with a seat pack, a one-time purchase that lets you add accounts up to
  its size. Sizes and prices are on [glassy.fyi/pricing](https://glassy.fyi/pricing).

## If you forget your password

Email is off on a self-host, so there is no reset link. There are two ways back in.

**You set up a recovery key.** On the sign-in screen choose "Use secret recovery key". You can
make one in Settings → Connections & data → Import & export. Do it now, before you need it.

**You didn't.** Reset the password from the machine itself. This keeps all your notes. Run it
from the Glassy folder, with your account email and a temporary password of your choosing:

```bash
docker compose stop
TAG=$(grep '^GLASSY_TAG=' .env | cut -d= -f2)

docker run --rm -v glassy-selfhost_glassy-data:/app/data \
  -e RESET_EMAIL='you@example.com' -e RESET_PASSWORD='Temp-Pass-12345' \
  --entrypoint node "ghcr.io/0reliance/glassy-dash:${TAG}" -e '
const sqlite3 = require("sqlite3");
const bcrypt = require("bcryptjs");
const db = new sqlite3.Database("/app/data/notes.db");
const hash = bcrypt.hashSync(process.env.RESET_PASSWORD, 12);
db.run(
  "UPDATE users SET password_hash = ?, password_must_change = 1 WHERE email = ?",
  [hash, process.env.RESET_EMAIL],
  function (err) {
    if (err) { console.error(err.message); process.exit(1); }
    console.log(this.changes === 1 ? "Done. You will choose a new password when you sign in." : "No account has that email. Nothing changed.");
    db.close();
  }
);
'

docker compose up -d
```

Put your own email and a temporary password in the second line.

Sign in with the temporary password. Glassy asks you to choose a new one straight away.

## Two-step sign-in

Turn it on in Settings → Account → Security. Glassy gives you ten recovery codes, shown once.
Keep them somewhere safe.

If a code is refused though it is right, the clock on this machine is probably off. See
[Troubleshooting](troubleshooting.md#a-two-step-code-is-refused).

## If a paid membership ends

| | What happens |
|---|---|
| This Glassy, your notes, and updates | Nothing changes. It is yours. |
| The account check at start | Still passes, as a free account |
| Cloud Sync with a Glassy cloud account | Slows to the free plan's pace |
| Storage on your Glassy cloud account | Returns to the free plan's amount. Nothing is deleted. |
| Publishing on your Glassy cloud account | Stops until you pay again |
| A Zero Reliance Pair you set up | Keeps running |

Each plan's numbers are on [glassy.fyi/pricing](https://glassy.fyi/pricing).
