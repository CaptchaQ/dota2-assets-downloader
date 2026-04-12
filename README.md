# Dota 2 Assets Downloader

PowerShell script that downloads official Dota 2 assets (heroes, abilities, items, neutral creeps) from Steam CDN and OpenDota API.

---

## 📦 Downloaded Assets

| Category       | Directory                      | Count  |
|----------------|--------------------------------|--------|
| Heroes         | `dota_official_assets/heroes/` | ~124   |
| Hero Icons     | `dota_official_assets/heroes/icons/` | ~124   |
| Abilities      | `dota_official_assets/abilities_items/` | ~1300+ |
| Items          | `dota_official_assets/abilities_items/` | ~200+  |
| Neutral Creeps | `dota_official_assets/neutrals/` | ~40+   |

> Asset counts may change with Dota 2 updates.

---

## 🚀 Quick Start

### Requirements

- **Windows** 10/11
- **PowerShell** 5.1+ or PowerShell 7+

### Download Assets

```powershell
# Run the script
.\download_dota_assets.ps1
```

If you get execution policy errors:

```powershell
powershell -ExecutionPolicy Bypass -File ".\download_dota_assets.ps1"
```

---

## 📂 Project Structure

```
dota2-assets-downloader/
├── download_dota_assets.ps1   # Main download script
├── README.md                   # Documentation
├── .gitignore                  # Git ignore rules
└── dota_official_assets/       # Generated on first run
    ├── heroes/                 # Hero portrait PNGs
    │   └── icons/              # Hero icon PNGs (smaller)
    ├── abilities_items/        # Ability & item icons
    │   ├── ability_*.png
    │   └── item_*.png
    └── neutrals/               # Neutral creep PNGs
```

> **Note:** `dota_official_assets/` is git-ignored. Run the script to generate.

---

## 🔌 Data Sources

| Source | Used For |
|--------|----------|
| [OpenDota API](https://docs.opendota.com/) | Heroes, abilities, items metadata |
| [Steam CDN](https://cdn.steamstatic.com) | PNG images |
| [SteamTracking](https://github.com/SteamTracking/GameTracking-Dota2) | Neutral unit names (`pak01_dir.txt`) |

---

## ⚙️ How It Works

1. **Heroes** — Fetches hero list from OpenDota, downloads portraits + icons from Steam CDN
2. **Abilities** — Fetches ability data, downloads icons with `ability_` prefix
3. **Items** — Fetches item data, downloads icons with `item_` prefix
4. **Neutrals** — Downloads `pak01_dir.txt` from SteamTracking, extracts neutral unit names, downloads images

The script **skips already downloaded files** — safe to re-run for incremental updates.

---

## 📝 License

Script provided as-is. Dota 2 assets are property of **Valve Corporation**.
