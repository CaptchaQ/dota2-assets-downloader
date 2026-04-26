# Dota 2 Assets Downloader
# Downloads official Dota 2 assets from Steam CDN, OpenDota API and Valve datafeed
# into dota_official_assets/.
#
# Sections (each can be toggled with a switch):
#   * Heroes  : portraits, icons, full, crops, social JPG, render webm, legacy variants
#   * Spells  : ability icons (modern + legacy size variants)
#   * Items   : item icons (modern + legacy)
#   * Neutrals: neutral creep PNGs (via SteamTracking pak01_dir.txt)
#   * Facets  : facet icon set (~80) used since 7.36
#   * Teams   : pro-team logos
#   * Data    : raw JSON metadata from OpenDota /api/constants and dota2.com/datafeed

[CmdletBinding()]
param(
    [string]$OutputRoot = $(Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'dota_official_assets'),
    [string]$Language   = 'english',

    [switch]$SkipHeroes,
    [switch]$SkipAbilities,
    [switch]$SkipItems,
    [switch]$SkipNeutrals,
    [switch]$SkipFacets,
    [switch]$SkipData,

    # -SkipLegacy is an umbrella that disables hero/abi/item legacy variants
    # in one go. The three granular switches below override per-section.
    [switch]$SkipLegacy,
    [switch]$SkipHeroLegacy,
    [switch]$SkipAbilitiesLegacy,
    [switch]$SkipItemsLegacy,

    # Off by default — these blow up disk usage by ~1 GB / ~150 MB respectively
    [switch]$IncludeVideos,
    [switch]$IncludeTeams,

    # Off by default — only useful for dataminers, ~10 KB extra per ability
    [switch]$IncludeAbilityHires,

    # New CDN-confirmed categories. All are small and on by default,
    # except hi-res team logos (heavier alternative path).
    [switch]$SkipHeroStatIcons,    # 9 PNGs at /heroes/stats/
    [switch]$SkipHeroWideBanners,  # 127 wide banner PNGs at /heroes/wide/
    [switch]$SkipExtraUnits,       # 12 sub-unit / lane creep PNGs at /units/
    [switch]$IncludeTeamsHires     # extra ~70 KB/team variant at /apps/dota2/teamlogos/
)

if ($SkipLegacy) {
    $SkipHeroLegacy       = $true
    $SkipAbilitiesLegacy  = $true
    $SkipItemsLegacy      = $true
}

$ErrorActionPreference = 'Stop'
# Suppress Invoke-WebRequest's per-byte progress bar so it doesn't fight with
# our Write-Progress reporting.
$ProgressPreference    = 'Continue'
# pwsh 7+ — use the compact one-line ANSI progress view; PS 5.1 falls through.
try { $PSStyle.Progress.View = 'Minimal' } catch { }

$Cdn = 'https://cdn.steamstatic.com'

# Output directories ---------------------------------------------------------
$HeroDir         = Join-Path $OutputRoot 'heroes'
$HeroIconDir     = Join-Path $HeroDir   'icons'
$HeroCropDir     = Join-Path $HeroDir   'crops'
$HeroSocialDir   = Join-Path $HeroDir   'social'
$HeroRenderDir   = Join-Path $HeroDir   'renders'
$HeroLegacyDir   = Join-Path $HeroDir   'legacy'
$MiniHeroDir     = Join-Path $HeroLegacyDir 'miniheroes'
$HeroWideDir     = Join-Path $HeroDir   'wide'
$HeroStatsDir    = Join-Path $HeroDir   'stats'

$AbiItemDir      = Join-Path $OutputRoot 'abilities_items'
$AbiItemLegacy   = Join-Path $OutputRoot 'abilities_items_legacy'

$NeutDir         = Join-Path $OutputRoot 'neutrals'
$ExtraUnitsDir   = Join-Path $OutputRoot 'units'
$FacetDir        = Join-Path $OutputRoot 'facets'
$TeamDir         = Join-Path $OutputRoot 'teams'
$TeamHiresDir    = Join-Path $OutputRoot 'teams_hires'
$DataDir         = Join-Path $OutputRoot 'data'

