# Update Glassy

You choose when Glassy updates. Nothing changes until you do this.

## Update

In the Glassy folder:

```bash
git pull
```

That brings the newest `.env.example`, which names the newest version. Copy that version into
your own `.env`:

```bash
grep '^GLASSY_TAG=' .env.example      # shows the newest version
```

Edit the `GLASSY_TAG` line in `.env` to match, then:

```bash
docker compose pull
docker compose up -d
./doctor.sh
```

Glassy updates its database by itself when it starts. Your notes stay where they are.

Then reload Glassy in your browser. A tab that was open during the update keeps running the
old version until it reloads.

**Before a big jump,** take a [backup](backups.md#keep-a-copy-somewhere-else). It takes a minute.

**If you use Cloud Sync,** update both sides.

## What changed

[What's new](whats-new.md) lists each version in plain words.

## Go back to the version before

Set `GLASSY_TAG` in `.env` to the earlier version, then `docker compose up -d`. If that
version is older than the database now expects, restore the backup you took before updating.

## Why not update automatically?

Glassy runs a named version on purpose, so an update never surprises you. The
`docker-compose.watchtower.yml` overlay exists for people who want hands-off updates of a
moving tag, but with a named version it has nothing to do. Don't point `GLASSY_TAG` at
`latest` to get automatic updates: that build is made for Glassy's own cloud and hides agent
access, search settings and your own AI keys.

## Start completely fresh

This erases every note, setting and account on this machine. Take a backup first if there is
anything you want.

```bash
docker compose down -v
```

Then, before starting again, open `.env`, delete the value after `JWT_SECRET=` (leave the
name), and run:

```bash
./install.sh
```

The installer makes a new secret, so browsers that were signed in to the old Glassy are signed
out, and starts Glassy.

Glassy starts as new, with a new one-time password.
