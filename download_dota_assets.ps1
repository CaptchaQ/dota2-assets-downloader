# Downloads Dota 2 CDN PNGs into dota_official_assets/{heroes,abilities_items,neutrals}
$ErrorActionPreference = 'Stop'
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutRoot = Join-Path $Base 'dota_official_assets'
$HeroDir = Join-Path $OutRoot 'heroes'
$AbiItemDir = Join-Path $OutRoot 'abilities_items'
$NeutDir = Join-Path $OutRoot 'neutrals'
New-Item -ItemType Directory -Force -Path $HeroDir, $AbiItemDir, $NeutDir | Out-Null

$Cdn = 'https://cdn.steamstatic.com'

function Get-JsonObj {
    param([string]$Url)
    $raw = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 120
    return $raw.Content | ConvertFrom-Json
}

function Download-File {
    param([string]$Url, [string]$DestPath)
    if (Test-Path $DestPath) { return $true }
    try {
        Invoke-WebRequest -Uri $Url -OutFile $DestPath -UseBasicParsing -TimeoutSec 60
        return $true
    } catch {
        return $false
    }
}

Write-Host 'Fetching heroes...'
$heroes = Get-JsonObj 'https://api.opendota.com/api/constants/heroes'

# Создаём папку для иконок героев
$HeroIconDir = Join-Path $HeroDir 'icons'
New-Item -ItemType Directory -Force -Path $HeroIconDir | Out-Null

$heroOk = 0
$heroIconOk = 0
foreach ($p in $heroes.PSObject.Properties) {
    $h = $p.Value

    # — Полноразмерное изображение —
    if ($h.img) {
        $rel = ($h.img -replace '\?.*$', '')
        $name = Split-Path $rel -Leaf
        $url = $Cdn + $rel
        if (Download-File $url (Join-Path $HeroDir $name)) { $heroOk++ }
    }

    # — Иконка героя —
    if ($h.icon) {
        $relIcon = ($h.icon -replace '\?.*$', '')
        $iconName = Split-Path $relIcon -Leaf
        $urlIcon = $Cdn + $relIcon
        if (Download-File $urlIcon (Join-Path $HeroIconDir $iconName)) { $heroIconOk++ }
    }
}

Write-Host "Heroes saved: $heroOk | Hero icons saved: $heroIconOk"

Write-Host 'Fetching abilities + items (abilities_dump from API)...'
$abilities = Get-JsonObj 'https://api.opendota.com/api/constants/abilities'
$abiOk = 0
foreach ($p in $abilities.PSObject.Properties) {
    $a = $p.Value
    if (-not $a.img) { continue }
    if ($a.img -notmatch '/dota_react/abilities/') { continue }
    $rel = ($a.img -replace '\?.*$', '')
    $name = 'ability_' + (Split-Path $rel -Leaf)
    $url = $Cdn + $rel
    if (Download-File $url (Join-Path $AbiItemDir $name)) { $abiOk++ }
}

Write-Host 'Fetching items...'
$items = Get-JsonObj 'https://api.opendota.com/api/constants/items'
$itemOk = 0
foreach ($p in $items.PSObject.Properties) {
    $it = $p.Value
    if (-not $it.img) { continue }
    if ($it.img -notmatch '/dota_react/items/') { continue }
    $rel = ($it.img -replace '\?.*$', '')
    $name = 'item_' + (Split-Path $rel -Leaf)
    $url = $Cdn + $rel
    if (Download-File $url (Join-Path $AbiItemDir $name)) { $itemOk++ }
}

Write-Host "Abilities: $abiOk, Items: $itemOk"

Write-Host 'Extracting neutral unit names from pak01_dir.txt...'
$pakPath = Join-Path $Base 'pak01_dir.txt'
if (-not (Test-Path $pakPath)) {
    Write-Host 'Downloading pak01_dir.txt (SteamTracking) for neutral unit list...'
    try {
        Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/SteamTracking/GameTracking-Dota2/master/game/dota/pak01_dir.txt' -OutFile $pakPath -UseBasicParsing -TimeoutSec 300
    } catch {
        Write-Host 'Could not download pak01_dir.txt — skipping neutrals'
        exit 0
    }
}

$names = [System.Collections.Generic.HashSet[string]]::new()
Get-Content $pakPath | ForEach-Object {
    if ($_ -match 'panorama/images/heroes/(npc_dota_neutral_[a-z0-9_]+)_png\.vtex_c') {
        [void]$names.Add($matches[1])
    }
}

Write-Host "Unique neutrals: $($names.Count)"
$neuOk = 0
foreach ($n in $names) {
    $file = "$n.png"
    $url = "$Cdn/apps/dota2/images/dota_react/units/$file"
    if (Download-File $url (Join-Path $NeutDir $file)) { $neuOk++ }
}
Write-Host "Neutrals saved: $neuOk"
Write-Host "Done. Root: $OutRoot"