$dirs = @($OutputRoot, $HeroDir, $HeroIconDir, $AbiItemDir, $NeutDir, $DataDir)
if (-not $SkipHeroes) {
    $dirs += $HeroCropDir, $HeroSocialDir
    if ($IncludeVideos)            { $dirs += $HeroRenderDir }
    if (-not $SkipHeroLegacy)      { $dirs += $HeroLegacyDir, $MiniHeroDir }
    if (-not $SkipHeroWideBanners) { $dirs += $HeroWideDir }
    if (-not $SkipHeroStatIcons)   { $dirs += $HeroStatsDir }
}
if (-not ($SkipAbilitiesLegacy -and $SkipItemsLegacy)) { $dirs += $AbiItemLegacy }
if (-not $SkipFacets)      { $dirs += $FacetDir }
if (-not $SkipExtraUnits)  { $dirs += $ExtraUnitsDir }
if ($IncludeTeams)         { $dirs += $TeamDir }
if ($IncludeTeamsHires)    { $dirs += $TeamHiresDir }
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

# Helpers --------------------------------------------------------------------
function Get-JsonObj {
    param([string]$Url)
    $raw = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 120
    return $raw.Content | ConvertFrom-Json
}

function Save-JsonRaw {
    param([string]$Url, [string]$DestPath)
    if (Test-Path $DestPath) { return $true }
    try {
        $raw = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 120
        Set-Content -Path $DestPath -Value $raw.Content -Encoding UTF8
        return $true
    } catch { return $false }
}

function Download-File {
    param([string]$Url, [string]$DestPath)
    if (Test-Path $DestPath) { return $true }
    try {
        # silence Invoke-WebRequest's own progress so our Write-Progress is clean
        $prev = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $DestPath -UseBasicParsing -TimeoutSec 120
        $ProgressPreference = $prev
        return $true
    } catch {
        return $false
    }
}

function Download-Many {
    param(
        [string]$Label,
        [System.Collections.IEnumerable]$Pairs,   # objects with .Url and .Dest
        [int]$Id = 2
    )
    $ok = 0; $skip = 0; $fail = 0; $i = 0; $n = @($Pairs).Count
    if ($n -eq 0) {
        Write-Host ("  {0}: nothing to do" -f $Label) -ForegroundColor DarkGray
        return
    }
    foreach ($p in $Pairs) {
        $i++
        if (Test-Path $p.Dest) { $skip++ }
        elseif (Download-File $p.Url $p.Dest) { $ok++ } else { $fail++ }
        if ($i -eq $n -or ($i % 5 -eq 0)) {
            $pct = [int](($i / $n) * 100)
            Write-Progress -Id $Id -Activity $Label `
                -Status ("{0,5}/{1,-5}  ok={2} skip={3} fail={4}" -f $i, $n, $ok, $skip, $fail) `
                -PercentComplete $pct
        }
    }
    Write-Progress -Id $Id -Activity $Label -Completed
    Write-Host ("  {0}: downloaded={1} skipped={2} failed={3}" -f $Label, $ok, $skip, $fail) -ForegroundColor Green
}

# 1. Heroes ------------------------------------------------------------------
$heroNames = @()  # short names like 'abaddon', 'antimage' — used everywhere later

