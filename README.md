# MCP Services Dashboard

Course project connecting Claude Code to third-party services via official MCP servers, downloading local copies of data from each, and building a local dashboard that searches across all of it.

## Services connected

- **Gmail** — official MCP server (TBD endpoint, pending verification)
- **GitHub** — official MCP server (`https://api.githubcopilot.com/mcp/`)
- **Notion** — official MCP server (`https://mcp.notion.com/mcp`)
- **Slack** — official MCP server (TBD endpoint, pending verification)

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
