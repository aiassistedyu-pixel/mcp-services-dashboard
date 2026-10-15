# Writes Slack channel history from saved Slack MCP responses into <ExportDir>/<folder>/{content.md,metadata.json},
# one folder per channel per UTC day. Format: see localStorageFormats.md ("Common pattern" and "Slack").
# Does not touch index.json; run scripts/build-index.ps1 afterwards.
#
# -ResponseFile: one or more files, each the JSON returned by slack_read_channel ({ messages: "<text>", pagination_info }).
#                Pass every page of a channel; messages are merged by ts before they are grouped into days.
# -RequestFile:  one per response file, same order. JSON describing the call that produced it:
#                { mcp_server, mcp_server_url, tool, arguments, supporting_requests: [ { purpose, tool, arguments } ] }
#                arguments.channel_id is required.
# -ThreadFile:   optional, JSON returned by slack_read_thread for a thread parent in one of the channel responses.
#                Replies are stored under their parent, in the parent's day.
#
# Usage (from the repo root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .claude/skills/download-slack/write-channels.ps1 `
#     -ResponseFile <response.json> -RequestFile <request.json> [-ThreadFile <thread.json>] [-ExportDir dataExports/slack]
param(
    [Parameter(Mandatory = $true)][string[]]$ResponseFile,
    [Parameter(Mandatory = $true)][string[]]$RequestFile,
    [string[]]$ThreadFile = @(),
    [string]$ExportDir = "dataExports/slack"
)

