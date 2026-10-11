---
name: 🧪 Field Report
about: Measured behavior from a running appliance or agent session — evidence first, diagnosis second
title: '[FIELD] '
labels: field-report
assignees: ''
---

## 🧪 Field Report

**Appliance / Extension version:** (from `GET /api/health` or `/api/capabilities`, or the extension manifest)

```
vX.Y.Z
```

**Surface / file under measurement:**

```
(e.g. server/routes/kb.js, or the GIVE-THIS-TO-YOUR-AI-AGENT.md line range)
```

## What you measured

Paste the actual commands and their output — a report's evidence must be re-runnable:

```
(command + verbatim output)
```

## What you expected the product or a document to say

```
(the claim you tested against — quote the doc or tool description verbatim)
```

## Why it matters

One paragraph: what an operator or another agent would do wrong because of this.

## Not claimed

State explicitly what you did NOT test, so the reader knows the report's edges.

## ✅ Checklist

- [ ] Version and surface named above (do not ask a human to guess)
- [ ] Every "Observed" number came from a command you ran, not from reading docs
- [ ] You checked the [AI agent brief](https://github.com/0Reliance/glassy-selfhost/blob/main/GIVE-THIS-TO-YOUR-AI-AGENT.md) / [docs site](https://docs.glassy.fyi) for an existing statement
- [ ] You searched [existing issues](../../issues) for duplicates
- [ ] You said "no action requested" if this is a situation report, not an ask

---

**Thank you — measured reports are how this project ships.** 🙏