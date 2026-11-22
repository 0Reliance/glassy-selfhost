# Set up Glassy for your people

One person starts it. Any admin can run it: invite people, choose what each person may do, make
groups, share what everyone needs and let an agent help. Nobody signs in as anyone else, and
nobody's private notes are opened while their account is open: only a closed account's things
can be downloaded, by an admin, and each download is in the activity log.

This page is written for you and for an agent you hand it to. Everything here works in the
app, in **People** in the sidebar, and through the agent tools at the end.

## Before you start

- Glassy Self-Host, with a seat pack for the number of people (see [Your account](accounts.md)).
  On a Glassy with one seat and only you on it, the sidebar has no **People** entry (**Admin**
  stays); it appears once a seat pack adds seats or someone else is on it.
- The first account on the machine is an admin. When you upgrade a Glassy that already has
  people on it, everyone on it becomes a member, everyone who was an admin stays one, and
  nobody's access changes. There is one group, **Everyone**, and it has no name until an admin
  gives it one.
- Glassy has no built-in kinds of people, groups or boards. Everything a person reads on the
  People page comes from you: the group's name, the names of your groups and the names of
  your starting setups.

## Admins and members

| | Who it's for | What they can do |
|---|---|---|
| Admin | Anyone you trust to run this Glassy | Everything on this page, with the options below set for themselves |
| Member | Everyone else | Their own space, the options an admin set for them, and leaving |

- **Any admin can make another person an admin, or make an admin a member.** In **People**,
  choose **Make admin** or **Remove admin** next to a name. **Admin → Users** follows the same
  rules.
- **There is always one admin.** The last admin can't be made a member, removed, closed or
  deleted until someone else is an admin. Glassy says "Someone else has to be an admin first."
- Someone who stops being an admin keeps nothing only an admin could make: the shared screens
  and shared devices they set up are turned off, the reach they gave their own agents ends and
  their open invites for admins are withdrawn.
- **Name this group** in **People** (the button reads **Change name** once there is one). The
  name is the title of the page and it is how people and agents can address everyone. Until you
  set one, the page says People. You can clear it again.

### What an admin sets for each member

- **How they share:**
  - **Shares directly.** Notes, documents, folders and calendars they share show up for people
    at once.
  - **Shares need the other person's OK.** A note they share goes out as a request, and the
    people it reaches accept it. Nothing else is shared.
  - **Can't share.** They can't share, assign or send to others, and can't set up a
    check-in.
- **Admins may look after this space.** When it is on, an admin can open that person's space
  to set up their board and look. The person sees that it is on in their own settings, and a
  banner shows while an admin is in their space. Turning it off ends a visit that is under way,
  and turning it on again doesn't bring that visit back: open their space again for a new one.
  Making them an admin, the visiting admin stopping being one, or either account closing ends a
  visit the same way.

- **Can sign in on a shared device.** They use a PIN on a device several people share
  (section 6). Turning it off clears their PIN. If they haven't set a password yet, Glassy says
  so: they can't sign in until one is set, and an admin can set one in **Admin → Users**. Someone
  who has only a PIN can't be made an admin until they have a password.

Admins can't be looked after and can't sign in on a shared device, so those two options are
for members.

An admin never reads the private notes of anyone whose account is open. **Download their
things** works only once an account is closed (see "When someone leaves"), and each download is
in the activity log. A visit to someone's space is shown on screen and
kept in the activity log, with every change made during it. It lasts at most 8 hours and can't
be extended. While in someone's space you can look after their notes, documents, folders,
calendar events, boards and look, and finish their jobs, and nothing else: their account, keys
of any kind, password, two-step sign-in, sync, billing, push devices, exports, sharing, making
anything public and the group's own settings all wait until you're back in your own sign-in.

If an admin makes someone's sharing stricter, Glassy takes back what the new option doesn't
allow: shares they made that it no longer allows stop, and when they now need the other
person's OK, their note shares become requests the people accept.

## 1. Invite people

In **People → Invite someone**, give their name and choose their options, whether they are an
admin, the groups they join besides Everyone and, if you like, a starting setup (section 4).
You get a code like `ABCD-2345` and a link. Send either one however you like. The link in
**People** starts with the address you opened People at; the link an agent gets starts with
`APP_URL`, so set `APP_URL` in `.env` to the address your people use.

- The link opens one screen: their name is already filled in, they choose a password, and they
  are in. You never pick it.
- Someone whose invite turns on the shared-device option chooses a PIN instead. Joining doesn't
  sign them in on the device that opened the link: they sign in on the shared device, by picking
  their name and typing their PIN. From that sign-in they can choose **Set a password so you can
  also sign in on your own device** in **People**, and then sign in anywhere. An admin invite
  never has that option. Until they set a password, the PIN screen on the shared device is the
  only way in, even if their invite had their email: no emailed password reset and no Google
  sign-in, also on a Glassy where those are set up. An admin can also set a password for them in
  **Admin → Users**.
