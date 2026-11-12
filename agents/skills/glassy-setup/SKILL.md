---
name: glassy-setup
description: Set up a newly installed Glassy Self-Host - first sign-in, a named agent key for yourself, connecting over MCP, and choosing where AI runs. Use after installing Glassy, or when asked to connect yourself or another assistant to a Glassy.
---

# Set up a new Glassy

Full steps: `agents/CONFIGURE.md` in the glassy-selfhost repository. Short form below.
Addresses assume `http://localhost:3000`.

## Do this

1. **First sign-in.** Until the first password is changed, every signed-in call answers
   `403 PASSWORD_CHANGE_REQUIRED`. That is not a broken install. Prefer that the person signs
   in and chooses their own password. Only if they asked you to: read
   `/app/data/.initial_admin_password` inside the container (email, then password), sign in
   at `POST /api/auth/login`, set a strong starting password with
   `POST /api/auth/change-password` (`currentPassword`, `newPassword`), save it to
   `glassy-first-password.txt` readable only by them, and tell them to change it and delete
   the file.
2. **Your own key.** A named agent key, one per agent. The person makes it in Settings →
   Connections & data → Agent access (MCP). If you did the first sign-in:
   `POST /api/mcp-keys` with `{"agentName":"<your name>"}` and the sign-in token. Keep the key
   in your client's configuration only.
3. **Connect.** MCP endpoint `http://localhost:3000/mcp`, header
   `Authorization: Bearer <key>`. Over plain HTTP send
   `Accept: application/json, text/event-stream`.
4. **Prove it.** Read `glassy://status` (expect your name with `"verified": true`), write a
   note with `glassy_note_create`, find it with `glassy_search` (expect `createdBy` to be
   you), then archive it.
5. **AI.** Ask where AI should run: their device (free), their own Ollama (free), or their own
   provider key (that provider bills them). Recommend Ollama if it is on this machine.
   Never add a provider key yourself unless handed one for that purpose.
6. **Tell the person:** the name you are connected as and where to revoke the key, the AI
   choice and its cost, where the starting password file is if you made one, and what you
   checked and did not.

## Never without a yes

Changing a password again, making or revoking another key, adding an AI key, opening Glassy to
other devices, turning on Cloud Sync or linking Obsidian.
