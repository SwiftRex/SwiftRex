# Xcodeproj

xcodeproj:
	swift package generate-xcodeproj --xcconfig-overrides=Development.xcconfig

# Unit Test

test-macos:
	set -o pipefail && \
		xcodebuild clean test \
		-project SwiftRex.xcodeproj \
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
		-project SwiftRex.xcodeproj \
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
	bundle exec jazzy

# Pre-Build

prebuild-mac: sourcery lint-autocorrect lint-check carthage-copy-mac

prebuild-ios: sourcery lint-autocorrect lint-check carthage-copy-ios

prebuild-watchos: sourcery lint-autocorrect lint-check carthage-copy-watchos

prebuild-tvos: sourcery lint-autocorrect lint-check carthage-copy-tvos

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