- An email address is optional. Without one, Glassy gives them a sign-in name and shows it.
- On joining they get their options, Everyone and the groups on the invite, the starting setup
  (skipped, and noted in the activity log, if it was deleted since), and a short welcome note
  that says how sharing works for them and who the admins are.
- A code works once, for 14 days. Withdraw it any time. Each open invite holds a seat.
- An admin's agent with admin reach can make the invite (`glassy_admin_invites` create, never as
  an admin) and gets back `link`, the join link to pass on. It uses `APP_URL`; when that is not
  set, the agent gets the path to open on this Glassy.

## 2. Groups

**Everyone** holds every person and can't be changed. Make your own in **People → Groups**,
and name them whatever your people call themselves.

Share with a group and everyone in it gets it, including people you add later. Take someone out
and it leaves their lists.

## 3. Share what everyone needs

- **A note or board:** open it, choose the collaborator button, then **Share with people**.
- **A document:** the people button at the top of the document.
- **A shared calendar:** share it once, and people you give edit access add events to it from
  their own calendar. Events can say who they're for, and each person's colour shows on the
  calendar.
- Choose **Can edit** or **Can read**. Reading means they open it but don't change it.

What someone can share depends on how an admin set them up (see "What an admin sets for each
member"). These rules hold wherever a note is shared from, including the older **Collaborate**
button. Access someone accepted from a request ends when either person leaves.

Someone you share with to edit changes what the note or document says, not who can see it or
where it sits: making it public, hiding it, pinning it and moving it stay with its owner.

## 4. Starting setups

Glassy ships with none. An admin saves one from a person: the look they have now (theme,
accent, background, glass, font and spacing) and, if the admin chooses, one board that person
owns, under a name of up to 60 characters. Applying a setup to someone sets that look and gives
them their own copy of the board. Applying it again keeps the copy they have, as they left it.
A setup never keeps a name, email, notes, PIN or a picture someone uploaded. There can be up to
50 setups, and a board in one has to fit the note size limit.

API: `GET /api/people/setups`, `POST /api/people/setups` (`fromUserId`, `name`,
`includeBoard`), `POST /api/people/members/:userId/setup` (`setupId`),
`DELETE /api/people/setups/:id`. Admins only.

## 5. Day to day

- **Send to people:** **People → Send**. Everyone you pick gets a notification, and on
  their phone if they turned that on. Each can tap **Seen**, and you see who has.
- **Assign a job:** from a checklist, give an item to someone with a time. They see it under
  **Assigned to you** on Today and get a reminder when it's due. Ticking it finishes it.
  Assigning follows the sharing rules: if the person can't open the note yet, the note's owner
  gives them edit access with the job when the owner shares directly; when the owner's shares
  need the other person's OK, they're asked to accept first; someone who only edits another
  person's note can hand it only to people who can already open it. Taking a job back removes
  the access it gave.
- **Ask the group:** a question to a group or to everyone, decided by the first answer, when
  everyone agrees, by most answers, or by one person while the rest advise. It shows on their
  Today.
- **Check-ins:** **People → Check-ins** asks a group the same question on a schedule ("What's on
  your week?" every Sunday at 6) and gathers the answers on one board everyone can read. A
  check-in needs a person who shares directly.
- **A weekly agenda** arrives for each person on Monday morning.

## 6. Shared devices and shared screens

- **Shared device, PIN sign-in:** on a tablet or computer several people use, choose
  **People → Screens and devices → Use this device for PIN sign-in**. Then the PIN screen shows
  the members who can sign in on a shared device; each picks their name and types their PIN. An
  admin sets the PIN in **People**. After 5 wrong PINs the PIN waits 5 minutes, after 10 an
  hour, and after 15 it stays locked until an admin sets a new one in **People**.
- **Each kind of try is counted on its own.** Wrong PINs, invite codes and shared screens each
  have their own limit, apart from the sign-in page, so many wrong PINs don't stop a shared
  screen, an invite or anyone signing in. A shared screen that checks for changes every 30
  seconds never reaches its limit.
- **A shared screen:** **People → Screens and devices → Add a shared screen** puts one board on
  a screen that stays on. People there can tick items, add to the list and finish jobs on that
  board, and nothing else; questions are answered on their own devices. Turn a shared screen
  off any time.
- **Boards you can tap:** a board can tick and add to its own list, answer a question linked to
  it that was asked of you, and finish your own job on it. It can't change any other note.

## 7. Let an agent help

An admin gives an agent's key **reach** in **People → Agents**. The agent then acts for the
people on this Glassy as itself, sees only what was shared with everyone, and never signs in as
anyone. There are two kinds of reach:

- **Reach** lets the key share, assign, send and ask. Any member's key can have it.
- **Admin reach** lets a key that belongs to an admin manage people with the same powers the
  admin has: the eight tools whose names start with `glassy_admin_`. A member's key can never
  have it, and it ends when the key's owner stops being an admin. The last-admin rule holds for
  agents too, and what an agent does is in the activity log with its name and the admin it
  worked for. Allowing admin reach for a key that had no reach gives it reach too (the group
  tools); if reach was taken away from that key before, it stays away until you give it again.
- A shared screen an agent adds acts with the access of the admin who owns its key, on its own
  board only, and the activity log names the agent and that admin.
- **An agent asks; an admin decides.** An agent never makes anyone an admin, downloads a closed
  account's things or deletes an account for good. It asks: you get a review, the request shows
  in the activity log in **People**, and you do it in **People** yourself. An agent can claim a
  member invite it made, but it can't make that account an admin. It can make an admin a member,
  and the last admin still stays.

| To do this | The agent uses |
|---|---|
| Learn the names and groups | `glassy_list_members` |
| Share a note, document, folder or calendar | `glassy_share` |
| Give someone a job, with a reminder | `glassy_assign` |
| Send to everyone, a group or a person | `glassy_notify` with `audience` |
| Ask a group and decide by a rule | `glassy_request_review` with `audience` and `rule` |
| Put an event on a shared calendar for people | `glassy_create_event` with `for` |
| Ask on a schedule | `glassy_checkin` |
| Put a picture on a board | `glassy_upload_image`, then use its `canvasUrl` |
| Manage people, invites, groups, setups, seats, devices and the group's name; read the activity log (admin reach) | `glassy_admin_people`, `glassy_admin_invites`, `glassy_admin_groups`, `glassy_admin_setups`, `glassy_admin_seats`, `glassy_admin_devices`, `glassy_admin_settings`, `glassy_admin_audit` |

Pass `onBehalfOf` with the name of the person who asked; the activity log records it. An agent
without reach gets a reply saying how to grant it. The full list is in the
[agent reference](../agents/REFERENCE.md).

## Pictures and privacy

Pictures and recordings people upload open for the person who uploaded them, and for someone
who can open a note or document they put them in. A picture on a board opens for the people
who can open that board. A picture the uploader put in a public note, document, recording or
bookmark shows to everyone, and stops the moment it's made private again. Pasting a picture's
address into a note, yours or someone else's, opens nothing. Avatars and banners always
show. Changing your password ends every picture link made before it. A picture shown inside a
board carries a short-lived key in its address, so if this Glassy is reached through
Cloudflare, Cloudflare's own logs can see that address; the key opens only that board's
pictures and runs out within 12 hours.

Files from before several people shared a Glassy, whose owner Glassy can't tell (because more
than one person's notes use them, or none do), work the way they always did, but no wider:
anyone signed in who can open a note or document using one sees it, and a public item using one
shows it to everyone. A file no note uses and nobody owns, like an old report an agent wrote,
opens for anyone signed in to this Glassy. That keeps old libraries and reports working; the
cost is that someone here who knows such a file's address can open it. To close that, set
`UPLOADS_LEGACY_OPEN=false`, and such files open for no one. Pictures inside checklist items
aren't looked at when deciding who may open a picture; put pictures in the note itself.

## When someone leaves

Someone can leave from **People**, and an admin can take someone out. Their own notes
and documents stay theirs on this Glassy. What they shared with others, and what was
shared with them, stops; every job given to them is withdrawn with the access it gave; the
shared screens and shared devices they set up are turned off. An admin can bring them back
without a new invite.

Someone who left still has their account, so they still hold a seat. To free it:

1. **Close their account** (**People**, in the list of people who left). They can't sign in,
   and the seat is free for someone else. Their notes and documents are kept. Anything they had
   shared with others is copied to the admin who closes the account and shared again, so the
   shared boards carry on. You can **Reopen** the account for 30 days.
2. **Delete for good**, only once the account is closed. **Download their things** first if you
   want a copy: it works only for a closed account, it's kept in the activity log, and an agent
   can only ask you for it. You type their name to confirm; it can't be undone, and it's kept in the
   activity log.

Closing an account, downloading their things and reopening it are each kept in the activity
log, so a download made while the account was closed still shows there after it is reopened.

Closing an account also turns off every agent key that person made: an agent using one is told
"Invalid MCP API key". Reopening the account doesn't turn those keys back on; the person makes
new ones in **Settings → Connections & data**.

To leave as an admin, choose **Remove admin** next to your own name first (someone else has to be
an admin), then **Leave** appears in **People**.

The last admin can't be taken out or closed (see "Admins and members"). **Admin → Users**
follows the same rules: its delete button closes the account, and *Invite someone* takes you
here. If every seat is taken, the message names anyone who left and still holds one.
