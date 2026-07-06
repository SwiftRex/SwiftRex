# Contributing to SwiftRex

Thank you for your interest in contributing to SwiftRex!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/SwiftRex.git`
3. Install tools: `brew install mint && mint bootstrap`
4. Build: `swift build 2>&1 | xcsift`
5. Test: `swift test 2>&1 | xcsift`

## Branch Naming

| Pattern | Purpose |
|---------|---------|
| `feature/name` | New feature |
| `bugfix/name` | Bug fix |

Never push directly to `main` — always open a PR.

## Before Submitting

- [ ] `mint run swiftformat --lint .` passes (run `--write` to auto-fix)
- [ ] `mint run swiftlint lint --strict` passes
- [ ] `swift test` passes on macOS
- [ ] `mint run periphery scan` passes
- [ ] New public APIs have DocC documentation (inline `///` + a `.docc` topic/article where relevant)
- [ ] CHANGELOG.md updated under `## [Unreleased]`
- [ ] Every new `.swift` file starts with `// SPDX-License-Identifier: Apache-2.0`

## Code Style

This library follows strict, Haskell-inspired functional programming. See the README and
`CLAUDE.md` for detailed guidance:

- Pure functions — no side effects; inject all ambient state (`Date`, `UUID`, `Calendar`,
  `Locale`, `TimeZone`, storage) as parameters
- `Result<Success, SpecificFailure>` over `throws`; `DeferredTask` over `async/await`
- Tacit / point-free composition with the FP operators (`>>>`, `|>`, `<£>`, `>>-`)
- No force unwraps, no crash functions (`fatalError`, `preconditionFailure`, …)
- `Sendable`-first; no singletons or global mutable state

## Pull Request Process

1. Open a PR against `main` using the PR template (What / Why / How / Tests).
2. All CI checks (format, lint, build, test, periphery, cross-platform) must pass.
3. A maintainer reviews and merges. Breaking changes are documented in `CHANGELOG.md`.

## License

By contributing, you agree that your contributions are licensed under the Apache License 2.0.
