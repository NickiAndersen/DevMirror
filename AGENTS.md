# DevMirror

## When making changes

After every code change, always:
1. `swift build -c release` - ensure it compiles
2. `swift test` - ensure all 40 tests pass
3. `make CONFIGURATION=release package` - package the .app bundle
4. `cp -rf DevMirror.app /Applications/` - update the installed app
5. `open /Applications/DevMirror.app` - restart the app
6. `git add -A && git commit -m "..." && git push` - commit and push
7. Only create a new GitHub release (git tag + gh release) when the changes are significant enough for a version bump

## Project structure

- `Sources/MirrorCore/` - sync engine library (types, scanner, watcher, sync queue, etc.)
- `Sources/DevMirror/` - SwiftUI menu bar app (App, ViewModel, Settings, Onboarding)
- `Tests/MirrorCoreTests/` - 40 unit tests

## Scripts

- `make build` - debug build
- `make test` - run tests
- `make package` - build app bundle
- `make install` - install to /Applications
- `make run` - launch from project dir
