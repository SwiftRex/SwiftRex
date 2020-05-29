# Version

ifndef TO
set-version:
	$(error Missing new version number. Please use `make set-version TO=1.2.3`)
else
set-version:
	sed -i .bkp -E "s/(s\.version.*=.*)'.*'/\1'${TO}'/" *.podspec
	sed -i .bkp -E "s/(, from: )\".*\"\)/\1\"${TO}\")/" README.md
	rm *.bkp
endif

# Pod push
pod-push:
	pod trunk push SwiftRex.podspec --allow-warnings
	pod trunk push ReactiveSwiftRex.podspec --allow-warnings
	pod trunk push RxSwiftRex.podspec --allow-warnings
	pod trunk push CombineRex.podspec --allow-warnings

mint:
	brew install mint
	mint bootstrap

# Unit Test

test:
	set -o pipefail && swift test

# Lint

lint-check:
	mint run swiftlint

lint-autocorrect:
	mint run swiftlint autocorrect

# Sourcery

sourcery:
	mint run sourcery

# CocoaPods
pod-install:
	bundle exec pod install

# Jazzy

jazzy:
	bundle exec jazzy --module CombineRex        --swift-build-tool spm --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 --output docs/api/CombineRex
	bundle exec jazzy --module ReactiveSwiftRex  --swift-build-tool spm --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 --output docs/api/ReactiveSwiftRex
	bundle exec jazzy --module RxSwift           --swift-build-tool spm --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 --output docs/api/RxSwiftRex
	bundle exec jazzy --module SwiftRex          --swift-build-tool spm --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 --output docs/api

swiftdoc:
	mint run swift-doc generate Sources --module-name SwiftRex --output docs/swiftdocs --format html

# Pre-Build

prebuild-mac: sourcery lint-autocorrect lint-check

prebuild-ios: sourcery lint-autocorrect lint-check

prebuild-watchos: sourcery lint-autocorrect lint-check

prebuild-tvos: sourcery lint-autocorrect lint-check

# Help

help:
	@echo Possible tasks
	@echo
	@echo make set-version TO=1.2.3
	@echo -- sets the SwiftRex version to the given value
	@echo -- param1: TO = required, new version number
	@echo
	@echo make pod-push
	@echo -- publishes the pod on CocoaPods repository
	@echo
	@echo make test
	@echo -- runs all the unit tests
	@echo
	@echo make lint-check
	@echo -- validates the code style
	@echo
	@echo make lint-autocorrect
	@echo -- automatic linting for auto-fixable rules
	@echo
	@echo make sourcery
	@echo -- code generation
	@echo
	@echo make jazzy
	@echo -- generates documentation
	@echo
	@echo make prebuild-mac
	@echo -- runs the pre-build phases on macOS target
	@echo
	@echo make prebuild-ios
	@echo -- runs the pre-build phases on iOS target
	@echo
	@echo make prebuild-watchos
	@echo -- runs the pre-build phases on watchOS target
	@echo
	@echo make prebuild-tvos
	@echo -- runs the pre-build phases on tvOS target
	@echo
