# DevMirror

*Code locally. Back up to the cloud. Zero conflicts.*

![Platform](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.3-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## The Problem

You write code in **Cursor** (or Windsurf, VS Code). You back it up with **Google Drive** (or iCloud, Dropbox). But running both on the same folder is a nightmare:

- **Locked files:** Cursor's AI can't read or save a file because Google Drive has locked it for upload.
- **Endless loops:** Cloud sync touches a file, triggering your dev server to hot-reload infinitely.
- **Git corruption:** Sync engines often conflict with `.git/index`, causing your commits to fail.
- **Gigabytes of trash:** `npm install` creates 50,000 files. Your cloud drive chokes trying to upload `node_modules`.

## How it works

DevMirror acts as a bridge between your dev environment and your cloud drive. Keep two folders: one for coding, one for syncing.

```
~/Developer               DevMirror                ~/DevMirror
(no cloud sync)      ->   mirrors changes     ->   (cloud syncs this)
                           in real time
```

Your `.git` folder and uncommitted work are mirrored too. If your Mac crashes or your SSD dies mid-session, your work-in-progress lives on, with full git history intact. DevMirror catches what `git push` misses.

## Install

### Download

Get the latest `DevMirror.app` from [Releases](../../releases).
Drag it to `/Applications`, open it, and you're done.

### Build from source

```bash
git clone https://github.com/NickiAndersen/DevMirror.git
cd DevMirror
make install
```

*Requires Xcode 16+ and macOS 14+*

## Features

- **Zero-Interference Sync:** Real-time sync via FSEvents with a 2-second debounce. Files are never copied while you're actively writing to them.
- **Atomic Copies:** Files are copied to a temporary location and renamed instantly. Your destination folder never sees a half-written file.
- **Smart Exclusions:** Automatically ignores `node_modules`, `build`, `.next`, `Pods`, `.dart_tool`, and 38 other heavy folders.
- **Safe Archive:** Accidental deletion? Deleted files aren't gone forever. They move to a local `_DevMirrorTrash` folder with 30-day retention.
- **Corrupted File Detection:** Skips unreadable files, like unresolved iCloud placeholders.
- **Native & Lightweight:** Built in Swift 6.3 with strict concurrency. Runs asynchronously in your menu bar without blocking your editor or terminal.

## Usage

1. Open DevMirror. The first run walks you through onboarding.
2. Choose your source (`~/Developer`) and destination (`~/DevMirror`).
3. Click "Start Syncing".

DevMirror lives quietly in your menu bar. The colored dot shows your sync status at a glance:

| Icon | Meaning |
|------|---------|
| 🟢 | Watching, everything synced |
| 🔵 | Syncing in progress |
| 🟡 | Paused |
| 🔴 | Error |

Click the icon to pause/resume, trigger a manual sync, open folders, or access settings.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| **Sync frequency** | Real-time | Real-time, 5 min, 15 min, 30 min, 1 hour, or manual |
| **Include .git** | On | Mirrors full git history and uncommitted changes |
| **Deletion policy** | Safe Archive | Keep deleted files 30 days / Exact mirror / Never delete |
| **Exclusions** | 43 patterns | Pre-configured to ignore build artifacts and package folders |
| **Notifications** | Errors only | Configurable alerts |

## License

MIT. See [LICENSE](LICENSE).
