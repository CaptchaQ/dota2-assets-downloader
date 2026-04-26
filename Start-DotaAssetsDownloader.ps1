# Interactive launcher for download_dota_assets.ps1
#
# Flow:
#   1. CaptchaQ ASCII logo
#   2. Language picker (English / Russian)
#   3. Multi-select checkbox menu of asset categories with name / count / size
#   4. Confirms and runs download_dota_assets.ps1 with the matching switches.
#
# Controls:
#   ↑ / ↓ (or k / j)  navigate
#   Space             toggle current row
#   A                 toggle all
#   D                 reset to defaults
#   Enter             start download
#   Q / Esc           quit

[CmdletBinding()]
param(
    [string]$OutputRoot,
    [string]$Language = '',                 # 'en' or 'ru' — skips the picker if set
    [switch]$NonInteractive                  # for CI / scripting: just runs with defaults
)

$ErrorActionPreference = 'Stop'
$script:ScriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Downloader     = Join-Path $script:ScriptDir 'download_dota_assets.ps1'
if (-not (Test-Path $script:Downloader)) {
    throw "download_dota_assets.ps1 not found next to this launcher."
}

# Make stdout UTF-8 so the Cyrillic strings render correctly on Windows hosts.
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $OutputEncoding           = [System.Text.UTF8Encoding]::new()
} catch { }

