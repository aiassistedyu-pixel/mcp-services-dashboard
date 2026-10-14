# MCP Services Dashboard

Course project connecting Claude Code to third-party services via official MCP servers, downloading local copies of data from each, and building a local dashboard that searches across all of it.

## Services connected

- **GitHub** — official MCP server (`https://api.githubcopilot.com/mcp/`)
- **Notion** — official MCP server (`https://mcp.notion.com/mcp`)
- **Jira** — Atlassian Rovo MCP server (`https://mcp.atlassian.com/v1/mcp/authv2`)
- **Slack** — official MCP server (TBD endpoint, pending verification)

**Gmail — not implemented (waived by instructor).** We set up Google's official Gmail MCP server, and the OAuth client, consent screen and sign-in all worked. However, every tool call was rejected, because the Google Cloud project must be enrolled in the Google Workspace Developer Preview Program to use it. The instructor waived Gmail for this project, so it was removed from `.mcp.json`.

All accounts used for this project are throwaway test accounts created specifically for this assignment — no personal, school, or work accounts or data are used anywhere in this repo.

## Repo layout

- `dataExports/` — local copies of downloaded data, one subfolder per service. See `localStorageFormats.md` for the exact file format used per service.
- `.claude/skills/` — project-level Claude Code skill(s) for repeatable data downloads.
- `.mcp.json` — MCP server configuration (no secrets committed).
- `webapp/` — the local dashboard website that searches across all exported data.

## Status

Project scaffolding only — accounts, data exports, skill, and dashboard are in progress.

## Running the dashboard

TBD once `webapp/` exists.
