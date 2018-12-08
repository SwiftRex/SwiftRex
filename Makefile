# Version

ifndef TO
set-version:
	$(error Missing new version number. Please use `make set-version TO=1.2.3`)
else
set-version:
	sed -i .bkp -E "s/(s\.version.*=.*)'.*'/\1'${TO}'/" SwiftRex.podspec
	sed -i .bkp -E "s/(CURRENT_PROJECT_VERSION.*= ).*/\1${TO}/" Configuration/SwiftRex-Common.xcconfig
endif

# Pod push
pod-push:
	pod trunk push SwiftRex.podspec --allow-warnings

# Xcodeproj

xcodeproj:
	swift package generate-xcodeproj --xcconfig-overrides=Development.xcconfig

# Unit Test

test-macos:
	set -o pipefail && \
		xcodebuild clean test \
		-workspace SwiftRex.xcworkspace \
		-scheme SwiftRex\ macOS \
		-destination platform="macOS" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		ONLY_ACTIVE_ARCH=YES \
		VALID_ARCHS=x86_64 \
		| xcpretty

test-ios:
	set -o pipefail && \
		xcodebuild clean test \
		-workspace SwiftRex.xcworkspace \
		-scheme SwiftRex\ iOS \
		-destination platform="iOS Simulator,name=iPhone 8,OS=11.3" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		ONLY_ACTIVE_ARCH=YES \
		VALID_ARCHS=x86_64 \
		| xcpretty

test-swift:
	swift test

test-all: test-mac test-ios

# Lint

lint-check: check-lint
lint-check:
	swiftlint

lint-autocorrect: check-lint
lint-autocorrect:
	swiftlint autocorrect

# Sourcery

sourcery: check-sourcery
sourcery:
	sourcery

# CocoaPods
pod-install:
	bundle exec pod install

# Carthage Copy

carthage-copy: check-carthage
carthage-copy:
	export SCRIPT_INPUT_FILE_0=$(SRCROOT)/Carthage/Build/${PLATFORM}/RxSwift.framework \
	export SCRIPT_INPUT_FILE_COUNT=1 \
	export SCRIPT_OUTPUT_FILE_0=$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/RxSwift.framework \
	export SCRIPT_OUTPUT_FILE_COUNT=1; \
	carthage copy-frameworks

carthage-copy-mac: PLATFORM = Mac
carthage-copy-mac: carthage-copy

carthage-copy-ios: PLATFORM = iOS
carthage-copy-ios: carthage-copy

carthage-copy-watchos: PLATFORM = watchOS
carthage-copy-watchos: carthage-copy

carthage-copy-tvos: PLATFORM = tvOS
carthage-copy-tvos: carthage-copy

# Jazzy

jazzy:
	bundle exec jazzy -x -target,SwiftRex\ macOS

# Pre-Build

prebuild-mac: sourcery lint-autocorrect lint-check

prebuild-ios: sourcery lint-autocorrect lint-check

prebuild-watchos: sourcery lint-autocorrect lint-check

prebuild-tvos: sourcery lint-autocorrect lint-check

# Validate pre-reqs

LINT := $(shell command -v swiftlint 2> /dev/null)
SOURCERY := $(shell command -v sourcery 2> /dev/null)
CARTHAGE := $(shell command -v carthage 2> /dev/null)

check-lint:
ifndef LINT
    $(error "Swiftlint not installed, please run `brew install swiftlint`")
endif

check-sourcery:
ifndef SOURCERY
    $(error "Sourcery not installed, please run `brew install sourcery`")
endif

check-carthage:
ifndef CARTHAGE
    $(error "Carthage not installed, please run `brew install carthage`")
endif

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
	@echo make test-macos
	@echo -- runs the unit tests for the macOS target
	@echo
	@echo make test-ios
	@echo -- runs the unit tests for the iOS target
	@echo
	@echo make test-swift
	@echo -- runs the unit tests using Swift Package Manager
	@echo
	@echo make test-all
	@echo -- runs the unit tests for macOS and iOS targets
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
	@echo make carthage-copy PLATFORM=Mac
	@echo -- runs the Carthage Framework copy for a given platform
	@echo -- param1: PLATFORM = required, Carthage build platform
	@echo
	@echo make carthage-copy-mac
	@echo -- runs the Carthage Framework copy for macOS target
	@echo
	@echo make carthage-copy-ios
	@echo -- runs the Carthage Framework copy for iOS target
	@echo
	@echo make carthage-copy-watchos
	@echo -- runs the Carthage Framework copy for watchOS target
	@echo
	@echo make carthage-copy-tvos
	@echo -- runs the Carthage Framework copy for tvOS target
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
	@echo make check-lint
	@echo -- checks if Swiftlint is installed
	@echo
	@echo make check-sourcery
	@echo -- checks if Sourcery is installed
	@echo
	@echo make check-carthage
	@echo -- checks if Carthage is installed
	@echo