# ─── Logo ────────────────────────────────────────────────────────────────────
$Logo = @'
   ____            _       _              ___
  / ___|__ _ _ __ | |_ ___| |__   __ _   / _ \
 | |   / _` | '_ \| __/ __| '_ \ / _` | | | | |
 | |__| (_| | |_) | || (__| | | | (_| | | |_| |
  \____\__,_| .__/ \__\___|_| |_|\__,_|  \__\_\
            |_|         Dota 2 Assets Downloader
'@

# ─── Localization ────────────────────────────────────────────────────────────
$L = @{
    en = @{
        ChooseLang   = 'Choose language / Выберите язык:'
        LangEn       = '1) English'
        LangRu       = '2) Русский'
        LangPrompt   = 'Press 1 or 2: '
        Title        = 'Pick what to download'
        Help1        = '↑/↓ — move    Space — toggle    A — toggle all    D — defaults'
        Help2        = 'Enter — start download    Q / Esc — quit'
        TotalLine    = 'Selected: {0}    Approx. download size: {1}'
        AskLang      = 'Datafeed JSON language (english/russian/schinese/...)'
        AskOutput    = 'Output directory'
        Confirm      = 'Run download with the selected categories? (y/n) '
        Cancelled    = 'Cancelled.'
        Starting     = 'Starting download...'
        Done         = 'Done.'
        ColName      = 'Category'
        ColCount     = 'Count'
        ColSize      = 'Size'
    }
    ru = @{
        ChooseLang   = 'Выберите язык / Choose language:'
        LangEn       = '1) English'
        LangRu       = '2) Русский'
        LangPrompt   = 'Нажмите 1 или 2: '
        Title        = 'Выберите, что скачать'
        Help1        = '↑/↓ — навигация    Space — переключить    A — все    D — сброс'
        Help2        = 'Enter — начать загрузку    Q / Esc — выход'
        TotalLine    = 'Выбрано: {0}    Примерный объём загрузки: {1}'
        AskLang      = 'Язык JSON-датафида (english/russian/schinese/...)'
        AskOutput    = 'Папка для сохранения'
        Confirm      = 'Запустить загрузку выбранных категорий? (y/n) '
        Cancelled    = 'Отменено.'
        Starting     = 'Запуск загрузки...'
        Done         = 'Готово.'
        ColName      = 'Категория'
        ColCount     = 'Кол-во'
        ColSize      = 'Объём'
    }
}

# ─── Categories ──────────────────────────────────────────────────────────────
# Each item maps to one or more switches passed to download_dota_assets.ps1.
# Defaults match the script defaults (heavy ones are off).
$Categories = @(
    [pscustomobject]@{
        Key      = 'HeroesModern'
        NameEn   = 'Heroes — modern (portrait, icon, crop, social, full)'
        NameRu   = 'Герои — modern (портрет, иконка, кроп, social, full)'
        Count    = '~635'
        SizeMb   = 66
        SizeText = '~66 MB'
        Default  = $true
    },
    [pscustomobject]@{
        Key      = 'HeroesLegacy'
        NameEn   = 'Heroes — legacy variants (_lg/_sb/_vert/_hphover/_icon, miniheroes)'
        NameRu   = 'Герои — legacy (_lg/_sb/_vert/_hphover/_icon, мини-герои)'
        Count    = '~890'
        SizeMb   = 31
        SizeText = '~31 MB'
        Default  = $true
    },
    [pscustomobject]@{
        Key      = 'HeroesVideos'
        NameEn   = 'Heroes — render videos (.webm)'
        NameRu   = 'Герои — рендер-видео (.webm)'
        Count    = '127'
        SizeMb   = 1024
        SizeText = '~1 GB'
        Default  = $false
    },
    [pscustomobject]@{
        Key      = 'AbilitiesModern'
        NameEn   = 'Abilities — modern icons'
        NameRu   = 'Способности — modern иконки'
        Count    = '~1300+'
        SizeMb   = 15
        SizeText = '~15 MB'
        Default  = $true
    },
    [pscustomobject]@{
        Key      = 'AbilitiesLegacy'
        NameEn   = 'Abilities — legacy variants (_lg/_md)'
        NameRu   = 'Способности — legacy (_lg/_md)'
        Count    = '~2600'
        SizeMb   = 25
        SizeText = '~25 MB'
        Default  = $true
    },
    [pscustomobject]@{
        Key      = 'AbilitiesHires'
        NameEn   = 'Abilities — hi-res variants (_hp1/_hp2)'
        NameRu   = 'Способности — hi-res (_hp1/_hp2)'
        Count    = '~2600'
        SizeMb   = 30
        SizeText = '~30 MB'
        Default  = $false
    },
    [pscustomobject]@{
        Key      = 'ItemsModern'
        NameEn   = 'Items — modern icons'
        NameRu   = 'Предметы — modern иконки'
        Count    = '~250+'
        SizeMb   = 3
        SizeText = '~3 MB'
        Default  = $true
    },
    [pscustomobject]@{
        Key      = 'ItemsLegacy'
        NameEn   = 'Items — legacy variants (_lg/_eg)'
        NameRu   = 'Предметы — legacy (_lg/_eg)'
        Count    = '~500'
        SizeMb   = 5
        SizeText = '~5 MB'
        Default  = $true
    },
    [pscustomobject]@{
        Key      = 'Neutrals'
        NameEn   = 'Neutral creep icons'
        NameRu   = 'Иконки нейтральных крипов'
        Count    = '~40+'
        SizeMb   = 1
        SizeText = '<1 MB'
        Default  = $true
    },
    [pscustomobject]@{
        Key      = 'Facets'
        NameEn   = 'Facet icons (since patch 7.36)'
        NameRu   = 'Иконки фасетов (с патча 7.36)'
        Count    = '~82'
        SizeMb   = 1
        SizeText = '<1 MB'
        Default  = $true
    },
    [pscustomobject]@{
        Key      = 'Teams'
        NameEn   = 'Pro-team logos'
        NameRu   = 'Логотипы про-команд'
        Count    = 'thousands'
        SizeMb   = 150
        SizeText = '~150 MB'
        Default  = $false
    },
    [pscustomobject]@{
        Key      = 'Data'
        NameEn   = 'JSON metadata (OpenDota constants + Valve datafeed)'
        NameRu   = 'JSON-метаданные (OpenDota constants + Valve datafeed)'
        Count    = '16 файлов'
        SizeMb   = 6
        SizeText = '~6 MB'
        Default  = $true
    }
)

# ─── Helpers ─────────────────────────────────────────────────────────────────
function Show-Logo {
    Clear-Host
    Write-Host ''
    Write-Host $Logo -ForegroundColor Cyan
    Write-Host ''
}

function Choose-Language {
    Show-Logo
    $strings = $L.en
    Write-Host $strings.ChooseLang -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  ' -NoNewline; Write-Host $strings.LangEn
    Write-Host '  ' -NoNewline; Write-Host $strings.LangRu
    Write-Host ''
    while ($true) {
        Write-Host $strings.LangPrompt -NoNewline -ForegroundColor Yellow
        $key = [Console]::ReadKey($true)
        Write-Host $key.KeyChar
        switch ($key.KeyChar) {
            '1' { return 'en' }
            '2' { return 'ru' }
            'q' { exit 0 }
        }
    }
}

function Format-MB {
    param([int]$Mb)
    if ($Mb -ge 1024) { return ('~{0:N1} GB' -f ($Mb / 1024.0)) }
    return ('~{0} MB' -f $Mb)
}

function Render-Menu {
    param(
        [hashtable]$T,
        [int]$Cursor,
        [bool[]]$Selected
    )
    Show-Logo
    Write-Host $T.Title -ForegroundColor Yellow
    Write-Host $T.Help1 -ForegroundColor DarkGray
    Write-Host $T.Help2 -ForegroundColor DarkGray
    Write-Host ''

    # Compute column widths
    $nameW  = 0
    $countW = ($T.ColCount).Length
    $sizeW  = ($T.ColSize).Length
    for ($i = 0; $i -lt $Categories.Count; $i++) {
        $name = if ($T -eq $L.ru) { $Categories[$i].NameRu } else { $Categories[$i].NameEn }
        if ($name.Length  -gt $nameW)  { $nameW  = $name.Length }
        if (([string]$Categories[$i].Count).Length    -gt $countW) { $countW = ([string]$Categories[$i].Count).Length }
        if (([string]$Categories[$i].SizeText).Length -gt $sizeW)  { $sizeW  = ([string]$Categories[$i].SizeText).Length }
    }

    # Header
    $header = ('     {0,-' + $nameW + '}   {1,-' + $countW + '}   {2,-' + $sizeW + '}') -f $T.ColName, $T.ColCount, $T.ColSize
    Write-Host $header -ForegroundColor DarkCyan
    Write-Host ('     ' + ('─' * ($nameW + $countW + $sizeW + 6))) -ForegroundColor DarkCyan

    for ($i = 0; $i -lt $Categories.Count; $i++) {
        $c        = $Categories[$i]
        $name     = if ($T -eq $L.ru) { $c.NameRu } else { $c.NameEn }
        $checkbox = if ($Selected[$i]) { '[x]' } else { '[ ]' }
        $line     = (' {0} {1,-' + $nameW + '}   {2,-' + $countW + '}   {3,-' + $sizeW + '}') -f $checkbox, $name, $c.Count, $c.SizeText

        if ($i -eq $Cursor) {
            Write-Host (' >' + $line) -ForegroundColor Black -BackgroundColor Cyan
        } else {
            $color = if ($Selected[$i]) { 'Green' } else { 'Gray' }
            Write-Host ('  ' + $line) -ForegroundColor $color
        }
    }

    # Footer
    $totalMb = 0
    $cnt     = 0
    for ($i = 0; $i -lt $Categories.Count; $i++) {
        if ($Selected[$i]) {
            $totalMb += [int]$Categories[$i].SizeMb
            $cnt++
        }
    }
    Write-Host ''
    Write-Host ($T.TotalLine -f $cnt, (Format-MB $totalMb)) -ForegroundColor Yellow
}

function Run-Menu {
    param([hashtable]$T)

    $selected = @($Categories | ForEach-Object { [bool]$_.Default })
    $cursor   = 0

    while ($true) {
        Render-Menu -T $T -Cursor $cursor -Selected $selected
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow'   { if ($cursor -gt 0) { $cursor-- } }
            'DownArrow' { if ($cursor -lt $Categories.Count - 1) { $cursor++ } }
            'Spacebar'  { $selected[$cursor] = -not $selected[$cursor] }
            'Enter'     { return $selected }
            'Escape'    { return $null }
            default {
                switch ($key.KeyChar) {
                    'k' { if ($cursor -gt 0) { $cursor-- } }
                    'j' { if ($cursor -lt $Categories.Count - 1) { $cursor++ } }
                    'a' {
                        $allOn = -not ($selected -contains $false)
                        for ($i = 0; $i -lt $selected.Count; $i++) { $selected[$i] = -not $allOn }
                    }
                    'A' {
                        $allOn = -not ($selected -contains $false)
                        for ($i = 0; $i -lt $selected.Count; $i++) { $selected[$i] = -not $allOn }
                    }
                    'd' { for ($i = 0; $i -lt $selected.Count; $i++) { $selected[$i] = [bool]$Categories[$i].Default } }
                    'D' { for ($i = 0; $i -lt $selected.Count; $i++) { $selected[$i] = [bool]$Categories[$i].Default } }
                    'q' { return $null }
                    'Q' { return $null }
                }
            }
        }
    }
}

function Build-Args {
    param([bool[]]$Selected, [string]$DataLanguage, [string]$Out)

    $byKey = @{}
    for ($i = 0; $i -lt $Categories.Count; $i++) {
        $byKey[$Categories[$i].Key] = $Selected[$i]
    }

    $argsList = @()
    if ($Out)            { $argsList += @('-OutputRoot', $Out) }
    if ($DataLanguage)   { $argsList += @('-Language',   $DataLanguage) }

    if (-not $byKey.HeroesModern)    { $argsList += '-SkipHeroes' }
    if (-not $byKey.AbilitiesModern) { $argsList += '-SkipAbilities' }
    if (-not $byKey.ItemsModern)     { $argsList += '-SkipItems' }
    if (-not $byKey.Neutrals)        { $argsList += '-SkipNeutrals' }
    if (-not $byKey.Facets)          { $argsList += '-SkipFacets' }
    if (-not $byKey.Data)            { $argsList += '-SkipData' }

    if (-not $byKey.HeroesLegacy)    { $argsList += '-SkipHeroLegacy' }
    if (-not $byKey.AbilitiesLegacy) { $argsList += '-SkipAbilitiesLegacy' }
    if (-not $byKey.ItemsLegacy)     { $argsList += '-SkipItemsLegacy' }

    if ($byKey.HeroesVideos)         { $argsList += '-IncludeVideos' }
    if ($byKey.Teams)                { $argsList += '-IncludeTeams' }
    if ($byKey.AbilitiesHires)       { $argsList += '-IncludeAbilityHires' }

    return $argsList
}

# ─── Main flow ───────────────────────────────────────────────────────────────
if ($NonInteractive) {
    & $script:Downloader
    return
}

$lang = if ($Language) { $Language.ToLower() } else { Choose-Language }
if ($lang -ne 'en' -and $lang -ne 'ru') { $lang = 'en' }
$T = $L[$lang]

$selected = Run-Menu -T $T
if (-not $selected -or -not ($selected -contains $true)) {
    Show-Logo
    Write-Host $T.Cancelled -ForegroundColor Red
    return
}

# Show summary and confirm
Render-Menu -T $T -Cursor -1 -Selected $selected
Write-Host ''
$dataLang = if ($lang -eq 'ru') { 'russian' } else { 'english' }
$argsList = Build-Args -Selected $selected -DataLanguage $dataLang -Out $OutputRoot

Write-Host ('-> ' + $script:Downloader) -ForegroundColor DarkCyan
Write-Host ('   ' + ($argsList -join ' ')) -ForegroundColor DarkCyan
Write-Host ''
Write-Host $T.Confirm -NoNewline -ForegroundColor Yellow
$answer = [Console]::ReadKey($true).KeyChar
Write-Host $answer
if ($answer -ne 'y' -and $answer -ne 'Y' -and $answer -ne 'д' -and $answer -ne 'Д') {
    Write-Host $T.Cancelled -ForegroundColor Red
    return
}

Write-Host ''
Write-Host $T.Starting -ForegroundColor Green
Write-Host ''
& $script:Downloader @argsList

Write-Host ''
Write-Host $T.Done -ForegroundColor Green
