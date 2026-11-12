# Backups

Your notes live in one Docker volume on this machine, named `glassy-selfhost_glassy-data`. It
holds the database, your images and recordings, and Glassy's own backups.

## What Glassy does by itself

Every night at 02:00 (by the container's clock, which is UTC unless you changed it), Glassy saves a copy of the database inside that volume and keeps about a
week of them. You don't set anything up.

Those copies protect you from a mistake or a bad update. They are in the same volume as your
notes, so they don't protect you from a failed disk or a deleted volume. For that, keep a copy
somewhere else.

`./doctor.sh` tells you how old the newest backup is.

## Keep a copy somewhere else

This saves everything (database, images, recordings and the nightly copies) into one file in
the current folder. Glassy is stopped for the few seconds it takes, so the copy is whole:

```bash
docker compose stop
docker run --rm -v glassy-selfhost_glassy-data:/data -v "$(pwd)":/backup alpine \
  tar czf /backup/glassy-backup-$(date +%Y%m%d).tar.gz -C /data .
docker compose up -d
```

Move that file to another disk or another machine. Do it on a schedule that matches how much
you'd mind losing: weekly is a sensible start.

Also keep a copy of `.env`. Without its two keys, the AI keys you saved can't be unlocked.

## Make a backup right now

```bash
docker compose exec glassy node server/utils/backup.js
docker compose exec glassy ls -1 /app/data/backups
```

To have these extra copies locked, set `BACKUP_ENCRYPTION_KEY` in `.env` first. It must be 64
hex characters; make one with `openssl rand -hex 32`. Keep that key with your copy of `.env`:
a locked backup can't be opened without it.

## Restore

Restoring replaces what is there now with what was there then. Stop Glassy first, so nothing
is written while the database is swapped.

**From one of Glassy's database copies:**

```bash
docker compose exec glassy ls -1 /app/data/backups        # choose a file
docker compose stop
docker compose run --rm --no-deps --entrypoint node glassy server/utils/backup.js --restore <backup-file>
docker compose up -d
```

Glassy saves a safety copy of the current database first (next to it, named
`notes.db.pre-restore-…`), waits five seconds (Ctrl+C stops it), then puts the backup in place.
Anything written since that backup is in the safety copy, not in your library.

**From a full copy of the volume**, onto this or a new machine. This empties the volume first,
then fills it from your file:

```bash
docker compose stop
docker run --rm -v glassy-selfhost_glassy-data:/data -v "$(pwd)":/backup alpine \
  sh -c "find /data -mindepth 1 -delete && tar xzf /backup/glassy-backup-YYYYMMDD.tar.gz -C /data"
docker compose up -d
```

On a new machine, run `./install.sh --no-start` first so the folder and `.env` exist, then put
the `.env` from your backup in place of the new one.

## Check that a backup works

A backup you have never restored is a hope. Once in a while, restore your latest file on
another machine or in a scratch folder and open it.

## Other ways to take your notes with you

Settings → Connections & data → Import & export saves your notes as files you can read
anywhere, including as an Obsidian vault.

Cloud Sync is not a backup. See [Cloud Sync](cloud-sync.md#what-cloud-sync-is-not).
