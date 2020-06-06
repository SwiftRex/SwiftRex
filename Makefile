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
	set -o pipefail && \
	swift test --enable-code-coverage

code-coverage-summary:
	xcrun llvm-cov report \
		.build/x86_64-apple-macosx/debug/SwiftRexPackageTests.xctest/Contents/MacOS/SwiftRexPackageTests \
		--instr-profile .build/x86_64-apple-macosx/debug/codecov/default.profdata \
		-use-color \
		--ignore-filename-regex \.build \
		--ignore-filename-regex Tests\/ \

code-coverage-details:
	xcrun llvm-cov show \
		.build/x86_64-apple-macosx/debug/SwiftRexPackageTests.xctest/Contents/MacOS/SwiftRexPackageTests \
		--instr-profile .build/x86_64-apple-macosx/debug/codecov/default.profdata \
		-use-color \
		--ignore-filename-regex \.build \
		--ignore-filename-regex Tests\/ \

code-coverage-file:
	xcrun llvm-cov show \
		.build/x86_64-apple-macosx/debug/SwiftRexPackageTests.xctest/Contents/MacOS/SwiftRexPackageTests \
		--instr-profile .build/x86_64-apple-macosx/debug/codecov/default.profdata \
		-use-color \
		--ignore-filename-regex \.build \
		--ignore-filename-regex Tests\/ \
		> coverage.txt

code-coverage-upload:
	bash <(curl -s https://codecov.io/bash) \
		-X xcodellvm \
		-X gcov \
		-f coverage.txt

# Lint

lint-check:
	mint run swiftlint

lint-autocorrect:
	mint run swiftlint autocorrect

# Sourcery

sourcery:
	mint run sourcery

# Jazzy

jazzy:
	bundle exec jazzy --module CombineRex        --swift-build-tool spm --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 --output docs/api/CombineRex
	bundle exec jazzy --module ReactiveSwiftRex  --swift-build-tool spm --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 --output docs/api/ReactiveSwiftRex
	bundle exec jazzy --module RxSwift           --swift-build-tool spm --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 --output docs/api/RxSwiftRex
	bundle exec jazzy --module SwiftRex          --swift-build-tool spm --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 --output docs/api

swiftdoc:
	mint run swift-doc generate Sources --module-name SwiftRex --output docs/swiftdocs --format html

# Pre-Build

prebuild: sourcery lint-autocorrect lint-check

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
	@echo make mint
	@echo -- bootstrap mint dependency manager
	@echo
	@echo make test
	@echo -- runs all the unit tests
	@echo
	@echo make code-coverage-summary
	@echo -- shows a code coverage summary
	@echo
	@echo make code-coverage-details
	@echo -- shows a code coverage detailed report
	@echo
	@echo make code-coverage-file
	@echo -- creates a code coverage file to be uploaded to codecov
	@echo
	@echo make code-coverage-upload
	@echo -- upload code coverage file to codecov
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
	@echo make swiftdoc
	@echo -- generates documentation (alternative API docs, not fully working yet)
	@echo
	@echo make prebuild
	@echo -- runs the pre-build phases
	@echo
