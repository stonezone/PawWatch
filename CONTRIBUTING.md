# Contributing to pawWatch

Thank you for your interest in contributing to pawWatch!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR-USERNAME/PawWatch.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Commit with descriptive messages
6. Push to your fork
7. Open a Pull Request

## Development Setup

### Requirements
- macOS with Xcode 26+
- Swift 6.2
- iOS 26+ Simulator or physical device
- watchOS 26+ Simulator or Apple Watch

### Build Steps
```bash
# Clone the repo
git clone https://github.com/stonezone/PawWatch.git
cd pawWatch-app

# Open in Xcode
open PawWatch.xcodeproj

# Select your development team in project settings
# Build and run (Cmd+R)
```

## Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for consistent formatting
- Maintain Swift 6.2 strict concurrency
- Document public APIs with DocC comments
- Keep functions focused and testable

## Testing

- Write unit tests for all new features
- Ensure existing tests pass
- Aim for 80%+ code coverage
- Test on both iOS and watchOS simulators

## Commit Messages

Use conventional commits format:

```
feat: add geofencing alerts
fix: correct GPS coordinate accuracy
docs: update architecture documentation
test: add location service tests
refactor: simplify watch connectivity logic
```

## Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure all tests pass
4. Update CHANGELOG.md (if applicable)
5. Request review from maintainers

## Architecture Guidelines

### Must Follow
- 0.5s GPS update minimum (real-time tracking)
- Watch + iPhone only (no external devices)
- iOS 26 Liquid Glass design language
- Single-stream architecture (Watch GPS → iPhone)

### Must Avoid
- GPS throttle >0.5s (performance regression)
- External device integration
- Over-engineered solutions
- Breaking changes without discussion

## Questions?

Open an issue or discussion on GitHub for:
- Feature requests
- Bug reports
- Architecture questions
- General feedback

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
