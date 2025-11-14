# Versioning Workflow

pawWatch now uses a single semantic version (`1.0.x`) for both the iOS app and the watch app. The version is stored in `Config/version.json` and is synced into every target's `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` setting.

## Bumping the Version

1. Run `./scripts/bump_version.py` before starting a new change set.
   - Default behavior bumps the patch number (1.0.x → 1.0.x+1).
   - Use `--minor` or `--major` if those components need to change.
   - The script updates both `Config/version.json` and `pawWatch.xcodeproj/project.pbxproj` so the Info.plist values stay in sync.
2. Commit both modified files alongside your code change.

The Settings tab already surfaces the bundle version, so every build you share exposes the new `1.0.x` identifier.

## Commit-Time Enforcement

- `scripts/check_version_bump.sh` validates that `Config/version.json` is staged whenever other files are committed and confirms the project file references the same version.
- Enable the hook once per clone by running `./scripts/install-git-hooks.sh`. This sets `core.hooksPath` to the repo's `githooks/` folder so the `pre-commit` hook runs automatically.
- You can bypass the check (for emergencies) by setting `SKIP_VERSION_CHECK=1` before committing.

## Build Numbers

`CURRENT_PROJECT_VERSION` mirrors the patch component. That means `CFBundleVersion` always matches the `1.0.x` suffix, giving you human-readable build identifiers across TestFlight, device installs, and crash logs.
