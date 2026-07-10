# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Bumped dependencies to their first stable majors: FP → 2.0.1, Hourglass → 1.0.1,
  ReactiveConcurrency → 1.0.0. No SwiftRex source changes were required — none of the majors'
  breaking changes touch APIs SwiftRex consumes.
- Tooling standardized to Swift 6.3 / Xcode 26.5; added SwiftFormat, SPDX headers, and Apache
  license attribution.

### Removed
- Dropped the XCFramework release path entirely — the pre-built binary artifacts were broken and
  unused. SwiftRex is distributed via Swift Package Manager only. Removes the `rc-build-xcframework`
  CI job and all XCFramework references from the README and the Installation article.

## [0.8.8] - 2026

- Latest tagged release of the redesigned `@Feature` + state-driven navigation API. See the
  [GitHub releases](https://github.com/SwiftRex/SwiftRex/releases) for the detailed history of the
  0.8.x line.

[Unreleased]: https://github.com/SwiftRex/SwiftRex/compare/v0.8.8...main
[0.8.8]: https://github.com/SwiftRex/SwiftRex/releases/tag/v0.8.8
