# Obsidian

Already keep your notes in Obsidian? Glassy sits on top of your vault, not in place of it.
Keep writing in Obsidian. Glassy searches the vault, shows it beside everything else you save,
lets your assistants read it, and can write back to it.

Only a Glassy on your own machine can do this. Your vault is on your computer, and a server
out on the internet can't reach it.

## What you need

- Obsidian, with the [Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api)
  plugin (version 4 or newer). Copy the API key from the plugin's settings.
- The Glassy Capture browser extension
  ([Chrome and Firefox](https://github.com/0Reliance/glassy-companion)).

## Link your vault

Glassy reaches your vault through the Glassy Capture extension. The extension runs in your
browser, on the same computer as Obsidian, so it can reach the vault where a container can't.
It never opens your vault to the network.

1. Install the Glassy Capture extension and sign in to it with your Glassy account.
2. In the extension, open Settings → **Obsidian Bridge**.
3. Set **Obsidian URL** to `http://127.0.0.1:27123`.
4. Paste the **API Key** from the Obsidian plugin.
5. Turn **Obsidian Bridge** on, choose **Test Connection**, then **Save**.

Test Connection checks the whole path: Glassy to the extension to Obsidian. Green means both
halves work.

In Glassy, Settings → Connections & data → Obsidian vault now says Obsidian is connected
through the browser extension. There is nothing to set in that panel on a self-host; the
address and key live in the extension, on your computer, and are never sent to Glassy.

The bridge works while that browser is open.

### Obsidian on another machine, or no browser

Glassy can also reach the Obsidian plugin directly over your network. That means making the
plugin listen beyond `127.0.0.1`, which exposes your vault to that network, so do it only on a
network you trust. The settings (`OBSIDIAN_NETWORK_ALLOWLIST`, `OBSIDIAN_HOST_OVERRIDE`) are
described in the [operations reference](reference/operations.md).

## What you can do once it's linked

- Search your vault from Glassy, together with your notes, documents and bookmarks.
- Open a vault note in Glassy, edit it, and have the change land in the file.
- Tick a checkbox, add under a heading, or append to today's daily note from Glassy.
- Save a web page from the extension straight into the vault.
- Let your assistants read vault notes and, if you allow it, append to them.

## If it isn't connecting

| What you see | Do this |
|---|---|
| The extension says connected, Glassy says not | Update the extension to the newest version and reload Glassy. |
| Reading works, writing fails | Update the extension. Writing through the bridge needs version 2.18 or newer. |
| Test Connection is red | Check Obsidian is open, the plugin is on, and the address and key match the plugin's settings. Try `http://127.0.0.1:27123` rather than the `https` address. |
| A monthly, quarterly or yearly note can't be found | That period is switched off in Obsidian's Periodic Notes settings. |
| "Invalid token" | The key in the extension doesn't match the plugin. Copy it again. |

For scripts, signed in: `GET /api/ext/obsidian-bridge/status` answers `{"connected":true,…}`
when the bridge is up.

## No Obsidian?

You don't need it. Glassy's own notes and documents are a complete library. The "vault" tools
your assistants see are only for an Obsidian vault.
