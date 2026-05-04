.PHONY: mint test lint-check lint-autocorrect periphery help
.DEFAULT_GOAL := help

# Dependencies

mint:
	command -v mint || brew install mint
	mint bootstrap

# Unit Tests

test:
	set -o pipefail && \
	swift test --build-path .build

# Lint

lint-check:
	mint run swiftlint lint --strict

lint-autocorrect:
	mint run swiftlint --fix

# Dead code analysis

periphery:
	mint run periphery scan

# Help

help:
	@echo Possible tasks
	@echo
	@echo make mint
	@echo -- bootstrap mint dependency manager
	@echo
	@echo make test
	@echo -- runs all unit tests
	@echo
	@echo make lint-check
	@echo -- validates the code style
	@echo
	@echo make lint-autocorrect
	@echo -- auto-corrects fixable lint violations
	@echo
	@echo make periphery
	@echo "-- scans for unused code"
