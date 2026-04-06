# Dota 2 Assets Downloader / Загрузчик ассетов Dota 2

PowerShell script that automatically downloads official Dota 2 assets (heroes, abilities, items, neutral creeps) from Steam CDN and OpenDota API.

PowerShell-скрипт для автоматической загрузки официальных ассетов Dota 2 (герои, способности, предметы, нейтральные крипы) из Steam CDN и OpenDota API.

---

## 📁 Downloaded Content / Загружаемый контент

| Category / Категория       | Directory / Папка               | Count / Кол-во   |
|----------------------------|----------------------------------|------------------|
| 🦸 Heroes / Герои          | `dota_official_assets/heroes/`   | ~124             |
| ⚡ Abilities / Способности  | `dota_official_assets/abilities_items/` | ~1300+    |
| 🎒 Items / Предметы        | `dota_official_assets/abilities_items/` | ~200+      |
| 🐉 Neutral Creeps / Нейтралы | `dota_official_assets/neutrals/` | ~40+            |

> **Note / Примечание:** Exact numbers may vary as Dota 2 receives updates. / Точное количество может меняться с обновлениями Dota 2.

---

## 🚀 Getting Started / Начало работы

### Prerequisites / Требования

- **Windows** 10/11
- **PowerShell** 5.1+ or PowerShell 7+
- **Git** (for cloning the repository)

### Installation / Установка

```powershell
# Clone the repository / Клонировать репозиторий
git clone https://github.com/YOUR_USERNAME/dota2-assets-downloader.git
cd dota2-assets-downloader
```

### Usage / Использование

```powershell
# Run the script / Запустить скрипт
.\download_dota_assets.ps1
```

If you encounter execution policy errors, run with bypass:

Если возникает ошибка политик выполнения, запустите так:

```powershell
powershell -ExecutionPolicy Bypass -File ".\download_dota_assets.ps1"
```

Or permanently allow scripts for your user:

Или разрешите выполнение скриптов навсегда для пользователя:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

## 📂 Project Structure / Структура проекта

```
dota2-assets-downloader/
├── download_dota_assets.ps1   # Main script / Главный скрипт
├── README.md                   # This file / Этот файл
├── .gitignore                  # Git ignore rules
└── dota_official_assets/       # Downloaded assets / Загруженные ассеты
    ├── heroes/                 # Hero portrait PNGs / Портреты героев
    ├── abilities_items/        # Ability & item icons / Иконки способностей и предметов
    │   ├── ability_*.png
    │   └── item_*.png
    └── neutrals/               # Neutral creep PNGs / Изображения нейтралов
```

---

## 🔌 Data Sources / Источники данных

| Source / Источник | Used for / Используется для |
|-------------------|------------------------------|
| [OpenDota API](https://docs.opendota.com/) | Heroes, abilities, items metadata |
| [Steam CDN](https://cdn.steamstatic.com) | Actual PNG images / Сами изображения |
| [SteamTracking GameTracking-Dota2](https://github.com/SteamTracking/GameTracking-Dota2) | Neutral unit names (pak01_dir.txt) |

---

## ⚙️ How It Works / Как это работает

1. **Heroes / Герои** — Fetches hero list from OpenDota API, downloads portrait images from Steam CDN
2. **Abilities / Способности** — Fetches ability data, filters and downloads icons with `ability_` prefix
3. **Items / Предметы** — Fetches item data, downloads icons with `item_` prefix
4. **Neutrals / Нейтралы** — Downloads `pak01_dir.txt`, extracts neutral unit names via regex, downloads their images

The script skips already downloaded files (checks if file exists before downloading).

Скрипт пропускает уже загруженные файлы (проверяет наличие перед скачиванием).

---

## 📝 License / Лицензия

This script is provided as-is. Dota 2 assets are property of Valve Corporation.  
Скрипт предоставляется «как есть». Ассеты Dota 2 являются собственностью Valve Corporation.

---

## 🤝 Contributing / Участие

Feel free to open issues or submit PRs!  
Не стесняйтесь открывать issue или отправлять pull-реквесты!
