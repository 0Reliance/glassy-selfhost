# Cloud Sync

Cloud Sync keeps this Glassy and one other Glassy in step. The other one is either:

- **your Glassy cloud account** (app.glassy.fyi or clear.glassy.fyi), so your notes are also
  there when you're away from this machine, or
- **a second Glassy you run yourself**, on your own server. That is a Zero Reliance Pair:
  two machines that are both yours, with no Glassy server in between. Setup is in
  [PAIRING.md](../PAIRING.md).

Sync is off until you turn it on.

## Turn it on

1. On **the other Glassy**, open Settings → Account → Cloud Sync and choose **Make a token**.
   Copy it. It is shown once.
2. On **this Glassy**, open Settings → Account → Cloud Sync. Paste it into **Pair token**,
   put the other Glassy's address in **Syncs to**, and save. It takes effect at the next
   sync, with no restart.
3. The panel shows **Sync status**. Choose **Sync now** to run one straight away.

The sync token is separate from your self-host pairing token. You can replace it at any time;
the old one stops working at once.

## What syncs

Notes, documents and their folders, bookmarks, voice recordings, calendars and events,
conversations, pinned tags, collections, highlights, review requests and custom backgrounds.
**What syncs** in the panel lets you turn each kind on or off. A kind you turn off waits; it
isn't lost, and it flows again when you turn it back on.

A few things to know:

- **Workspaces pair by name.** Your main workspace syncs with the other side's main workspace,
  and the rest match by name. A workspace missing on the other side is made there. Moving an
  item to another workspace on one side moves it on the other.
- **Public stays where you set it.** Whether a note, document or bookmark is public never
  travels. Something that arrives by sync is private on the Glassy it arrives at, until you
  make it public there.
- **Images and audio** are fetched after the items that use them. Give a large library a few
  rounds.
- **Calendar events synced to a Glassy cloud account count toward its storage.** The panel
  says so where you choose.
- **Changes arrive within about a minute.** A full round runs every five minutes as a backstop.

Both sides should run the same version of Glassy. Update one, then the other.

## Direction and conflicts

In **Sync settings**:

- **Direction:** Two-way, Push to cloud, or Pull from cloud.
- **Conflicts:** when the same item changed on both sides, the newest change wins. You can
  choose "The cloud's version wins" instead.

## What Cloud Sync is not

It is not a backup, and it won't refill an empty Glassy. Sync carries changes as they happen.
If you reinstall and start with an empty library, sync does not bring your old notes back by
itself. Keep [backups](backups.md).

## Known limits

- A workspace's new name or color doesn't travel after pairing. Change it on each side.
- Removing a workspace on one side doesn't remove it on the other.
- Deleting a bookmark, collection, highlight, conversation or pinned tag may not travel.
  Delete it on the other side too.

## If something looks wrong

Settings → Account → Cloud Sync shows the state of the connection, how many changes are
waiting to be sent, and anything held back. If files are reported missing, check that both
sides are on the same version and have disk space before assuming anything is lost.

For scripts: `GET /api/sync-token/health` (signed in) reports the same state. More detail in
the [operations reference](reference/operations.md#12-cloud-sync-cross-instance-data-sync).
