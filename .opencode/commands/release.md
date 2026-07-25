---
description: Build DevMirror, copy to /Applications, and publish GitHub release
---

Build, package, codesign, install to /Applications, and create a GitHub release:

```bash
pkill -f DevMirror 2>/dev/null; sleep 1
cd /Users/nickiandersen/Developer/DevMirror

swift build -c release && swift test && \
make CONFIGURATION=release package && \
xattr -cr DevMirror.app && codesign --force --sign - DevMirror.app && \
cp -rf DevMirror.app /Applications/ && \
open /Applications/DevMirror.app

# Only when ready for a version bump:
# git tag -a v1.0.X -m "Description" && git push origin v1.0.X
# ditto -c -k --keepParent DevMirror.app DevMirror-v1.0.X.zip
# gh release create v1.0.X DevMirror-v1.0.X.zip --title "DevMirror v1.0.X" --notes "Changes..."
```

Then commit and push:

```bash
git add -A && git commit -m "Description of changes" && git push
```
