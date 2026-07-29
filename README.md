# DevMirror

Back up `~/Developer` in real time. Code without cloud sync conflicts.

![Platform](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.3-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## The problem

You use **Cursor** (or Windsurf, Copilot) to write code. You use **Google Drive**
(or iCloud, Dropbox) to back it up. But you can't use both on the same folder.

Here's what happens when cloud sync touches your code while you work:

- Cursor's AI can't read a file because Google Drive locked it for upload
- `npm install` writes 50,000 files — cloud sync chokes and never catches up
- Git commit fails because cloud sync conflicts with `.git/index`
- Dev server hot-reloads in an endless loop because sync touched a watched file
- `node_modules/`, `.next/`, and `build/` get uploaded anyway — gigabytes of trash

## The solution

Keep two folders. Code in one. Back up the other. DevMirror connects them.

```
~/Developer/               ← You code here. No cloud sync. Ever.
    ├── project/
    │   ├── .git/               Full git history
    │   ├── src/                Cursor, npm, git — all run freely
    │   └── ...
    └── ...
              ↓  DevMirror copies changes (within seconds, never mid-write)

~/DevMirror/               ← Cloud sync touches only this folder
    ├── project/
    │   ├── .git/               Git history mirrored in real time
    │   ├── src/                Stable copies. No conflicts.
    │   └── ...
    └── ...
              ↓  Google Drive / iCloud / Dropbox uploads to the cloud
```

## An extra safety net for git

DevMirror mirrors **everything** — including your `.git` folder and every
uncommitted change. This means:

- Unsaved work is backed up **before** you commit or push
- If your disk dies or `~/Developer` gets corrupted, the mirrored copy
  of your repo lives on — with full git history intact
- Unlike `git push`, which only saves committed snapshots, DevMirror
  catches work-in-progress in real time

## Features

- **Real-time sync** via FSEvents — changes mirrored within seconds
- **2-second debounce** — never copies a file mid-write
- **Async I/O** — syncs without blocking your editor or terminal
- **Atomic copies** — temp file + rename, destination never sees a partial file
- **Empty directories** — mirrored too, so nothing is missed
- **Safe delete** — deleted files move to `_DevMirrorTrash/` (30-day retention)
- **Corrupted file detection** — skips unreadable files (iCloud placeholders, etc.)
- **17 default exclusions** — `node_modules`, `build`, `.next`, `Pods`, and more
- **Menu bar icon** — colored dot shows sync status at a glance
- **Notifications** — optional alerts on completion or errors
- **Launch at login** — starts automatically
- **Sync every:** real-time, 5 min, 15 min, 30 min, 1 hour, or manual only

## Quick start

### Download

Get the latest `DevMirror.app` from [Releases](../../releases).
Drag to `/Applications`. Open it. Done.

### Build from source

```bash
git clone https://github.com/NickiAndersen/DevMirror.git
cd DevMirror
make install
```

**Requirements:** Xcode 16+, macOS 14+

## Usage

1. Open DevMirror — first run walks through onboarding
2. Choose source (`~/Developer`) and destination (`~/DevMirror`)
3. Click "Start Syncing"
4. Done. It lives in your menu bar:

| Icon | Meaning |
|------|---------|
| ● Green | Watching, everything synced |
| ● Blue | Syncing in progress |
| ● Yellow | Paused |
| ● Red | Error |

Click the icon for pause/resume, manual sync, open folders, or settings.

## Recommended setup

| Setting | Value |
|---------|-------|
| Source | `~/Developer` |
| Destination | `~/DevMirror` |
| Sync mode | Real-time |
| Include .git | ON |
| Exclusions | Default (17 patterns) |

Then point Google Drive (or iCloud/Dropbox) to sync `~/DevMirror`.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Sync frequency | Real-time | Real-time / 5 min / 15 min / 30 min / 1 hour / Manual |
| Include .git | On | Mirror full git history |
| Deletion policy | Safe Archive | Keep deleted files 30 days / Exact mirror / Never |
| Exclusions | 17 patterns | `node_modules`, `build`, `.next`, `Pods`, `.dart_tool`, etc. |
| Notifications | Errors ON | Configurable per event type |

## Tech stack

- **Swift 6.3** with strict concurrency
- **SwiftUI** menu bar app
- **FSEvents** — kernel-level file system monitoring
- **MirrorCore** — modular sync engine with 44 unit tests
- **APFS clone-aware** file copying

## License

MIT — see [LICENSE](LICENSE)
