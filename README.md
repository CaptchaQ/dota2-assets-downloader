# Dota 2 Assets Downloader

PowerShell script that downloads official Dota 2 assets (heroes, abilities, items, neutrals, facets, pro-team logos and JSON metadata) from Steam CDN, OpenDota API and Valve datafeed.

---

## 📦 What gets downloaded

By default the script saves everything in the table below, except hero render videos and pro-team logos (off by default — they're large/very numerous).

| Category | Directory | Source | Approx. count | Approx. size |
|---|---|---|---|---|
| Hero portraits (modern) | `dota_official_assets/heroes/{name}.png` | OpenDota → CDN `dota_react/heroes/` | 127 | ~3 MB |
| Hero card variant | `dota_official_assets/heroes/{name}_full.png` | CDN `dota_react/heroes/` | 127 | ~7 MB |
| Hero icons | `dota_official_assets/heroes/icons/` | OpenDota → CDN `dota_react/heroes/icons/` | 127 | ~1 MB |
| Hero crops (head shots) | `dota_official_assets/heroes/crops/` | CDN `dota_react/heroes/crops/` | 127 | ~15 MB |
| Hero social JPGs | `dota_official_assets/heroes/social/` | CDN `dota_react/heroes/social/` | 127 | ~40 MB |
| Hero render videos *(opt-in)* | `dota_official_assets/heroes/renders/` | CDN `dota_react/videos/heroes/renders/` | 127 | ~1 GB |
| Hero legacy variants | `dota_official_assets/heroes/legacy/{name}_full/_lg/_sb/_vert.jpg/_hphover/_icon.png` | CDN `images/heroes/` | 127 × 6 | ~30 MB |
| Mini-hero icons | `dota_official_assets/heroes/legacy/miniheroes/` | CDN `images/miniheroes/` | 127 | ~1 MB |
| Ability icons (modern) | `dota_official_assets/abilities_items/ability_*.png` | OpenDota → CDN `dota_react/abilities/` | ~1300+ | ~15 MB |
| Item icons (modern) | `dota_official_assets/abilities_items/item_*.png` | OpenDota → CDN `dota_react/items/` | ~250+ | ~3 MB |
| Ability legacy variants | `dota_official_assets/abilities_items_legacy/ability_*_lg/_md.png` | CDN `images/abilities/` | ~1300 × 2 | ~25 MB |
| Item legacy variants | `dota_official_assets/abilities_items_legacy/item_*_lg/_eg.png` | CDN `images/items/` | ~250 × 2 | ~5 MB |
| Neutral creep icons | `dota_official_assets/neutrals/` | SteamTracking `pak01_dir.txt` → CDN | ~40+ | <1 MB |
| Facet icons | `dota_official_assets/facets/` | OpenDota `hero_abilities` → CDN `dota_react/icons/facets/` | ~80 | <1 MB |
| Pro-team logos *(opt-in)* | `dota_official_assets/teams/` | OpenDota `/api/teams` → CDN `dota_react/teams/` | thousands | ~150 MB |
| OpenDota constants JSON | `dota_official_assets/data/opendota_*.json` | `https://api.opendota.com/api/constants/...` | 12 files | ~5 MB |
| Valve datafeed JSON | `dota_official_assets/data/valve_*.json` | `https://www.dota2.com/datafeed/...` | 4 files | ~1 MB |

> Counts and sizes change with every Dota 2 patch.

---

## 🚀 Quick Start

### Requirements

- **Windows / Linux / macOS** (anywhere PowerShell runs)
- **PowerShell 5.1+** or **PowerShell 7+**

### Run

```powershell
# Default: download everything except hero render videos and team logos.
.\download_dota_assets.ps1
```

If you get an execution-policy error on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File ".\download_dota_assets.ps1"
```

### Options

```powershell
.\download_dota_assets.ps1 `
  -OutputRoot 'D:\dota_assets' `   # custom destination
  -Language    'russian' `          # for Valve datafeed JSON (english/russian/schinese/...)
  -IncludeVideos `                  # download hero render webm (~1 GB)
  -IncludeTeams `                   # download all pro-team logos (~150 MB)
  -IncludeAbilityHires `            # download legacy *_hp1/_hp2 ability icons
  -SkipLegacy `                     # skip legacy CDN size variants
  -SkipData `                       # skip JSON metadata
  -SkipHeroes -SkipAbilities -SkipItems -SkipNeutrals -SkipFacets
```

All sections can be toggled independently. Re-running the script is safe — files that already exist are skipped, so it works as an incremental updater.

---

## 📂 Output layout

```
dota_official_assets/
├── heroes/
│   ├── {name}.png                  # modern dota_react portrait
│   ├── {name}_full.png             # modern dota_react large card
│   ├── icons/{name}.png            # modern dota_react icon
│   ├── crops/{name}.png            # head crop
│   ├── social/{name}.jpg           # social-share image
│   ├── renders/{name}.webm         # animated render (opt-in)
│   └── legacy/
│       ├── {name}_full.png
│       ├── {name}_lg.png
│       ├── {name}_sb.png
│       ├── {name}_vert.jpg
│       ├── {name}_hphover.png
│       ├── {name}_icon.png
│       └── miniheroes/{name}.png
├── abilities_items/
│   ├── ability_*.png               # modern dota_react ability icons
│   └── item_*.png                  # modern dota_react item icons
├── abilities_items_legacy/
│   ├── ability_*_lg.png            # legacy size variants
│   ├── ability_*_md.png
│   ├── ability_*_hp1.png           # opt-in via -IncludeAbilityHires
│   ├── ability_*_hp2.png           # opt-in via -IncludeAbilityHires
│   ├── item_*_lg.png
│   └── item_*_eg.png
├── neutrals/
│   └── npc_dota_neutral_*.png
├── facets/
│   └── {icon}.png                  # ~80 icons used by hero facets (since 7.36)
├── teams/                          # opt-in via -IncludeTeams
│   └── {team_id}.png
└── data/
    ├── opendota_heroes.json
    ├── opendota_abilities.json
    ├── opendota_items.json
    ├── opendota_hero_abilities.json
    ├── opendota_aghs_desc.json
    ├── opendota_neutral_abilities.json
    ├── opendota_hero_lore.json
    ├── opendota_patchnotes.json
    ├── opendota_patch.json
    ├── opendota_skillshots.json
    ├── opendota_ability_ids.json
    ├── opendota_item_ids.json
    ├── valve_herolist.json
    ├── valve_abilitylist.json
    ├── valve_itemlist.json
    └── valve_patchnoteslist.json
```

> `dota_official_assets/` is git-ignored. Run the script to (re)generate it.

---

## 🔌 Data sources

| Source | Used for |
|---|---|
| [OpenDota constants API](https://docs.opendota.com/) | Hero/ability/item/aghs/lore/patch metadata; lists of names to download images for |
| [Steam CDN](https://cdn.steamstatic.com) | Every PNG / JPG / WEBM asset (modern `dota_react` and legacy paths) |
| [SteamTracking GameTracking-Dota2](https://github.com/SteamTracking/GameTracking-Dota2) | `pak01_dir.txt` — used to extract neutral creep names |
| [Valve datafeed](https://www.dota2.com/datafeed/) | Localized hero/ability/item/patchnote JSON |
| [OpenDota `/api/teams`](https://docs.opendota.com/#tag/teams%2Fpaths%2F~1teams%2Fget) | Pro-team IDs for `teams/{id}.png` (only when `-IncludeTeams` is set) |

---

## ⚙️ How it works

1. **Heroes** — Pulls hero list from OpenDota, derives short names (`abaddon`, `antimage`, …) and fetches every variant from Steam CDN: portrait, full card, icon, crop, social JPG, optional render WEBM and the full legacy size set (`_full`, `_lg`, `_sb`, `_vert`, `_hphover`, `_icon`, plus `miniheroes/`).
2. **Abilities + Items** — Pulls OpenDota `abilities` and `items`, downloads modern dota_react PNGs and (optionally) the legacy `_md`/`_lg`/`_eg` variants.
3. **Neutrals** — Downloads `pak01_dir.txt` from SteamTracking (cached at the script root), extracts neutral unit names matching `npc_dota_neutral_*` and downloads each from `dota_react/units/`.
4. **Facets** — Reads `hero_abilities` from OpenDota, collects every unique `facets[].icon` value and pulls each from `dota_react/icons/facets/`.
5. **Teams** *(opt-in)* — Calls OpenDota `/api/teams`, walks every returned `team_id` and downloads `dota_react/teams/{id}.png`.
6. **Data** — Writes raw JSON copies of OpenDota constants (`heroes`, `abilities`, `items`, `hero_abilities`, `aghs_desc`, `neutral_abilities`, `hero_lore`, `patchnotes`, `patch`, `skillshots`, `ability_ids`, `item_ids`) and Valve datafeed (`herolist`, `abilitylist`, `itemlist`, `patchnoteslist`) into `data/`.

The script **skips files that already exist on disk**, so re-running it is an incremental update.

---

## 🧱 Things that are *not* downloaded

These are not exposed on the public CDN and would require a different toolchain:

- **VPK-only assets** — rank-tier medals (Herald → Immortal), arcana / persona spell icons, HUD skins, emoticons, sprays, chat-wheel, loading screens, hero voice lines, Dota Plus relics, etc. These live inside `pak01_*.vpk` in the Dota 2 install and need a tool like [ValveResourceFormat / Decompiler.exe](https://github.com/ValveResourceFormat/ValveResourceFormat) (or SteamCMD + `vpk`) to extract.
- **Match / player data** — requires Steam Web API key (`api.steampowered.com`) or Stratz GraphQL token.
- **Cosmetic schema (`items_game.txt`)** — also fetched via the Steam Web API (`IEconItems_570/GetSchemaURL`).

---

## 📝 License

Script is provided as-is. All Dota 2 assets are property of **Valve Corporation**.
