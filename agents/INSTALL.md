# Install Glassy for a person

**Goal:** Glassy is running on this machine from this folder, and you have shown it is healthy.
**Done when:** `./doctor.sh` shows no "problem" lines and you have given the person the hand-back in step 7.
**Takes:** about five minutes, most of it the first download.

You do the work through `install.sh`. It checks the machine, writes the settings file, starts
Glassy and confirms it. It is safe to run more than once: it keeps every value already set and
never touches data.

## 1. Check first

Run from the repository folder:

```bash
./install.sh --check
```

Expected: `ok` lines for Docker, the port and disk space, then "This machine is ready for
Glassy. Nothing was changed."

| If it stops with | It means | Do this |
|---|---|---|
| exit 10, "Docker isn't installed" or "isn't running" | No Docker, or it is stopped | Tell the person. Installing Docker is their call: https://docs.docker.com/get-docker/ |
| exit 10, "neither curl nor wget" | Nothing to check Glassy with | Ask before installing curl. |
| exit 11, "Port 3000 is already in use" | Something else has the port | Pick a free one and pass `--port`, for example `--port 3005`. Tell the person which you chose. |
| exit 13, "A container named glassy is already running from somewhere else" | There is already a Glassy on this machine | **Stop and ask.** Do not stop or remove it. They may want that one, not a new one. |

On Windows without WSL, use `install.ps1` in PowerShell. It takes the same options with
PowerShell spelling (`-Check`, `-Email`, `-TokenFile`, `-Port`, `-Yes`).

## 2. Ask the person

Ask these together, in one message. Give the default and what each choice means.

1. **"Which email is your Glassy account under, and is it on glassy.fyi or on Clear?"**
   A free account is enough. If they have none, they make one at https://glassy.fyi first.
   Clear accounts need `--cloud clear`.
2. **"Please make a pairing token and save it in a file for me."**
   They make it at Settings → Account → Self-hosting → Generate token
   (`https://app.glassy.fyi/#/settings?g=account&s=selfhost`, or the same path on
   `clear.glassy.fyi`). Ask them to save it to a file, for example `~/glassy-token.txt`, and
   tell you the path. Do not ask them to paste it into the chat. The token ties this Glassy to
   their account, so nobody who only knows their email can set one up in their name.
3. **"Do you want AI to run on this machine too?"** Default: not now. Glassy works without it,
   and they can choose later between AI in their browser, their own Ollama, or their own key
   with a provider. If they say yes and have no Ollama, add `--with-ollama`. That starts
   Ollama beside Glassy; models are several gigabytes each and run on this machine's memory.
4. **"Will you do the first sign-in yourself, or shall I?"** Default: they do. It takes a
   minute and they choose their own password. If you do it, you have to set a password for
   them and hand it over (see [CONFIGURE.md](CONFIGURE.md#1-first-sign-in)).

Glassy never provides AI on a self-host and never pays for it. Do not promise that AI comes with it.

## 3. Install

```bash
./install.sh --email <their email> --token-file <path to the token file> --yes
```

Add `--cloud clear`, `--port <n>` or `--with-ollama` from the answers above.

Expected, in order: `ok` lines under "Checking this machine" and "Settings", then
`ok    Glassy vX.Y.Z is running at http://localhost:3000`, then "Glassy is ready".

| If you see | It means | Do this |
|---|---|---|
| exit 2 | An option was misspelled or is missing its value | Check it against `./install.sh --help`. |
| exit 12, "Glassy needs your account email" or "pairing token" | A value is missing | Supply it and run the same command again. |
| exit 12, another message | `GLASSY_TAG` is missing or is `latest`, or this is not the Glassy folder | The message says which. Fix that and run again. |
| exit 20, "Couldn't download Glassy" | No route to the image registry (`ghcr.io`) | Check the connection or proxy. Run again. |
| exit 20, "Docker couldn't start Glassy" | Compose refused | Read `docker compose logs --tail 40 glassy` and see [TROUBLESHOOT.md](TROUBLESHOOT.md). |
| exit 21, "started but isn't answering yet" | Slow first start | Wait a minute, then `./doctor.sh`. |
| `note  Glassy couldn't confirm your account just now` | The email or token did not match, or this machine could not reach Glassy's cloud | Glassy still works fully. Check the email and token with the person. It tries again at the next start. Do not treat this as a failed install. |

## 4. Stop and ask

Never do these without the person saying yes to that exact thing:

- `docker compose down -v`, or removing the `glassy-data` volume. That erases every note.
- Stopping, removing or replacing another Glassy container.
- Changing `JWT_SECRET` or `API_KEY_ENCRYPTION_KEY` in an existing `.env`. Saved keys stop working.
- Setting `GLASSY_TAG` to `latest` or `main`. Those builds hide the self-host features.
- Opening the port to the internet, or setting up a tunnel or domain.
- Installing Docker or anything else system-wide.

## 5. Prove it

```bash
./doctor.sh
```

Expected right after a new install: a list of `ok` lines (Docker, `.env`, the container, the
version, agent access, and a few more), plus one `attention` line: "Nobody has signed in yet."
That line is correct at this point.

How to read the result: **no `problem` line means the install is good.** `attention` lines are
things for the person to know, such as the first sign-in still waiting or the account not being
confirmed; they make the exit code 1 and do not mean a failed install. Any `problem` line
(exit code 2) means it is not working; go to [TROUBLESHOOT.md](TROUBLESHOOT.md).

For your own reading: `./doctor.sh --json`.

## 6. Leave it tidy

- `.env` now holds the token and two secret keys. It is already unreadable to other users and
  ignored by git. Do not copy it anywhere, and do not print it.
- Suggest the person deletes the token file once Glassy is running. The token is in `.env`.
- Do not leave test notes, extra containers or scratch files behind. (The one file you may
  leave is `glassy-first-password.txt`, if you do the first sign-in for them in the next job.)

## 7. Tell the person

If you are going straight on to [CONFIGURE.md](CONFIGURE.md), skip this and give the hand-back
at the end of that file instead: once you have done the first sign-in, the one-time password
below no longer exists.

Otherwise use this shape, in your own words, with their real values:

> Glassy is installed and running at http://localhost:3000 (version vX.Y.Z).
>
> To sign in the first time, run this to see your email and one-time password:
> `docker exec glassy cat /app/data/.initial_admin_password`
> Glassy asks you to choose your own password straight away.
>
> Your settings are in `.env` in this folder. Keep a backup of that file: it holds the two
> keys that unlock your data. You can delete the token file now.
>
> I checked: Glassy answers, the version matches, agent access is on. I did not check: [what you did not].
>
> Next, if you'd like: I can connect myself to Glassy so I can write notes for you
> (it takes a couple of minutes once you've signed in).

If the account could not be confirmed, add one line saying so and that nothing is lost.

**Next job:** [CONFIGURE.md](CONFIGURE.md).
