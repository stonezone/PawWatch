# Claude Starter Checklist — Liquid Glass Phase Work

1. Read `documentation_archive/PawWatch_UI_Package/TODO_UI.md` + `docs/HANDOFF_STATUS.md` for current phase notes.
2. Ensure `documentation_archive/` changes are staged (folder is tracked now).
3. For new UI components:
   - Copy/update assets under `pawWatchPackage/Sources/pawWatchFeature/Resources/`.
   - Keep Package.swift resources block in sync.
   - Add SwiftUI primitives under `LiquidGlassComponents.swift` with iOS 26 availability + iOS 18 fallbacks.
4. Use `python3 scripts/bump_version.py --set <version>` at each phase boundary (pre-commit hook enforces this).
5. Build with `xcodebuild -workspace pawWatch.xcworkspace -scheme pawWatch -destination 'generic/platform=iOS' build` (no `xcpretty`).
6. After each phase: update `TODO_UI.md` status log, refresh `docs/HANDOFF_STATUS.md`, commit, and push.
7. For doc-only commits, set `SKIP_VERSION_CHECK=1` before running `git commit` to bypass the hook.
