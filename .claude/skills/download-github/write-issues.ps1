# Writes GitHub issues from saved GitHub MCP responses into <ExportDir>/<folder>/{content.md,metadata.json}.
# Format: see localStorageFormats.md ("Common pattern" and "GitHub"). Does not touch index.json; run
# scripts/build-index.ps1 afterwards.
#
# -ResponseFile:  one or more files, each the JSON returned by search_issues ({ items: [...] }), list_issues
#                 ({ issues: [...] }) or issue_read method "get" ({ issue: {...} }).
# -RequestFile:   one per response file, same order. JSON describing the call that produced it:
#                 { mcp_server, mcp_server_url, tool, arguments, supporting_requests: [ { purpose, tool, arguments } ] }
#                 arguments.owner and arguments.repo are required (list_issues responses don't name the repo).
# -CommentsFile:  optional, JSON returned by issue_read method "get_comments" ({ comments: [...] }).
# -CommentsIssue: one per comments file, same order: "<owner>/<repo>#<number>".
# If the same issue appears in several responses, the last one wins.
#
# Usage (from the repo root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/download-github/write-issues.ps1 `
#     -ResponseFile <response.json> -RequestFile <request.json> [-CommentsFile <c.json> -CommentsIssue owner/repo#7] [-ExportDir dataExports/github]
param(
    [Parameter(Mandatory = $true)][string[]]$ResponseFile,
    [Parameter(Mandatory = $true)][string[]]$RequestFile,
    [string[]]$CommentsFile = @(),
    [string[]]$CommentsIssue = @(),
    [string]$ExportDir = "dataExports/github"
)

