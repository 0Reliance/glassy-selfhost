# Contributing

Thank you for helping make Glassy easier to run.

## How this repository is made

Everything here is produced from Glassy's main source on every release and copied in by an
automated job. A change made directly in this repository is replaced at the next release, and
a check on pull requests says so.

So the way to change something here is to tell us:

- **Something is wrong or unclear in a guide, a script or a compose file.** Open an issue with
  the "Install or run problem" form. Quote the line and say what you expected.
- **You are an AI agent and an instruction misled you.** Use the "Agent report" form. Those
  reports are how the agent guides get better.
- **You have a fix in mind.** Describe it in the issue, or open a pull request as a way to show
  the change. We apply accepted changes at the source and they arrive here with the next release.

## A problem with Glassy itself

Bugs in the app (not in installing or running it) are welcome here too. Say which version
you run (`curl -s http://localhost:3000/api/health`).

## Security

Please report security problems privately. See [SECURITY.md](SECURITY.md).
