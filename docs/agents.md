# Agents in your Glassy

Glassy is built for you and your AI assistants to share. They read what you've saved, write
their work where you can see it, and ask you when a choice is yours.

## Connect an assistant

1. Open **Settings → Connections & data → Agent access (MCP)**.
2. Under **Agent keys**, choose which app is connecting and give the key the assistant's name.
3. Tick **Read-only** if it should search and recall but never write.
4. Choose **Create key**, then copy the setup the panel shows for that app into the assistant.

<img src="../assets/agent-access.webp" alt="Agent access, Agent keys: choose the app, name the agent, an optional read-only box, when the key ends, a Create key button, and below it the keys for Claude and Hermes" width="100%">

The address assistants connect to is `http://localhost:3000/mcp`.

Give your assistant [AGENTS.md](../AGENTS.md) too. It tells an agent how to work in Glassy well.

## See what your assistants did

The **Agents** page, in the sidebar, lists everyone who works in your Glassy: what each wrote,
how many tools it called, what it asked you, and what it keeps for itself.

<img src="../assets/agents-page.webp" alt="The Agents page: Juniper, with a key that reads and writes, wrote five notes and two documents, called nineteen tools and asked two questions in the last seven days" width="100%">

## Why one key per assistant

- **You can tell who wrote what.** Each note and document shows whether you or an assistant
  wrote it, and which one. Search can show everyone's work, only yours, or only your assistants'.
- **You can switch one off.** Revoking a key stops that assistant and nothing else.
- **Each keeps its own memory.**

The panel also has one shared key. It works, but Glassy can only record the name each app gives
itself, unchecked, so two apps can look alike and you can't switch off one without the others.
Use named keys.

## Where assistants' work goes

| Place | What's there | Where you see it |
|---|---|---|
| Your workspace | What an assistant wrote for you | With your own notes and documents. Documents land in the "Agent work" folder. |
| The archive | Finished work worth keeping | Found by search. Out of your everyday lists. |
| The assistant's own space | Its working notes and memory | On the Agents page and in Settings → Agent access (MCP), listed per assistant. Kept out of your lists and search, never hidden from you. |

You can move anything from one place to another.

## When an assistant asks you something

A question from an assistant appears under **Decisions** on Today, with the choices as buttons
and what each one leads to. Click one; the assistant picks up your answer and carries on.
Nothing consequential needs to happen without you.

## What an assistant can't do

- Sign in as you, or see your password.
- Restore something from the bin. Only you can.
- Change your settings, keys or account.
- Read anyone's private notes, on a Glassy with several people.

## Assistants and the people on your Glassy

On a Glassy with several people ([Set up Glassy for your people](people.md)), an admin decides
what each assistant may do with them, in **People → Agents**:

- **Reach** lets an assistant share, assign, ask a group and send notices to people, on behalf of
  the person whose key it is. It sees only what was shared with everyone.
- **Admin reach**, for an admin's own assistant, also lets it invite people, change their options,
  run groups and starting setups, and close the account of someone who left. Every change is in
  the activity log under the assistant's name and the admin it works for.
- **Always yours to decide:** making someone an admin, downloading a closed account's things and
  deleting an account for good. The assistant can only ask; the request waits for an admin in
  People. It never signs in as anyone, sets a PIN or gives another assistant reach.

## Letting Glassy hand work to an agent

The other direction is called dispatch: Glassy starts a task on an agent you run, from a
calendar event or a button. Set it up in **Settings → Connections & data → Agent dispatch**.
The technical details are in the [agent reference](../agents/REFERENCE.md#connecting-an-agent-as-a-dispatch-target).

## Agents on Glassy's cloud

Glassy cloud accounts have agents too: a named key for each agent, questions under Decisions
and notices, with limits that depend on the plan. On the cloud, anything an agent makes public
waits for your yes under Decisions. Running Glassy yourself adds what the cloud keeps back:
several people on one Glassy, your Obsidian vault, pictures from agents, and no limits.
