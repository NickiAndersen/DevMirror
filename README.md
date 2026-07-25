# DevMirror

A lightweight macOS menu bar app that keeps a folder backed up by automatically mirroring it to another location. Changes are synced in real time with minimal CPU and disk usage.

![Platform](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.3-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Why?

Cloud sync services (Google Drive, iCloud, Dropbox) cause conflicts when syncing active development folders — build artifacts, locked files, and rapid changes create chaos. DevMirror solves this by:

- **You work directly in `~/Developer`** — no cloud service touches it
- **DevMirror** watches for changes and copies them to a backup folder
- **The backup folder** is synced by Google Drive / iCloud / Dropbox
- Build artifacts (`node_modules`, `build`, `Pods`, etc.) are automatically excluded

## Features

- **Real-time sync** via FSEvents (instant, debounced 2 seconds)
- **Periodic sync** — every 5/15/30 minutes, or manual only
- **Safe delete** — deleted files are moved to `_DevMirrorTrash/` (configurable retention)
- **17 default exclusions** for build/cache folders (fully editable)
- **Atomic file copies** — never sees partial files
- **Corrupted file detection** — skips unreadable files (HFS+ decmpfs failures)
- **Mtime stability check** — won't copy files mid-write from editors
- **First-run onboarding** — pick any source and destination
- **App Nap prevention** — syncs reliably even in background
- **Notifications** — optional alerts on completion or errors
- **Launch at login** — starts automatically

## Installation

### Download (recommended)

Download the latest `DevMirror.app` from [Releases](../../releases) and drag it to `/Applications`.

### Build from source

```bash
git clone https://github.com/NickiAndersen/DevMirror.git
cd DevMirror
make install   # builds, packages, and copies to /Applications
```

**Requirements:** Xcode 16+, macOS 14+

## Usage

1. Launch DevMirror
2. First run: onboarding asks for source and destination folders
3. Choose a source (folder to back up) and a destination (backup location)
4. Click "Start Syncing"

The app lives in your menu bar — a colored dot + drive icon:

- ● Green — watching, everything OK
- ● Blue — syncing in progress
- ● Yellow — paused
- ● Red — error

Click the icon for pause/resume, manual sync, open backup folder, or settings.

### Recommended setup

- **Source:** `~/Developer` (untouched by any cloud service)
- **Destination:** `~/Documents/DevMirror` (synced by Google Drive)
- Leave on "Real-time" for instant sync
- "Include .git folders" = ON by default

## Configuration

| Setting | Default | Description |
|---|---|---|
| Sync frequency | Real-time | Real-time / 5 min / 15 min / 30 min / 1 hour / Manual |
| Include .git | On | Sync full git history |
| Deletion policy | Safe Archive | Keep deleted files 30 days / Exact mirror / Never |
| Exclusions | 17 types | `node_modules`, `build`, `Pods`, `.dart_tool`, etc. |
| Notifications | Errors ON | Configurable alerts |

## How it works

```
~/Developer/               ← You work here. No cloud sync.
    ├── project/
    └── ...
             ↓  DevMirror copies changed files

~/Documents/DevMirror/     ← Google Drive syncs THIS folder
    ├── project/
    └── ...
             ↓  Google Drive uploads to cloud
```

1. FSEvents monitors the source folder for changes
2. Changes are debounced (2s) and checked for mid-write stability (150ms re-check)
3. Non-excluded files are copied atomically (temp file → rename)
4. Deleted source files are archived to `_DevMirrorTrash/` (30-day retention)
5. Periodic full scans catch anything FSEvents missed

## Tech stack

- **Swift 6.3** with strict concurrency
- **SwiftUI** menu bar app (`MenuBarExtra`)
- **FSEvents** for file system monitoring
- **MirrorCore** — modular sync engine with 40 unit tests
- **APFS clone-aware** file copying (falls back gracefully)

## License

MIT — see [LICENSE](LICENSE)
