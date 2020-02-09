# Version

ifndef TO
set-version:
	$(error Missing new version number. Please use `make set-version TO=1.2.3`)
else
set-version:
	sed -i .bkp -E "s/(s\.version.*=.*)'.*'/\1'${TO}'/" *.podspec
	sed -i .bkp -E "s/(CURRENT_PROJECT_VERSION.*= ).*/\1${TO}/" Configuration/SwiftRex-Common.xcconfig
endif

# Pod push
pod-push:
	pod trunk push SwiftRex.podspec --allow-warnings
	pod trunk push ReactiveSwiftRex.podspec --allow-warnings
	pod trunk push RxSwiftRex.podspec --allow-warnings
	pod trunk push CombineRex.podspec --allow-warnings

# Xcodeproj

xcodeproj:
	swift package generate-xcodeproj --xcconfig-overrides=Development.xcconfig

# Unit Test

test-all:
	set -o pipefail && \
		xcodebuild clean test \
		-workspace SwiftRex.xcworkspace \
		-scheme BuildAndTestAll \
		-destination "platform=iOS Simulator,name=iPhone 11 Pro Max" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		ONLY_ACTIVE_ARCH=YES \
		VALID_ARCHS=x86_64 \
		| bundle exec xcpretty

test-common:
	set -o pipefail && \
		xcodebuild clean test \
		-workspace SwiftRex.xcworkspace \
		-scheme SwiftRex\ iOS \
		-destination "platform=iOS Simulator,name=iPhone 11 Pro Max" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		ONLY_ACTIVE_ARCH=YES \
		VALID_ARCHS=x86_64 \
		| bundle exec xcpretty

test-combine:
	set -o pipefail && \
		xcodebuild clean test \
		-workspace SwiftRex.xcworkspace \
		-scheme SwiftRex\ iOS\ Combine \
		-destination "platform=iOS Simulator,name=iPhone 11 Pro Max" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		ONLY_ACTIVE_ARCH=YES \
		VALID_ARCHS=x86_64 \
		| bundle exec xcpretty

test-reactiveswift:
	set -o pipefail && \
		xcodebuild clean test \
		-workspace SwiftRex.xcworkspace \
		-scheme SwiftRex\ iOS\ ReactiveSwift \
		-destination "platform=iOS Simulator,name=iPhone 11 Pro Max" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		ONLY_ACTIVE_ARCH=YES \
		VALID_ARCHS=x86_64 \
		| bundle exec xcpretty

test-rxswift:
	set -o pipefail && \
		xcodebuild clean test \
		-workspace SwiftRex.xcworkspace \
		-scheme SwiftRex\ iOS\ RxSwift \
		-destination "platform=iOS Simulator,name=iPhone 11 Pro Max" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		ONLY_ACTIVE_ARCH=YES \
		VALID_ARCHS=x86_64 \
		| bundle exec xcpretty

# Lint

lint-check:
	Pods/SwiftLint/swiftlint

lint-autocorrect:
	Pods/SwiftLint/swiftlint autocorrect

# Sourcery

sourcery:
	Pods/Sourcery/bin/sourcery

# CocoaPods
pod-install:
	bundle exec pod install

# Jazzy

jazzy:
	bundle exec jazzy -x -target,SwiftRex\ iOS\ Combine

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
	@echo make xcodeproj
	@echo -- creates xcodeproj for those using Swift Package Manager
	@echo
	@echo make test-common
	@echo -- runs the unit tests for the macOS target common for any framework
	@echo
	@echo make test-combine
	@echo -- runs the unit tests for the macOS target using Combine dependency
	@echo
	@echo make test-reactiveswift
	@echo -- runs the unit tests for the macOS target using ReactiveSwift dependency
	@echo
	@echo make test-rxswift
	@echo -- runs the unit tests for the macOS target using RxSwift dependency
	@echo
	@echo make test-all
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
