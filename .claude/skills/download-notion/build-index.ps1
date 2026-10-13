# Rebuilds <ExportDir>/index.json from every <ExportDir>/*/metadata.json.
# Format: see localStorageFormats.md ("Shared index.json shape").
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File build-index.ps1 [-ExportDir dataExports/notion]
param([string]$ExportDir = "dataExports/notion")

$ErrorActionPreference = "Stop"
$dir = (Resolve-Path $ExportDir).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Esc([string]$s) {
    if ($null -eq $s) { return "null" }
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

$entries = New-Object System.Collections.Generic.List[object]
$seen = @{}
foreach ($d in Get-ChildItem -LiteralPath $dir -Directory) {
    $metaPath = Join-Path $d.FullName "metadata.json"
    if (-not (Test-Path -LiteralPath $metaPath)) { Write-Warning "No metadata.json in $($d.Name); skipped"; continue }
    $m = [System.IO.File]::ReadAllText($metaPath, $utf8) | ConvertFrom-Json
    if (-not $m.id) { throw "$($d.Name)/metadata.json has no id" }
    if ($seen.ContainsKey($m.id)) { throw "Duplicate id $($m.id) in $($d.Name) and $($seen[$m.id])" }
    $seen[$m.id] = $d.Name
    $entries.Add([pscustomobject]@{
        id = [string]$m.id; title = [string]$m.title; folder = $d.Name
        created_time = [string]$m.created_time; last_edited_time = $m.last_edited_time
    })
}

# Sort by created_time, then title, ordinal (code point) order so the result is the same on every machine.
$entries.Sort([System.Comparison[object]] {
    param($a, $b)
    $r = [string]::CompareOrdinal($a.created_time, $b.created_time)
    if ($r -ne 0) { return $r }
    return [string]::CompareOrdinal($a.title, $b.title)
})

$service = Split-Path $dir -Leaf
$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('{')
$lines.Add('  "schema_version": 1,')
$lines.Add("  ""service"": $(Esc $service),")
$lines.Add("  ""updated_at"": $(Esc $now),")
$lines.Add("  ""count"": $($entries.Count),")
$lines.Add('  "pages": [')
for ($i = 0; $i -lt $entries.Count; $i++) {
    $e = $entries[$i]
    $sep = if ($i -lt $entries.Count - 1) { "," } else { "" }
    $lines.Add("    {""id"": $(Esc $e.id), ""title"": $(Esc $e.title), ""folder"": $(Esc $e.folder), ""created_time"": $(Esc $e.created_time), ""last_edited_time"": $(Esc $e.last_edited_time)}$sep")
}
$lines.Add('  ]')
$lines.Add('}')

$out = Join-Path $dir "index.json"
[System.IO.File]::WriteAllText($out, ($lines -join "`n") + "`n", $utf8)
Write-Output "Wrote $out with $($entries.Count) entries"
