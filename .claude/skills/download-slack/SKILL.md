---
name: download-slack
description: Download Slack channel history through the Slack MCP server (read only) and save it under dataExports/slack/ in the project's local format (one content.md + metadata.json per channel per UTC day, plus index.json). Use for requests like "download #social", "download all my Slack channels", "download Slack messages from this week", "refresh my Slack export", or "save today's #new-channel messages locally".
---

# Download Slack channels

Save Slack messages to `dataExports/slack/` in the format defined in **`localStorageFormats.md`** (repo root, sections "Common pattern" and "Slack"). Read that file first; it is the source of truth for folder names, files and every field. This skill covers *how* to produce that format.

The Slack MCP server is configured in the project's `.mcp.json` (server `slack`, `https://mcp.slack.com/mcp`); it may also be available through the Claude Code Slack plugin. Its tools are named `mcp__slack__*` when loaded from `.mcp.json`, or `mcp__plugin_slack_slack__*` via the plugin.

## Hard rules

- **Read only.** Use only `slack_list_user_channels`, `slack_search_channels`, `slack_read_channel`, `slack_read_thread`, `slack_read_user_profile` and `slack_search_users`. Never call a tool that sends, schedules, drafts, reacts, uploads, or creates or changes channels, canvases or lists (`slack_send_message`, `slack_schedule_message`, `slack_send_message_draft`, `slack_add_reaction`, `slack_create_*`, `slack_update_*`, …).
- **Whole UTC days only.** A folder holds *every* message in a channel on one UTC day. Never write a day you only fetched part of: it would replace the saved day with fewer messages.
- **No duplicates.** A channel-day is identified by `<channel ID>:<YYYY-MM-DD>`, never by folder name. `write-channels.ps1` finds existing folders by `id` and updates or renames them (channels can be renamed).
- **Public and private channels only.** Don't download DMs or group DMs unless the user explicitly asks.
- **Don't hand-write the files.** Save the raw MCP response to a file and convert it with `write-channels.ps1` (step 4). It parses the message text, converts `ts` to UTC, groups by day, and drops email addresses.

## 1. Work out which channels and days

| Request | How |
|---|---|
| "all my channels" | `slack_list_user_channels` with `types: "public_channel,private_channel"`, `exclude_archived: true` |
| "#name" | `slack_list_user_channels` with `name_prefix: "<name>"`, or `slack_search_channels` if the user isn't a member |
| "this week" / "today" / a date range | Turn it into whole UTC days: `oldest` = 00:00:00 UTC of the first day and `latest` = 00:00:00 UTC of the day after the last, both as Unix seconds (e.g. `"1792022400"`). Say which days you used. |
| no dates given | the whole channel history (no `oldest` / `latest`) |
| "refresh" / "update my export" | every `channel.id` in `dataExports/slack/*/metadata.json`, whole history |

If a channel has more than ~500 messages in the range, say how many and confirm before downloading.

## 2. Read each channel

Call `slack_read_channel` with `channel_id`, `limit: 100`, plus `oldest` / `latest` from step 1. Use the default (`detailed`) response format. Read independent channels in parallel.

- **Saving responses:** save the exact JSON response (`{ "messages": "...", "pagination_info": "..." }`) to a file in the scratchpad (Write tool), unchanged. Large responses are saved to a file by the tool; use that path.
- **Pagination:** if `pagination_info` says there are more messages, call again with the same arguments plus `cursor`. Each page is its own response and request file in step 4. The script merges every page of a channel before grouping by day, so pass them all in one run.

## 3. Read threads

If a message in the response shows that it has thread replies, call `slack_read_thread` with `channel_id` and `message_ts: <the parent's ts>`, `limit: 1000`, and save the response to its own file. Add each thread call to the request file's `supporting_requests`. Replies are stored beneath their parent, in the parent's day, even if they were posted on a later day.

## 4. Write the channel-day folders

For each channel response file, write a request file to the scratchpad describing the call that produced it:

```json
{
  "mcp_server": "slack",
  "mcp_server_url": "https://mcp.slack.com/mcp",
  "tool": "slack_read_channel",
  "arguments": { "...": "exactly the arguments sent in step 2, including channel_id" },
  "supporting_requests": [
    { "purpose": "list the channels the user is a member of", "tool": "slack_list_user_channels", "arguments": { "types": "public_channel,private_channel" } },
    { "purpose": "resolve the current user", "tool": "slack_read_user_profile", "arguments": { "response_format": "concise" } }
  ]
}
```

`arguments.channel_id` is required. Then run, from the repo root (comma-separate several files, with Windows paths):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/download-slack/write-channels.ps1 `
  -ResponseFile <social.json>,<general-p1.json>,<general-p2.json> -RequestFile <social-req.json>,<general-req1.json>,<general-req2.json> `
  [-ThreadFile <thread1.json>,<thread2.json>] -ExportDir dataExports/slack
```

It prints `created`, `updated` or `renamed from …` for each channel-day, with its message count. It warns when:

- a response has more pages: fetch them and rerun with every page;
- a saved day has messages that aren't in the new download: either they were deleted in Slack, or the day was only partly fetched. Check `oldest` / `latest` before trusting the result;
- a thread's parent isn't in any channel response.

If the script stops with "the response format changed", the Slack MCP server changed how it prints messages. Update `ParseMessages` in the script; don't hand-write files.

## 5. Rebuild `index.json`

Never hand-edit `index.json`. Rebuild it from every `metadata.json` in the folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-index.ps1 -ExportDir dataExports/slack
```

Then refresh the dashboard with `scripts/build-dashboard-data.ps1`.

## 6. Check the result

- Every `*.json` in `dataExports/slack/` parses (PowerShell: `Get-Content -Raw -Encoding UTF8 <f> | ConvertFrom-Json`).
- `count` in `index.json` equals the number of `pages` entries and the number of folders, and every `folder` in the index exists.
- No duplicate `id`s.
- Each folder name matches `^\d{4}-\d{2}-\d{2}_[a-z0-9-]+_<last 8 chars of channel ID>$`, and its date is the `date` in `metadata.json`.
- No email addresses in the export (Grep `dataExports/slack` for `@` followed by a domain).
- `git check-ignore -v dataExports/slack/*/*` prints nothing (`.gitignore` ignores `*secret*`).

## 7. Report back

Give a short summary: channels and UTC days downloaded; folders created, updated or renamed; threads included; any warnings; and the folder tree of what changed. Do not commit unless the user asks.