$ErrorActionPreference = "Stop"
# powershell -File passes "a,b" as one string, so split list arguments on commas.
$ResponseFile = @($ResponseFile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$RequestFile = @($RequestFile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$ThreadFile = @($ThreadFile | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$inv = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object System.Text.UTF8Encoding($false)
if ($ResponseFile.Count -ne $RequestFile.Count) { throw "Pass one -RequestFile per -ResponseFile" }
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

function Slug([string]$s) {
    $s = $s.Normalize([Text.NormalizationForm]::FormD) -replace '[^\x00-\x7F]', ''
    $s = $s.ToLowerInvariant() -replace "['$([char]0x2019)]", '' -replace '[^a-z0-9]+', '-'
    $s = $s.Trim('-')
    if ($s.Length -gt 60) { $s = $s.Substring(0, 60).TrimEnd('-') }
    if ($s -eq "") { return "untitled" }
    return $s
}

# Slack ts "1792033294.742989" (seconds since the epoch) -> "2026-10-15T03:01:34.742Z".
function TsToUtc([string]$ts) {
    $sec, $frac = $ts -split '\.', 2
    $ms = if ($frac) { [int]($frac.PadRight(3, '0').Substring(0, 3)) } else { 0 }
    return [DateTimeOffset]::FromUnixTimeSeconds([long]$sec).AddMilliseconds($ms).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ", $inv)
}

# Parses the text in a slack_read_channel / slack_read_thread response. Each message looks like:
#   === Message from <name> <<email>> (<user id>) at <local time> ===
#   Message TS: <ts>
#   <text, one or more lines>
# Email addresses are not kept.
function ParseMessages([string]$text) {
    $out = New-Object System.Collections.Generic.List[object]
    $cur = $null
    foreach ($line in (($text -replace "`r`n", "`n") -split "`n")) {
        $h = [regex]::Match($line, '^=== Message from (.*?)(?: <[^<>]*>)? \(([A-Z0-9]+)\) at .* ===\s*$')
        if ($h.Success) {
            if ($cur) { $out.Add($cur) }
            $cur = [pscustomobject]@{
                name = $h.Groups[1].Value; user_id = $h.Groups[2].Value; ts = $null; text = $null; time = $null
                lines = New-Object System.Collections.Generic.List[string]; replies = New-Object System.Collections.Generic.List[object]
            }
            continue
        }
        if (-not $cur) { continue }
        $t = [regex]::Match($line, '^Message TS: (\d+\.\d+)\s*$')
        if (-not $cur.ts -and $t.Success) { $cur.ts = $t.Groups[1].Value; continue }
        $cur.lines.Add($line)
    }
    if ($cur) { $out.Add($cur) }
    foreach ($m in $out) {
        if (-not $m.ts) { throw "Message from $($m.name) has no 'Message TS' line; the response format changed" }
        $m.text = ($m.lines -join "`n").Trim("`n").TrimEnd()
        $m.time = TsToUtc $m.ts
    }
    return ,$out
}

# Existing folders by id, so re-downloads update in place instead of duplicating.
$existing = @{}; $existingTs = @{}
foreach ($d in Get-ChildItem -LiteralPath $dir -Directory) {
    $mp = Join-Path $d.FullName "metadata.json"
    if (Test-Path -LiteralPath $mp) {
        $m = [IO.File]::ReadAllText($mp, $utf8) | ConvertFrom-Json
        if ($m.id) { $existing[[string]$m.id] = $d.Name; $existingTs[[string]$m.id] = @($m.messages | ForEach-Object { [string]$_.ts }) }
    }
}

# Collect messages per channel, merged by ts across pages.
$channels = [ordered]@{}
for ($i = 0; $i -lt $ResponseFile.Count; $i++) {
    $resp = [IO.File]::ReadAllText((Resolve-Path $ResponseFile[$i]).Path, $utf8) | ConvertFrom-Json
    $req = [IO.File]::ReadAllText((Resolve-Path $RequestFile[$i]).Path, $utf8) | ConvertFrom-Json
    $chId = [string]$req.arguments.channel_id
    if (-not $chId) { throw "$($RequestFile[$i]): arguments.channel_id is required" }
    if ([string]$resp.pagination_info -match 'There are more messages') { Write-Warning "$($ResponseFile[$i]) has more pages; fetch them with cursor and pass every page" }
    $hdr = [regex]::Match([string]$resp.messages, '(?m)^Channel: #(\S+) \(([A-Z0-9]+)\)')
    if (-not $hdr.Success) { throw "$($ResponseFile[$i]): no 'Channel: #name (ID)' line" }
    if ($hdr.Groups[2].Value -ne $chId) { throw "$($ResponseFile[$i]) is channel $($hdr.Groups[2].Value) but the request says $chId" }
    if (-not $channels.Contains($chId)) { $channels[$chId] = @{ name = $hdr.Groups[1].Value; req = $req; msgs = @{} } }
    $channels[$chId].req = $req
    foreach ($m in (ParseMessages ([string]$resp.messages))) { $channels[$chId].msgs[$m.ts] = $m }
}

# Attach thread replies to their parent (the oldest message in the thread response).
foreach ($tf in $ThreadFile) {
    $resp = [IO.File]::ReadAllText((Resolve-Path $tf).Path, $utf8) | ConvertFrom-Json
    $parsed = ParseMessages ([string]$resp.messages)
    $thread = @($parsed | Sort-Object { [decimal]::Parse($_.ts, $inv) })
    if ($thread.Count -eq 0) { Write-Warning "$tf has no messages"; continue }
    $parentTs = $thread[0].ts; $parent = $null
    foreach ($ch in $channels.Values) { if ($ch.msgs.ContainsKey($parentTs)) { $parent = $ch.msgs[$parentTs] } }
    if (-not $parent) { Write-Warning "$($tf): parent message $parentTs is not in any channel response; skipped"; continue }
    $parent.replies.Clear()
    foreach ($r in ($thread | Select-Object -Skip 1)) { $parent.replies.Add($r) }
    # A reply that was also sent to the channel appears in both; keep it only in the thread.
    foreach ($ch in $channels.Values) { foreach ($r in $parent.replies) { if ($ch.msgs.ContainsKey($r.ts)) { $ch.msgs.Remove($r.ts) } } }
}

function UserObj($m) { return [ordered]@{ id = $m.user_id; name = $m.name } }

function Render($m, [string]$indent) {
    $lines = @("**$($m.name)** $($m.time)") + @(if ($m.text) { $m.text -split "`n" } else { "_No text._" })
    return (($lines | ForEach-Object { if ($_ -eq "") { "" } else { "$indent$_" } }) -join "`n")
}

$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ", $inv)
foreach ($chId in $channels.Keys) {
    $ch = $channels[$chId]; $req = $ch.req
    $days = [ordered]@{}
    foreach ($m in ($ch.msgs.Values | Sort-Object { [decimal]::Parse($_.ts, $inv) })) {
        $day = $m.time.Substring(0, 10)
        if (-not $days.Contains($day)) { $days[$day] = New-Object System.Collections.Generic.List[object] }
        $days[$day].Add($m)
    }
    foreach ($day in $days.Keys) {
        $msgs = $days[$day]
        $id = "$($chId):$day"
        if ($existingTs.ContainsKey($id)) {
            $newTs = @($msgs | ForEach-Object { $_.ts })
            $missing = @($existingTs[$id] | Where-Object { $newTs -notcontains $_ })
            if ($missing.Count) { Write-Warning "$($id): $($missing.Count) previously saved message(s) are not in this download (deleted, or the day was only partly fetched)" }
        }

        $participants = New-Object System.Collections.Generic.List[object]; $seen = @{}
        # Every message and reply that day, in order (List.AddRange avoids a PowerShell 5.1 bug with @($hashtable)).
        $all = New-Object System.Collections.Generic.List[object]
        foreach ($m in $msgs) { $all.Add($m); $all.AddRange($m.replies) }
        foreach ($x in $all) { if (-not $seen.ContainsKey($x.user_id)) { $seen[$x.user_id] = 1; $participants.Add((UserObj $x)) } }
        $lastTime = ($all | ForEach-Object { $_.time } | Sort-Object | Select-Object -Last 1)

        $meta = [ordered]@{
            schema_version = 1
            service = "slack"
            id = $id
            title = $ch.name
            url = $null
            channel = [ordered]@{ id = $chId; name = $ch.name }
            date = $day
            message_count = $msgs.Count
            participants = $participants.ToArray()
            messages = @($msgs | ForEach-Object { [ordered]@{ ts = $_.ts; user = (UserObj $_); time = $_.time; thread_reply_count = $_.replies.Count } })
            created_time = $msgs[0].time
            created_time_precision = "exact"
            last_edited_time = $lastTime
            created_by = $null
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

        $parts = New-Object System.Collections.Generic.List[string]
        $parts.Add("# $($ch.name)")
        $parts.Add("Channel: #$($ch.name) ($chId) $([char]0x00B7) $day (UTC) $([char]0x00B7) $($msgs.Count) messages")
        foreach ($m in $msgs) {
            $parts.Add((Render $m ""))
            foreach ($r in $m.replies) { $parts.Add((Render $r "  ")) }
        }

        # Folder: <UTC day>_<channel name slug>_<last 8 chars of channel id>
        $idPart = $chId -replace '-', ''
        if ($idPart.Length -gt 8) { $idPart = $idPart.Substring($idPart.Length - 8) }
        $folder = "$($day)_$(Slug $ch.name)_$idPart"
        $target = Join-Path $dir $folder
        $action = "created"
        if ($existing.ContainsKey($id)) {
            $old = $existing[$id]
            if ($old -ne $folder) { Move-Item -LiteralPath (Join-Path $dir $old) -Destination $target; $action = "renamed from $old" }
            else { $action = "updated" }
        } else { New-Item -ItemType Directory -Path $target | Out-Null }
        $existing[$id] = $folder

        [IO.File]::WriteAllText((Join-Path $target "content.md"), ($parts -join "`n`n") + "`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $target "metadata.json"), (ToJson $meta) + "`n", $utf8)
        Write-Output "#$($ch.name) $($day): $action -> $folder ($($msgs.Count) messages)"
    }
}
