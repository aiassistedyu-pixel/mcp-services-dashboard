# Local Storage Formats

How data downloaded from each service is stored under `dataExports/`. The dashboard (`webapp/`) and any download skill must read and write exactly this layout.

- [Common pattern](#common-pattern) — rules every service follows
- [Notion](#notion) — implemented
- [Gmail](#gmail) · [Google Drive](#google-drive) · [GitHub](#github) · [Slack](#slack) — planned

---

## Common pattern

Every service uses the same three-part layout: **one folder per item**, holding a **content file** and a **`metadata.json`**, plus one **`index.json`** per service.

```
dataExports/
  <service>/
    index.json                                  ← list of every item downloaded from this service
    <date>_<title-slug>_<id8>/                  ← one folder per item
      content.<ext>                             ← the item's body (Markdown when possible)
      metadata.json                             ← facts about the item and how it was downloaded
```

### Shared rules

| Rule | Detail |
|---|---|
| **Folder name** | `<YYYY-MM-DD>_<title-slug>_<id8>`. The date is the item's creation date (UTC). `id8` is the **last** 8 characters of the service's item ID, with any dashes removed first. (The last characters are used because IDs often share a common prefix.) |
| **Title slug** | Lowercase, ASCII only. Drop apostrophes (`Maria's` → `marias`), turn every other run of non `a-z0-9` characters into one `-`, trim `-` from both ends, and cut at 60 characters (then trim a trailing `-`). Empty result → `untitled`. |
| **Identity** | The service's item ID is the identity, never the folder name. Before writing, look for an existing `metadata.json` whose `id` matches. If one is found, **update that folder** (rename it if the title or date changed) instead of creating a second one. |
| **Content file** | `content.md` for text. Start it with `# <title>`, then the body. Use other extensions only for formats that can't become Markdown (for example `content.pdf`). |
| **Encoding** | UTF-8 without BOM, LF line endings, JSON indented with 2 spaces. |
| **Timestamps** | ISO 8601 UTC strings (`2026-10-13T23:13:45.770Z`). If only the date is known, store `YYYY-MM-DD` and set the matching `*_precision` field to `"day"`. |
| **Unknown values** | Use `null`. Never guess. |
| **Read only** | Downloads never change anything in the source service. |
| **`index.json`** | Rebuild it from the `metadata.json` files after every download run (never hand-edit it), so it lists **every** item folder for that service. Sort by `created_time`, then `title`, comparing strings by code point (ordinal), not by locale. |

### Shared `metadata.json` fields

Every service's `metadata.json` contains these fields. Service sections below add their own fields.

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | integer | Format version, currently `1`. |
| `service` | string | `notion`, `gmail`, `gdrive`, `github` or `slack`. |
| `id` | string | The service's own ID for the item. This is the identity used for updates. |
| `title` | string | Human-readable title (page title, email subject, file name, issue title…). |
| `url` | string \| null | Link to open the item in the service. |
| `created_time` | string | When the item was created (see Timestamps above). |
| `last_edited_time` | string \| null | When the item was last changed in the service. |
| `created_by` | object \| null | `{ "id": string, "name": string }` for the author. |
| `downloaded_at` | string | When this copy was saved locally. |
| `content_file` | string | Name of the content file in the folder, for example `content.md`. |
| `download_request` | object | The MCP call that returned the content: `mcp_server`, `mcp_server_url`, `tool`, `arguments`, plus any as-of time the response reported. |
| `supporting_requests` | array | Other MCP calls whose results went into this file, each `{ "purpose", "tool", "arguments" }`. |

### Shared `index.json` shape

```json
{
  "schema_version": 1,
  "service": "<service>",
  "updated_at": "<ISO timestamp of the last run>",
  "count": 0,
  "pages": [
    { "id": "…", "title": "…", "folder": "…", "created_time": "…", "last_edited_time": "…" }
  ]
}
```

| Field | Type | Meaning |
|---|---|---|
| `schema_version` | integer | `1`. |
| `service` | string | Same value as in each `metadata.json`. |
| `updated_at` | string | When the index was last rewritten. |
| `count` | integer | Number of entries in `pages`. Must equal the number of item folders. |
| `pages` | array | One entry per item folder. Each entry copies `id`, `title`, `created_time`, `last_edited_time` from that item's `metadata.json` and adds `folder` (the folder name, relative to the service directory). |

The array is called `pages` for every service, so the dashboard can read every index with the same code.

---

## Notion

**Status:** implemented. Skill: `.claude/skills/download-notion/SKILL.md`.
**Source:** official Notion MCP server (`https://mcp.notion.com/mcp`). Content comes from `notion-fetch`.

### Layout

```
dataExports/notion/
  index.json
  2026-10-13_project-falcon-kickoff-meeting-notes_1b8a25e7/
    content.md
    metadata.json
  2026-10-13_recipe-marias-black-bean-enchiladas_d985a48a/
    content.md
    metadata.json
  …
```

### Folder name

`<created-date>_<title-slug>_<last-8-chars-of-page-id>`

| Part | Source | Example |
|---|---|---|
| `created-date` | `created_time`, date only | `2026-10-13` |
| `title-slug` | page title, slug rules above (emoji icon is not part of the title) | `recipe-marias-black-bean-enchiladas` |
| `id8` | last 8 hex characters of the page ID, dashes removed | `d985a48a` (from `3f848ed8-7a9c-81eb-91db-d956d985a48a`) |

> **Why the last 8:** pages in the same Notion workspace share their leading ID characters (every page in the test workspace starts with `3f848ed8`). The trailing characters differ between pages. Even so, the folder name is only for people to read: always match pages by the full `id` in `metadata.json`.

### `content.md`

- Line 1 is `# <page title>`, followed by a blank line.
- After that comes the page body: the text inside `<content>…</content>` from the `notion-fetch` response. It is already Markdown, so it is kept unchanged except that blank lines are added between blocks so it renders correctly.
- What is kept: headings (`##`), bulleted and numbered lists, to-dos (`- [ ]` / `- [x]`), bold, italic, inline code, quotes, and Notion's `\$` escapes.
- Child pages (`<page url="…">Title</page>` tags) are **not** copied into the parent's body. Each child page is downloaded on its own.
- Notion-specific tags that have no Markdown equivalent (callouts, columns, databases, mentions) are kept as written by the fetch response, so no information is lost.

### `metadata.json` fields

| Field | Type | Example | Notes |
|---|---|---|---|
| `schema_version` | integer | `1` | |
| `service` | string | `"notion"` | |
| `id` | string (UUID with dashes) | `"3f848ed8-7a9c-81eb-91db-d956d985a48a"` | Notion page ID. Identity key. |
| `title` | string | `"Recipe: Maria's Black Bean Enchiladas"` | From `properties.title`, without the icon. |
| `icon` | string \| null | `"🌯"` | Emoji icon, or `null`. |
| `url` | string | `"https://app.notion.com/p/3f848ed87a9c81eb91dbd956d985a48a"` | Page URL with the `?pvs=…` query removed. |
| `parent` | object \| null | see below | Direct parent page, from `<ancestor-path>`. `null` for top-level pages. |
| `parent.id` | string | `"3f848ed8-7a9c-810b-97e4-f9d94e08e8cd"` | |
| `parent.title` | string | `"Test Data"` | |
| `parent.url` | string | `"https://app.notion.com/p/3f848ed87a9c810b97e4f9d94e08e8cd"` | |
| `created_time` | string | `"2026-10-13"` | See "Where the dates come from" below. |
| `created_time_precision` | string | `"day"` | `"day"` or `"exact"`. |
| `last_edited_time` | string | `"2026-10-13T23:13:45.770Z"` | `page_last_edited_at` from `notion-fetch`. |
| `created_by` | object \| null | `{ "id": "3f8d872b-594c-811e-a0b0-0002261b832d", "name": "AI class" }` | See below. |
| `downloaded_at` | string | `"2026-10-13T23:21:11.134Z"` | |
| `content_file` | string | `"content.md"` | |
| `download_request` | object | see example | The `notion-fetch` call that returned the content. |
| `download_request.mcp_server` | string | `"notion"` | Server name in `.mcp.json`. |
| `download_request.mcp_server_url` | string | `"https://mcp.notion.com/mcp"` | |
| `download_request.tool` | string | `"notion-fetch"` | |
| `download_request.arguments` | object | `{ "id": "3f848ed87a9c81eb91dbd956d985a48a" }` | Exact arguments sent. |
| `download_request.response_as_of` | string | `"2026-10-13T23:13:45.813Z"` | The "as of" time in the fetch response. |
| `supporting_requests` | array | see example | How the page was found, plus the calls used for `created_time` and `created_by`. |

#### Where the dates and author come from

`notion-fetch` returns `page_last_edited_at` but **not** the created time or the creator. They are filled in like this:

- **`created_time`**: run `notion-search` with `filters.created_date_range` set to one day, scoped by `page_url` to the parent. If the page appears in the results, it was created that day. Store the date and set `created_time_precision: "day"`. Do not use the search result's `timestamp` field as the created time: it is the last-edited time cut to the minute.
- **`created_by`**: run `notion-search` with `filters.created_by_user_ids: ["me"]`, and call `notion-get-self` to get the `me` user's `id` and `name`. If a page doesn't show up for `me` and no other creator can be confirmed, use `null`.

If a later version of the Notion MCP returns exact created times, store them and set `created_time_precision: "exact"`.

### Example `metadata.json`

```json
{
  "schema_version": 1,
  "service": "notion",
  "id": "3f848ed8-7a9c-81eb-91db-d956d985a48a",
  "title": "Recipe: Maria's Black Bean Enchiladas",
  "icon": "🌯",
  "url": "https://app.notion.com/p/3f848ed87a9c81eb91dbd956d985a48a",
  "parent": {
    "id": "3f848ed8-7a9c-810b-97e4-f9d94e08e8cd",
    "title": "Test Data",
    "url": "https://app.notion.com/p/3f848ed87a9c810b97e4f9d94e08e8cd"
  },
  "created_time": "2026-10-13",
  "created_time_precision": "day",
  "last_edited_time": "2026-10-13T23:13:45.770Z",
  "created_by": { "id": "3f8d872b-594c-811e-a0b0-0002261b832d", "name": "AI class" },
  "downloaded_at": "2026-10-13T23:21:11.134Z",
  "content_file": "content.md",
  "download_request": {
    "mcp_server": "notion",
    "mcp_server_url": "https://mcp.notion.com/mcp",
    "tool": "notion-fetch",
    "arguments": { "id": "3f848ed87a9c81eb91dbd956d985a48a" },
    "response_as_of": "2026-10-13T23:13:45.813Z"
  },
  "supporting_requests": [
    { "purpose": "list child pages of the parent", "tool": "notion-fetch", "arguments": { "id": "3f848ed8-7a9c-810b-97e4-f9d94e08e8cd" } },
    { "purpose": "confirm created date and creator (fetch does not return them)", "tool": "notion-search", "arguments": { "query": "Project Falcon", "page_url": "3f848ed87a9c810b97e4f9d94e08e8cd", "filters": { "created_by_user_ids": ["me"], "created_date_range": { "start_date": "2026-10-13", "end_date": "2026-10-13" } } } },
    { "purpose": "resolve the 'me' user id and name", "tool": "notion-get-self", "arguments": {} }
  ]
}
```

### `index.json`

Uses the [shared shape](#shared-indexjson-shape) with `"service": "notion"`. Rebuild it with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/download-notion/build-index.ps1 -ExportDir dataExports/notion
```

The script reads every `*/metadata.json`, stops with an error on duplicate `id`s, sorts the entries, and writes `index.json`. It only reads the shared fields, so other services can reuse it by passing their own `-ExportDir`.

---

## Gmail

**Status:** planned. Follow the [common pattern](#common-pattern).

- One folder per **message**. Date = sent date, title = subject, `id8` = Gmail message ID.
- `content.md`: subject as `# <subject>`, then the plain-text body. Attachments go in an `attachments/` subfolder.
- Likely extra `metadata.json` fields: `thread_id`, `from`, `to`, `cc`, `labels`, `attachments` (array of `{ filename, mime_type, size }`).

## Google Drive

**Status:** planned. Follow the [common pattern](#common-pattern).

- One folder per **file**. Date = created date, title = file name, `id8` = Drive file ID.
- Google Docs export to `content.md`. Other files keep their own format (`content.pdf`, `content.xlsx`…).
- Likely extra fields: `mime_type`, `parent_folder` (`{ id, name }`), `owners`, `size`.

## GitHub

**Status:** planned. Follow the [common pattern](#common-pattern).

- One folder per **issue, pull request or file**. Date = created date, title = issue or PR title (file path for files). `id8` = issue/PR node ID (blob SHA for files).
- `content.md`: body, then each comment under a `## Comment by <user> — <time>` heading.
- Likely extra fields: `repo`, `kind` (`issue` \| `pull_request` \| `file`), `number`, `state`, `labels`, `assignees`.

## Slack

**Status:** planned. Follow the [common pattern](#common-pattern).

- One folder per **channel per day** (a single message is too small to be useful on its own). Date = that day, title = `<channel-name>`, `id8` = last 8 characters of the channel ID. Identity for updates = channel ID + date, stored as `id: "<channel_id>:<YYYY-MM-DD>"`.
- `content.md`: one `**<user>** <time>` line per message, with thread replies indented beneath.
- Likely extra fields: `channel` (`{ id, name }`), `message_count`, `participants`.
