# Suggested Commands

## Build Commands
```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build iOS app
xcodebuild -workspace pawWatch.xcworkspace -scheme pawWatch -configuration Debug -sdk iphonesimulator build

# Build Watch app
xcodebuild -workspace pawWatch.xcworkspace -scheme "pawWatch Watch App" -configuration Debug -sdk watchsimulator build

# Run tests
xcodebuild test -workspace pawWatch.xcworkspace -scheme pawWatch -testPlan pawWatch

# Clean build
xcodebuild -workspace pawWatch.xcworkspace -scheme pawWatch clean
```

## Swift Commands
```bash
# Format code
swift-format -i Sources/**/*.swift

# Lint code
swiftlint

# Build package
swift build --package-path pawWatchPackage

# Test package
swift test --package-path pawWatchPackage
```

## Git Commands
```bash
# Status
git status

# Add changes
git add -A

# Commit
git commit -m "message"

# Push
git push origin main
```

## System Commands (Darwin/macOS)
```bash
# List files
ls -la

# Change directory
cd path/

# Find files
find . -name "*.swift"

# Search in files
grep -r "pattern" .

# Open in Xcode
open pawWatch.xcworkspace
```

## Dependency Management
```bash
# Resolve SPM dependencies
xcodebuild -resolvePackageDependencies -workspace pawWatch.xcworkspace

# Update packages
swift package update --package-path pawWatchPackage
```