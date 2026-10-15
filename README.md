# MCP Services Dashboard

Course project connecting Claude Code to third-party services via official MCP servers, downloading local copies of data from each, and building a local dashboard that searches across all of it.

## Services connected

- **GitHub** — official MCP server (`https://api.githubcopilot.com/mcp/`)
- **Notion** — official MCP server (`https://mcp.notion.com/mcp`)
- **Jira** — Atlassian Rovo MCP server (`https://mcp.atlassian.com/v1/mcp/authv2`)
- **Slack** — official MCP server (`https://mcp.slack.com/mcp`)

**Gmail — not implemented (waived by instructor).** We set up Google's official Gmail MCP server, and the OAuth client, consent screen and sign-in all worked. However, every tool call was rejected, because the Google Cloud project must be enrolled in the Google Workspace Developer Preview Program to use it. The instructor waived Gmail for this project, so it was removed from `.mcp.json`.

All accounts used for this project are throwaway test accounts created specifically for this assignment — no personal, school, or work accounts or data are used anywhere in this repo.

## Repo layout

- `dataExports/` — local copies of downloaded data, one subfolder per service. See `localStorageFormats.md` for the exact file format used per service.
- `.claude/skills/` — project-level Claude Code skill(s) for repeatable data downloads.
- `.mcp.json` — MCP server configuration (no secrets committed).
- `webapp/` — the local dashboard website that searches across all exported data.

## Status

| Part | Status |
| --- | --- |
| Notion | Done. Exported to `dataExports/notion/`, repeatable with the `download-notion` skill |
| Jira | Done. Exported to `dataExports/jira/`, repeatable with the `download-jira` skill |
| GitHub | Done. Exported to `dataExports/github/`, repeatable with the `download-github` skill |
| Slack (Lior's extra service) | Done. Exported to `dataExports/slack/`, repeatable with the `download-slack` skill. Slack is stored as one item per channel per day, so the dashboard's 6 Slack items contain 16 messages across 3 channels |
| Dashboard (`webapp/`) | Done. Searches Notion, Jira, GitHub and Slack at once or one at a time |
| Gmail | Waived by instructor (see above) |

## Who did what

**Gabi Slepoy:**

- Notion: MCP connection, data export, and the `download-notion` skill
- Jira (Gabi's extra service): Atlassian MCP connection, data export, and the `download-jira` skill
- Gmail: the setup attempt (OAuth client, consent screen, sign-in) that led to the waiver
- The shared local storage format (`localStorageFormats.md`) and the download skills
- The dashboard (`webapp/`) and its data build script (`scripts/build-dashboard-data.ps1`)

**Lior Bongart:**

- GitHub: MCP connection, issue export, and the `download-github` skill
- Slack (Lior's extra service): MCP connection, channel export, and the `download-slack` skill
- Slack added to `.mcp.json`
- Dashboard: GitHub and Slack integration (issue number/state, per-day Slack titles)

## Running the dashboard

The dashboard in `webapp/` is a local website that searches all downloaded data in `dataExports/` at once (or one service at a time). It is plain HTML/CSS/JavaScript, reads only local files, works offline, and needs nothing installed on Windows or Mac.

**To open it:** double-click `webapp/index.html`. That's it.

**Optional local server (Windows):** from the repo folder run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File webapp/serve.ps1
```

It opens `http://localhost:8000/webapp/` in your browser. Press `Ctrl+C` to stop it.

**After every download**, rebuild the dashboard's data file (`webapp/data.js`) and reload the page:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-dashboard-data.ps1
```

New services (GitHub, a partner's service) show up automatically once their folder follows `localStorageFormats.md` and this script is rerun. Full instructions, search rules and troubleshooting: [`webapp/README.md`](webapp/README.md).