$needHeroNames = (-not $SkipHeroes) `
    -or (-not $SkipFacets) `
    -or (-not $SkipHeroWideBanners) `
    -or (-not $SkipHeroStatIcons)
if ($needHeroNames) {
    Write-Host 'Fetching hero list from OpenDota...'
    $heroes = Get-JsonObj 'https://api.opendota.com/api/constants/heroes'
    foreach ($p in $heroes.PSObject.Properties) {
        $h = $p.Value
        if ($h.img) {
            $rel  = ($h.img -replace '\?.*$', '')
            $name = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $rel -Leaf))
            $heroNames += $name
        }
    }
    $heroNames = $heroNames | Sort-Object -Unique
    Write-Host ("  found {0} heroes" -f $heroNames.Count)
}

if (-not $SkipHeroes) {
    Write-Host 'Heroes: portraits + icons + crops + social...'
    $modern = New-Object System.Collections.Generic.List[Object]
    foreach ($name in $heroNames) {
        $modern.Add([pscustomobject]@{ Url = "$Cdn/apps/dota2/images/dota_react/heroes/$name.png";       Dest = (Join-Path $HeroDir       "$name.png") })
        $modern.Add([pscustomobject]@{ Url = "$Cdn/apps/dota2/images/dota_react/heroes/icons/$name.png"; Dest = (Join-Path $HeroIconDir   "$name.png") })
        $modern.Add([pscustomobject]@{ Url = "$Cdn/apps/dota2/images/dota_react/heroes/crops/$name.png"; Dest = (Join-Path $HeroCropDir   "$name.png") })
        $modern.Add([pscustomobject]@{ Url = "$Cdn/apps/dota2/images/dota_react/heroes/social/$name.jpg";Dest = (Join-Path $HeroSocialDir "$name.jpg") })
        # Modern dota_react also serves *_full.png — bigger card variant
        $modern.Add([pscustomobject]@{ Url = "$Cdn/apps/dota2/images/dota_react/heroes/${name}_full.png";Dest = (Join-Path $HeroDir       "${name}_full.png") })
    }
    Download-Many -Label 'heroes' -Pairs $modern

    if ($IncludeVideos) {
        Write-Host 'Heroes: render videos (.webm, ~7-8 MB each)...'
        $vids = New-Object System.Collections.Generic.List[Object]
        foreach ($name in $heroNames) {
            $vids.Add([pscustomobject]@{
                Url  = "$Cdn/apps/dota2/videos/dota_react/heroes/renders/$name.webm"
                Dest = (Join-Path $HeroRenderDir "$name.webm")
            })
        }
        Download-Many -Label 'hero-renders' -Pairs $vids
    }

    if (-not $SkipHeroLegacy) {
        Write-Host 'Heroes: legacy CDN variants (full/lg/sb/vert/hphover/icon + miniheroes)...'
        $legacy = New-Object System.Collections.Generic.List[Object]
        foreach ($name in $heroNames) {
            foreach ($suffix in '_full.png','_lg.png','_sb.png','_vert.jpg','_hphover.png','_icon.png') {
                $legacy.Add([pscustomobject]@{
                    Url  = "$Cdn/apps/dota2/images/heroes/$name$suffix"
                    Dest = (Join-Path $HeroLegacyDir "$name$suffix")
                })
            }
            $legacy.Add([pscustomobject]@{
                Url  = "$Cdn/apps/dota2/images/miniheroes/$name.png"
                Dest = (Join-Path $MiniHeroDir "$name.png")
            })
        }
        Download-Many -Label 'heroes-legacy' -Pairs $legacy
    }
}

# 1b. Hero wide banners + stat icons -----------------------------------------
# Independent of $SkipHeroes so they can be picked individually from the launcher.
if ((-not $SkipHeroWideBanners) -and $heroNames.Count -gt 0) {
    if (-not (Test-Path $HeroWideDir)) { New-Item -ItemType Directory -Force -Path $HeroWideDir | Out-Null }
    Write-Host 'Heroes: wide background banners (heroes/wide/*.png)...'
    $wide = New-Object System.Collections.Generic.List[Object]
    foreach ($name in $heroNames) {
        $wide.Add([pscustomobject]@{
            Url  = "$Cdn/apps/dota2/images/dota_react/heroes/wide/$name.png"
            Dest = (Join-Path $HeroWideDir "$name.png")
        })
    }
    Download-Many -Label 'heroes-wide' -Pairs $wide
}

if (-not $SkipHeroStatIcons) {
    if (-not (Test-Path $HeroStatsDir)) { New-Item -ItemType Directory -Force -Path $HeroStatsDir | Out-Null }
    Write-Host 'Heroes: stat icons (armor, damage, attack range, vision, ...)...'
    # The 9 stat icons exposed under /heroes/stats/. Other names (health,
    # mana, strength, agility, intelligence, *_regen) return 404 — Valve
    # only ships these on the React CDN.
    $stats = @(
        'icon_armor','icon_attack_range','icon_attack_time','icon_damage',
        'icon_magic_resist','icon_movement_speed','icon_projectile_speed',
        'icon_turn_rate','icon_vision'
    )
    $sList = New-Object System.Collections.Generic.List[Object]
    foreach ($s in $stats) {
        $sList.Add([pscustomobject]@{
            Url  = "$Cdn/apps/dota2/images/dota_react/heroes/stats/$s.png"
            Dest = (Join-Path $HeroStatsDir "$s.png")
        })
    }
    Download-Many -Label 'hero-stats' -Pairs $sList
}

# 2. Abilities + 3. Items ----------------------------------------------------
$abilityNames = @()
$itemNames    = @()

if (-not $SkipAbilities -or -not $SkipAbilitiesLegacy) {
    Write-Host 'Fetching abilities from OpenDota...'
    $abilities = Get-JsonObj 'https://api.opendota.com/api/constants/abilities'
    $modern = New-Object System.Collections.Generic.List[Object]
    foreach ($p in $abilities.PSObject.Properties) {
        $a = $p.Value
        if (-not $a.img) { continue }
        if ($a.img -notmatch '/dota_react/abilities/') { continue }
        $rel  = ($a.img -replace '\?.*$', '')
        $leaf = Split-Path $rel -Leaf
        $abilityNames += [System.IO.Path]::GetFileNameWithoutExtension($leaf)
        $modern.Add([pscustomobject]@{ Url = $Cdn + $rel; Dest = (Join-Path $AbiItemDir ('ability_' + $leaf)) })
    }
    $abilityNames = $abilityNames | Sort-Object -Unique
    Write-Host ("  abilities: {0}" -f $abilityNames.Count)
    if (-not $SkipAbilities) { Download-Many -Label 'abilities' -Pairs $modern }
}

if (-not $SkipItems -or -not $SkipItemsLegacy) {
    Write-Host 'Fetching items from OpenDota...'
    $items = Get-JsonObj 'https://api.opendota.com/api/constants/items'
    $modern = New-Object System.Collections.Generic.List[Object]
    foreach ($p in $items.PSObject.Properties) {
        $it = $p.Value
        if (-not $it.img) { continue }
        if ($it.img -notmatch '/dota_react/items/') { continue }
        $rel  = ($it.img -replace '\?.*$', '')
        $leaf = Split-Path $rel -Leaf
        $itemNames += [System.IO.Path]::GetFileNameWithoutExtension($leaf)
        $modern.Add([pscustomobject]@{ Url = $Cdn + $rel; Dest = (Join-Path $AbiItemDir ('item_' + $leaf)) })
    }
    $itemNames = $itemNames | Sort-Object -Unique
    Write-Host ("  items: {0}" -f $itemNames.Count)
    if (-not $SkipItems) { Download-Many -Label 'items' -Pairs $modern }
}

if (-not ($SkipAbilitiesLegacy -and $SkipItemsLegacy)) {
    Write-Host 'Abilities + items: legacy CDN variants...'
    $legacy = New-Object System.Collections.Generic.List[Object]

    if (-not $SkipAbilitiesLegacy) {
        foreach ($a in $abilityNames) {
            foreach ($suffix in '_lg.png','_md.png') {
                $legacy.Add([pscustomobject]@{
                    Url  = "$Cdn/apps/dota2/images/abilities/$a$suffix"
                    Dest = (Join-Path $AbiItemLegacy ('ability_' + $a + $suffix))
                })
            }
            if ($IncludeAbilityHires) {
                foreach ($suffix in '_hp1.png','_hp2.png') {
                    $legacy.Add([pscustomobject]@{
                        Url  = "$Cdn/apps/dota2/images/abilities/$a$suffix"
                        Dest = (Join-Path $AbiItemLegacy ('ability_' + $a + $suffix))
                    })
                }
            }
        }
    }

    if (-not $SkipItemsLegacy) {
        foreach ($it in $itemNames) {
            foreach ($suffix in '_lg.png','_eg.png') {
                $legacy.Add([pscustomobject]@{
                    Url  = "$Cdn/apps/dota2/images/items/$it$suffix"
                    Dest = (Join-Path $AbiItemLegacy ('item_' + $it + $suffix))
                })
            }
        }
    }
    Download-Many -Label 'abilities-items-legacy' -Pairs $legacy
}

# 4. Neutrals ----------------------------------------------------------------
if (-not $SkipNeutrals) {
    Write-Host 'Neutrals: extracting unit names from pak01_dir.txt...'
    $pakPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'pak01_dir.txt'
    if (-not (Test-Path $pakPath)) {
        Write-Host '  downloading pak01_dir.txt from SteamTracking...'
        try {
            Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/SteamTracking/GameTracking-Dota2/master/game/dota/pak01_dir.txt' -OutFile $pakPath -UseBasicParsing -TimeoutSec 600
        } catch {
            Write-Host '  could not download pak01_dir.txt — skipping neutrals'
            $pakPath = $null
        }
    }
    if ($pakPath -and (Test-Path $pakPath)) {
        $names = [System.Collections.Generic.HashSet[string]]::new()
        Get-Content $pakPath | ForEach-Object {
            if ($_ -match 'panorama/images/heroes/(npc_dota_neutral_[a-z0-9_]+)_png\.vtex_c') {
                [void]$names.Add($matches[1])
            }
        }
        Write-Host ("  unique neutrals: {0}" -f $names.Count)
        $list = New-Object System.Collections.Generic.List[Object]
        foreach ($n in $names) {
            $file = "$n.png"
            $list.Add([pscustomobject]@{
                Url  = "$Cdn/apps/dota2/images/dota_react/units/$file"
                Dest = (Join-Path $NeutDir $file)
            })
        }
        Download-Many -Label 'neutrals' -Pairs $list
    }
}

# 4b. Extra units / lane creeps / sub-units ---------------------------------
# These are the non-neutral npc_dota_* assets from pak01 that Valve actually
# exposes on /dota_react/units/. Dire-side creeps, courier, roshan, and most
# hero-summons (visage familiar, lone druid bear, brewmaster split, etc.) are
# NOT exposed by the CDN — they only live inside pak01_*.vpk.
if (-not $SkipExtraUnits) {
    Write-Host 'Extra units: lane creeps, siege, sub-units (CDN-confirmed subset)...'
    $extraUnits = @(
        'npc_dota_creep_goodguys_melee',
        'npc_dota_creep_goodguys_ranged',
        'npc_dota_creep_goodguys_flagbearer',
        'npc_dota_goodguys_siege',
        'npc_dota_eidolon',
        'npc_dota_furion_treant',
        'npc_dota_broodmother_spiderling',
        'npc_dota_beastmaster_boar',
        'npc_dota_dark_troll_warlord_skeleton_warrior',
        'npc_dota_warlock_golem',
        'npc_dota_invoker_forged_spirit',
        'npc_dota_unit_undying_zombie'
    )
    $list = New-Object System.Collections.Generic.List[Object]
    foreach ($n in $extraUnits) {
        $list.Add([pscustomobject]@{
            Url  = "$Cdn/apps/dota2/images/dota_react/units/$n.png"
            Dest = (Join-Path $ExtraUnitsDir "$n.png")
        })
    }
    Download-Many -Label 'extra-units' -Pairs $list
}

# 5. Facets ------------------------------------------------------------------
if (-not $SkipFacets) {
    Write-Host 'Facets: fetching icon list via OpenDota /constants/hero_abilities...'
    try {
        $heroAb = Get-JsonObj 'https://api.opendota.com/api/constants/hero_abilities'
    } catch {
        Write-Host '  could not fetch hero_abilities — skipping facets'
        $heroAb = $null
    }
    if ($heroAb) {
        $facetIcons = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($p in $heroAb.PSObject.Properties) {
            $facets = $p.Value.facets
            if ($null -eq $facets) { continue }
            foreach ($f in $facets) {
                if ($f.icon) { [void]$facetIcons.Add([string]$f.icon) }
            }
        }
        Write-Host ("  unique facet icons: {0}" -f $facetIcons.Count)
        $list = New-Object System.Collections.Generic.List[Object]
        foreach ($icon in $facetIcons) {
            $list.Add([pscustomobject]@{
                Url  = "$Cdn/apps/dota2/images/dota_react/icons/facets/$icon.png"
                Dest = (Join-Path $FacetDir "$icon.png")
            })
        }
        Download-Many -Label 'facets' -Pairs $list
    }
}

# 6. Pro-team logos ----------------------------------------------------------
if ($IncludeTeams) {
    Write-Host 'Teams: fetching team list from OpenDota /api/teams...'
    try {
        $teams = Get-JsonObj 'https://api.opendota.com/api/teams'
    } catch {
        Write-Host '  could not fetch /api/teams — skipping team logos'
        $teams = @()
    }
    if ($teams.Count -gt 0) {
        Write-Host ("  teams listed: {0}" -f $teams.Count)
        $list = New-Object System.Collections.Generic.List[Object]
        foreach ($t in $teams) {
            if (-not $t.team_id) { continue }
            $list.Add([pscustomobject]@{
                Url  = "$Cdn/apps/dota2/images/dota_react/teams/$($t.team_id).png"
                Dest = (Join-Path $TeamDir "$($t.team_id).png")
            })
        }
        Download-Many -Label 'teams' -Pairs $list
    }
}

# 6b. Pro-team logos (hi-res, alternative path) -----------------------------
# /apps/dota2/teamlogos/{id}.png returns ~70 KB upstream PNGs vs ~17 KB on
# /dota_react/teams/. Same id space, different rendition. Off by default.
if ($IncludeTeamsHires) {
    Write-Host 'Teams (hi-res): fetching team list from OpenDota /api/teams...'
    try {
        if (-not $teams) { $teams = Get-JsonObj 'https://api.opendota.com/api/teams' }
    } catch {
        Write-Host '  could not fetch /api/teams — skipping hi-res team logos'
        $teams = @()
    }
    if ($teams.Count -gt 0) {
        $list = New-Object System.Collections.Generic.List[Object]
        foreach ($t in $teams) {
            if (-not $t.team_id) { continue }
            $list.Add([pscustomobject]@{
                Url  = "$Cdn/apps/dota2/teamlogos/$($t.team_id).png"
                Dest = (Join-Path $TeamHiresDir "$($t.team_id).png")
            })
        }
        Download-Many -Label 'teams-hires' -Pairs $list
    }
}

# 7. JSON metadata -----------------------------------------------------------
if (-not $SkipData) {
    Write-Host 'Data: dumping JSON metadata (OpenDota constants + dota2.com datafeed)...'

    $openDota = @(
        'heroes','abilities','items',
        'hero_abilities','aghs_desc','neutral_abilities','hero_lore',
        'patchnotes','patch','skillshots','ability_ids','item_ids'
    )
    # Note: leaguelist/cosmeticlist/neutralitemtimedrops respond with empty body
    # unless called from an authenticated dota2.com session, so they're left out.
    $datafeed = @('herolist','abilitylist','itemlist','patchnoteslist')

    $totalData = $openDota.Count + $datafeed.Count
    $okCount = 0; $failCount = 0; $i = 0
    foreach ($name in $openDota) {
        $i++
        Write-Progress -Id 4 -Activity 'JSON metadata' `
            -Status ("opendota/{0}" -f $name) `
            -PercentComplete ([int](($i / $totalData) * 100))
        $url  = "https://api.opendota.com/api/constants/$name"
        $dest = Join-Path $DataDir "opendota_$name.json"
        if (Save-JsonRaw $url $dest) { $okCount++ } else { $failCount++ }
    }
    foreach ($name in $datafeed) {
        $i++
        Write-Progress -Id 4 -Activity 'JSON metadata' `
            -Status ("datafeed/{0}" -f $name) `
            -PercentComplete ([int](($i / $totalData) * 100))
        $url  = "https://www.dota2.com/datafeed/$name`?language=$Language"
        $dest = Join-Path $DataDir "valve_$name.json"
        if (Save-JsonRaw $url $dest) { $okCount++ } else { $failCount++ }
    }
    Write-Progress -Id 4 -Activity 'JSON metadata' -Completed
    Write-Host ("  data: ok={0} fail={1}" -f $okCount, $failCount) -ForegroundColor Green
}

Write-Host ''
Write-Host ("Done. Root: {0}" -f $OutputRoot) -ForegroundColor Green