$ErrorActionPreference = "Stop"
# powershell -File passes "a,b" as one string, so split list arguments on commas.
$ResponseFile = @($ResponseFile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$RequestFile = @($RequestFile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$CommentsFile = @($CommentsFile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$CommentsIssue = @($CommentsIssue | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$inv = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object System.Text.UTF8Encoding($false)
if ($ResponseFile.Count -ne $RequestFile.Count) { throw "Pass one -RequestFile per -ResponseFile" }
if ($CommentsFile.Count -ne $CommentsIssue.Count) { throw "Pass one -CommentsIssue per -CommentsFile" }
if (-not (Test-Path -LiteralPath $ExportDir)) { New-Item -ItemType Directory -Path $ExportDir | Out-Null }
$dir = (Resolve-Path $ExportDir).Path

function Esc([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $s.ToCharArray()) {
        switch ($c) {
            '"'  { [void]$sb.Append('\"') }
            '\'  { [void]$sb.Append('\\') }
            "`n" { [void]$sb.Append('\n') }
            "`r" { [void]$sb.Append('\r') }
            "`t" { [void]$sb.Append('\t') }
            default {
                if ([int]$c -lt 0x20) { [void]$sb.AppendFormat('\u{0:x4}', [int]$c) } else { [void]$sb.Append($c) }
            }
        }
    }
    return '"' + $sb.ToString() + '"'
}

# Serializes ordered dictionaries, PSCustomObjects, arrays and scalars as JSON indented with 2 spaces.
function ToJson($v, [string]$ind = "") {
    if ($null -eq $v) { return "null" }
    if ($v -is [bool]) { if ($v) { return "true" } else { return "false" } }
    if ($v -is [string]) { return Esc $v }
    if ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal]) { return ([string]::Format($inv, "{0}", $v)) }
    $next = $ind + "  "
    if ($v -is [System.Collections.IDictionary] -or $v -is [System.Management.Automation.PSCustomObject]) {
        # A List, not @(... ,@(k, v)): with a single key, @() would unroll the one pair into [k, v].
        $pairs = New-Object System.Collections.Generic.List[object]
        if ($v -is [System.Collections.IDictionary]) { foreach ($k in $v.Keys) { $pairs.Add(@($k, $v[$k])) } }
        else { foreach ($p in $v.PSObject.Properties) { $pairs.Add(@($p.Name, $p.Value)) } }
        if ($pairs.Count -eq 0) { return "{}" }
        $items = foreach ($p in $pairs) { "$next$(Esc $p[0]): $(ToJson $p[1] $next)" }
        return "{`n" + ($items -join ",`n") + "`n$ind}"
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $arr = @($v)
        if ($arr.Count -eq 0) { return "[]" }
        $items = foreach ($x in $arr) { "$next$(ToJson $x $next)" }
        return "[`n" + ($items -join ",`n") + "`n$ind]"
    }
    throw "Cannot serialize value of type $($v.GetType().FullName)"
}

# GitHub returns "2026-10-15T02:52:29Z" (ConvertFrom-Json may already turn it into a DateTime); store "2026-10-15T02:52:29.000Z".
function ToUtc($s) {
    if ($null -eq $s -or [string]$s -eq "") { return $null }
    if ($s -is [DateTime]) { return $s.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ", $inv) }
    return [DateTimeOffset]::Parse([string]$s, $inv).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ", $inv)
}

function Slug([string]$s) {
    $s = $s.Normalize([Text.NormalizationForm]::FormD) -replace '[^\x00-\x7F]', ''
    $s = $s.ToLowerInvariant() -replace "['$([char]0x2019)]", '' -replace '[^a-z0-9]+', '-'
    $s = $s.Trim('-')
    if ($s.Length -gt 60) { $s = $s.Substring(0, 60).TrimEnd('-') }
    if ($s -eq "") { return "untitled" }
    return $s
}

function User($u) {
    if ($null -eq $u) { return $null }
    $id = if ($null -ne $u.id) { [string]$u.id } else { $null }
    return [ordered]@{ id = $id; name = [string]$u.login }
}

function Cell($s) { return ([string]$s -replace '\r?\n', ' ' -replace '\|', '\|') }

function Body($s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    return (([string]$s -replace "`r`n", "`n").TrimEnd())
}

function Names($list, [string]$prop) {
    [string[]]$out = @($list | Where-Object { $_ } | ForEach-Object { if ($_ -is [string]) { $_ } else { [string]$_.$prop } })
    return ,$out
}

# Existing folders by issue id, so re-downloads update in place instead of duplicating.
$existing = @{}
foreach ($d in Get-ChildItem -LiteralPath $dir -Directory) {
    $mp = Join-Path $d.FullName "metadata.json"
    if (Test-Path -LiteralPath $mp) {
        $m = [IO.File]::ReadAllText($mp, $utf8) | ConvertFrom-Json
        if ($m.id) { $existing[[string]$m.id] = $d.Name }
    }
}

# Comments by issue id.
$commentsById = @{}
for ($i = 0; $i -lt $CommentsFile.Count; $i++) {
    $resp = [IO.File]::ReadAllText((Resolve-Path $CommentsFile[$i]).Path, $utf8) | ConvertFrom-Json
    $commentsById[$CommentsIssue[$i]] = @($resp.comments | Where-Object { $_ })
}

# Collect issues; later responses override earlier ones.
$issues = [ordered]@{}
for ($i = 0; $i -lt $ResponseFile.Count; $i++) {
    $resp = [IO.File]::ReadAllText((Resolve-Path $ResponseFile[$i]).Path, $utf8) | ConvertFrom-Json
    $req = [IO.File]::ReadAllText((Resolve-Path $RequestFile[$i]).Path, $utf8) | ConvertFrom-Json
    if (-not $req.arguments.owner -or -not $req.arguments.repo) { throw "$($RequestFile[$i]): arguments.owner and arguments.repo are required" }
    $repo = "$($req.arguments.owner)/$($req.arguments.repo)"
    $nodes = if ($null -ne $resp.items) { @($resp.items) } elseif ($null -ne $resp.issues) { @($resp.issues) } elseif ($resp.issue) { @($resp.issue) } else { throw "$($ResponseFile[$i]): no items, issues or issue" }
    if ($resp.pageInfo -and $resp.pageInfo.hasNextPage) { Write-Warning "$($ResponseFile[$i]) has more pages; fetch them with after: endCursor" }
    if ($null -ne $resp.total_count -and $resp.total_count -gt $nodes.Count) { Write-Warning "$($ResponseFile[$i]) returned $($nodes.Count) of $($resp.total_count) results; fetch the next page" }
    foreach ($n in @($nodes | Where-Object { $_ })) {
        if ($n.pull_request) { Write-Warning "$repo#$($n.number) is a pull request; skipped (only issues are supported)"; continue }
        $id = "$repo#$($n.number)"
        $prev = if ($issues.Contains($id)) { $issues[$id].node } else { $null }
        $issues[$id] = @{ node = $n; prev = $prev; req = $req; repo = $repo }
    }
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ", $inv)
foreach ($id in $issues.Keys) {
    $entry = $issues[$id]; $n = $entry.node; $req = $entry.req; $repo = $entry.repo
    if (-not $n.number -or -not $n.title -or -not $n.created_at) { throw "$id is missing number, title or created_at; don't pass a fields filter" }
    # Fill fields that a later, smaller response left out from an earlier one (e.g. issue_read after search_issues).
    function Pick([string]$name) {
        if ($null -ne $n.$name) { return $n.$name }
        if ($null -ne $entry.prev) { return $entry.prev.$name }
        return $null
    }

    $number = [int]$n.number
    $url = if ($n.html_url) { [string]$n.html_url } else { "https://github.com/$repo/issues/$number" }
    $created = ToUtc $n.created_at
    $labels = Names (Pick "labels") "name"
    $assignees = Names (Pick "assignees") "login"
    $state = ([string]$n.state).ToLowerInvariant()
    $stateReason = Pick "state_reason"
    $comments = if ($commentsById.ContainsKey($id)) { ,$commentsById[$id] } else { $null }
    $commentCount = if ($null -ne (Pick "comments")) { [int](Pick "comments") } elseif ($null -ne $comments) { $comments.Count } else { $null }
    if ($null -eq $commentCount) { Write-Warning "$($id): the response has no comment count; comment_count is null" }
    if ($commentCount -gt 0 -and $null -eq $comments) { Write-Warning "$($id): has $commentCount comments; fetch them with issue_read get_comments and pass -CommentsFile" }

    $meta = [ordered]@{
        schema_version = 1
        service = "github"
        id = $id
        title = [string]$n.title
        url = $url
        repo = $repo
        kind = "issue"
        number = $number
        state = $state
        state_reason = if ($stateReason) { [string]$stateReason } else { $null }
        labels = $labels
        assignees = $assignees
        comment_count = $commentCount
        closed_time = ToUtc (Pick "closed_at")
        created_time = $created
        created_time_precision = "exact"
        last_edited_time = ToUtc $n.updated_at
        created_by = User $n.user
        downloaded_at = $now
        content_file = "content.md"
        download_request = [ordered]@{
            mcp_server = [string]$req.mcp_server
            mcp_server_url = [string]$req.mcp_server_url
            tool = [string]$req.tool
            arguments = $req.arguments
        }
        supporting_requests = @($req.supporting_requests | Where-Object { $_ })
    }
    if ($null -ne $comments) {
        $owner, $name = $repo -split '/', 2
        $meta.supporting_requests += [ordered]@{
            purpose = "fetch the issue's comments"; tool = "issue_read"
            arguments = [ordered]@{ method = "get_comments"; owner = $owner; repo = $name; issue_number = $number }
        }
    }

    # content.md
    $dash = [char]0x2014
    $md = New-Object System.Collections.Generic.List[string]
    $md.Add("# $($n.title)"); $md.Add("")
    $md.Add("| Field | Value |"); $md.Add("|---|---|")
    $md.Add("| Issue | [$repo#$number]($url) |")
    $md.Add("| Kind | Issue |")
    $md.Add("| State | $($inv.TextInfo.ToTitleCase($state))$(if ($meta.state_reason) { " ($($meta.state_reason))" }) |")
    $md.Add("| Labels | $(if ($labels.Count) { Cell ($labels -join ', ') } else { 'None' }) |")
    $md.Add("| Assignees | $(if ($assignees.Count) { Cell ($assignees -join ', ') } else { 'Unassigned' }) |")
    $md.Add("| Author | $(if ($meta.created_by) { Cell $meta.created_by.name } else { 'None' }) |")
    $md.Add("| Created | $created |")
    $md.Add("| Updated | $($meta.last_edited_time) |")
    if ($meta.closed_time) { $md.Add("| Closed | $($meta.closed_time) |") }
    $md.Add(""); $md.Add("## Description"); $md.Add("")
    $desc = Body $n.body
    $md.Add($(if ($desc) { $desc } else { "_No description._" }))
    $md.Add(""); $md.Add("## Comments ($(if ($null -ne $commentCount) { $commentCount } else { '?' }))"); $md.Add("")
    if ($null -eq $comments -or $comments.Count -eq 0) {
        $md.Add($(if ($commentCount -gt 0) { "_Comments not downloaded._" } else { "_No comments._" })); $md.Add("")
    }
    foreach ($c in @($comments | Sort-Object { ToUtc $_.created_at })) {
        $who = if ($c.user) { $c.user.login } else { "Unknown" }
        $md.Add("### Comment by $who $dash $(ToUtc $c.created_at)"); $md.Add("")
        $b = Body $c.body
        $md.Add($(if ($b) { $b } else { "_Empty comment._" })); $md.Add("")
    }

    # Folder: <created date>_<repo slug>-<number>_<title slug>_<number>
    $folder = "$($created.Substring(0, 10))_$(Slug ($repo -split '/')[1])-$($number)_$(Slug $n.title)_$number"
    $target = Join-Path $dir $folder
    $action = "created"
    if ($existing.ContainsKey($id)) {
        $old = $existing[$id]
        if ($old -ne $folder) { Move-Item -LiteralPath (Join-Path $dir $old) -Destination $target; $action = "renamed from $old" }
        else { $action = "updated" }
    } else { New-Item -ItemType Directory -Path $target | Out-Null }
    $existing[$id] = $folder

    [IO.File]::WriteAllText((Join-Path $target "content.md"), (($md -join "`n").TrimEnd() + "`n"), $utf8)
    [IO.File]::WriteAllText((Join-Path $target "metadata.json"), (ToJson $meta) + "`n", $utf8)
    Write-Output "$($id): $action -> $folder"
}
