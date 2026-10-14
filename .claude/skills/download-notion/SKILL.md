---
name: download-notion
description: Download Notion pages through the Notion MCP server (read only) and save them under dataExports/notion/ in the project's local format (content.md + metadata.json per page, plus index.json). Use for requests like "download the pages under Test Data", "download Notion pages that mention Joe Smith", "refresh my Notion export", or "save this Notion page locally".
---

# Download Notion pages

Save Notion pages to `dataExports/notion/` in the format defined in **`localStorageFormats.md`** (repo root, sections "Common pattern" and "Notion"). Read that file first; it is the source of truth for folder names, files and every field. This skill covers *how* to produce that format.

## Hard rules

- **Read only.** Use only `notion-search`, `notion-fetch` and `notion-get-self`. Never call any Notion tool that creates, updates, moves, comments on or deletes anything.
- **No duplicates.** A page is identified by its full Notion page `id`, never by folder name. If a page was already downloaded, update its existing folder.
- **Never guess metadata.** If a value can't be confirmed, write `null` (or `created_time_precision: "day"`, see step 4).
- **No scripting runtime needed.** Write files with the Write tool, or Bash heredocs for repetitive JSON. Validate the JSON afterwards (step 7).

## 1. Work out which pages to download

Turn the request into a list of page IDs.

| Request | How to find the pages |
|---|---|
| "pages under X" / "children of X" | `notion-search` for X to get its ID, then `notion-fetch` X. Its child pages are the `<page url="…">Title</page>` tags in `<content>`. Only include deeper descendants if the user asks for them. |
| "pages that mention <person or term>" (e.g. "Joe Smith") | `notion-search` with `query: "<term>"`, `page_size: 25` (narrow with `page_url` if the user names a parent). Keyword search is loose, so **fetch each candidate and keep it only if the term really appears** in the title or body (case-insensitive). For a person, also try the `query_type: "user"` lookup. If it finds the user, a separate `notion-search` with `filters.created_by_user_ids: [<id>]` finds pages they *created*. Ask whether the user means "mentions" or "created by" only when the difference changes the result. |
| A specific page URL or title | Use it directly, or `notion-search` for the title. |
| "refresh" / "update my export" | Every `id` in `dataExports/notion/index.json`. |

Skip results that are not pages (databases, data sources) unless asked, and say so. If more than ~25 pages match, show the count and confirm before downloading.

## 2. Fetch each page

Call `notion-fetch` with `id: <page id without dashes>`. Fetch independent pages in parallel. From the response, record:

- `title`: `<properties>` → `"title"` (not the top-level `title`, which has the icon in front)
- `icon`: `iconMetadata.emoji`, or `null`
- `url`: drop the `?pvs=…` query
- `parent`: the last `<parent-page url=… title=…>` in `<ancestor-path>` (`null` if there is none). The parent ID is the 32 hex characters at the end of its URL, re-dashed 8-4-4-4-12.
- `last_edited_time`: `page_last_edited_at`
- `response_as_of`: the "as of …" time in the response text
- the body: everything between `<content>` and `</content>`

If the response reports `truncated`, `unknown_block_count` > 0, or `unknown_block_ids`, say so in the final summary. Those parts of the page are missing.

## 3. Build `content.md`

```
# <title>

<body>
```

- Keep the fetched Markdown as it is: headings, lists, to-dos (`- [ ]` / `- [x]`), bold/italic, code, quotes, `\$` escapes.
- Put a blank line between blocks (before and after headings, between paragraphs, around lists and quotes) so standard Markdown renders it correctly. Change nothing else in the text.
- Remove child-page tags (`<page url="…">…</page>`); child pages get their own folders.

## 4. Fill in created date and author

`notion-fetch` does not return these. Look them up once per run, not once per page:

1. `notion-get-self` → `user.id`, `user.name` (trim spaces). This is "me".
2. `notion-search` with a query that matches the pages (scope it with `page_url` to the parent when there is one) and
   `filters: { "created_by_user_ids": ["me"], "created_date_range": { "start_date": D, "end_date": D } }`.
   Start with today's date as D. Pages that show up were created on day D by me.
   For pages that don't show up, try earlier days, or widen the range and then split it in half until each page is pinned to one day.
3. Write `created_time: "YYYY-MM-DD"`, `created_time_precision: "day"`, `created_by: { id, name }`.
   If a page never shows up under `["me"]`, set `created_by: null` and still find the date with a date-only search.
   **Do not** use the search result's `timestamp` field as the created time; it is the last-edited time cut to the minute.

List these calls in each page's `supporting_requests` (along with the step 1 call that found the page).

## 5. Write the files (with the update check)

For each page:

1. **Folder name:** `<created_time date>_<slug(title)>_<LAST 8 chars of id with dashes removed>`. Example: id `3f848ed8-7a9c-81eb-91db-d956d985a48a` → suffix `d985a48a`. (The first 8 characters are the same across the workspace, so don't use them.) Slug rules are in `localStorageFormats.md` (lowercase ASCII, drop apostrophes, other non-alphanumeric runs → `-`, max 60 chars).
2. **Check for an existing copy:** search `dataExports/notion/*/metadata.json` for `"id": "<full id>"` (Grep tool).
   - **Found, same folder name:** overwrite `content.md` and `metadata.json` in place.
   - **Found, different folder name** (title or date changed): rename the folder with `git mv` if it is tracked, otherwise a plain move. Then overwrite both files.
   - **Not found:** create the folder.
3. Write `content.md`, then `metadata.json` with **every** field from the Notion table in `localStorageFormats.md`, in that order. `downloaded_at` is the current UTC time (one value per run is fine). `download_request` = `{ mcp_server: "notion", mcp_server_url: "https://mcp.notion.com/mcp", tool: "notion-fetch", arguments: { id }, response_as_of }`.

## 6. Rewrite `index.json`

Never hand-edit `index.json` (no sed, no Edit tool). Rebuild it from **all** `metadata.json` files in `dataExports/notion/`, not only the ones from this run, by running the shared script from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-index.ps1 -ExportDir dataExports/notion
```

It writes the shape in `localStorageFormats.md`, sorts by `created_time` then `title` (ordinal), sets `count` and `updated_at`, and stops with an error if two folders share an `id`. If it reports a duplicate, merge the two folders (keep the newer `downloaded_at`) and run it again.

## 7. Check the result

- Every `*.json` parses (PowerShell: `Get-Content -Raw -Encoding UTF8 <f> | ConvertFrom-Json`).
- `count` equals the number of `pages` entries and the number of page folders, and every `folder` in the index exists.
- No duplicate `id`s in the index.
- Each folder's suffix equals the last 8 characters of its `metadata.json` `id` (dashes removed).

## 8. Report back

Give a short summary: pages created / updated / renamed / skipped (and why), anything truncated, and the folder tree of what changed. Do not commit unless the user asks.
