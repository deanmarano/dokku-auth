SHELL := /bin/bash
PLUGIN_NAME := auth

.PHONY: help lint format format-check test test-unit test-integration clean install uninstall submodules

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: ## Run shellcheck on all scripts
	@echo "Running shellcheck..."
	@# SC1091: Not following source (files may not exist during lint)
	@# SC2034: Variable appears unused (desc is used by help system)
	@# SC2001: See if you can use ${variable//search/replace} (sed is clearer for line prefixing)
	@shellcheck -x -e SC1091 -e SC2034 -e SC2001 commands config functions help-functions log-functions install
	@shellcheck -x -e SC1091 -e SC2034 -e SC2001 subcommands/*
	@shellcheck -x -e SC1091 -e SC2034 -e SC2001 integrations/*.sh 2>/dev/null || true
	@shellcheck -x -e SC1091 -e SC2034 -e SC2001 providers/*/provider.sh providers/*/config.sh 2>/dev/null || true
	@echo "Shellcheck passed!"

format: ## Format all scripts with shfmt
	@echo "Formatting with shfmt..."
	@shfmt -w -i 2 -ci commands config functions help-functions log-functions install
	@shfmt -w -i 2 -ci subcommands/*
	@shfmt -w -i 2 -ci providers/*/provider.sh providers/*/config.sh 2>/dev/null || true
	@echo "Formatting complete!"

format-check: ## Check formatting without modifying
	@echo "Checking formatting..."
	@shfmt -d -i 2 -ci commands config functions help-functions log-functions install
	@shfmt -d -i 2 -ci subcommands/*
	@shfmt -d -i 2 -ci providers/*/provider.sh providers/*/config.sh 2>/dev/null || true
	@echo "Format check passed!"

test: lint test-unit ## Run all tests

test-unit: ## Run BATS unit tests
	@echo "Running unit tests..."
	@bats tests/unit/*.bats

test-integration: ## Run integration tests
	@echo "Running integration tests..."
	@bats tests/integration/*.bats

test-file: ## Run a specific test file (usage: make test-file FILE=tests/unit/create.bats)
	@bats $(FILE)

clean: ## Clean up test artifacts
	@echo "Cleaning up..."
	@rm -rf tests/tmp
	@echo "Clean complete!"

install: ## Install plugin locally (requires sudo)
	@echo "Installing plugin..."
	@sudo dokku plugin:install file://$(PWD) $(PLUGIN_NAME)

uninstall: ## Uninstall plugin locally (requires sudo)
	@echo "Uninstalling plugin..."
	@sudo dokku plugin:uninstall $(PLUGIN_NAME)

reinstall: uninstall install ## Reinstall plugin locally

submodules: ## Update git submodules
	@git submodule update --init --recursive

ci-dependencies: ## Install CI dependencies
	@echo "Installing CI dependencies..."
	@sudo apt-get update
	@sudo apt-get install -y shellcheck
	@curl -sS https://webinstall.dev/shfmt | bash
	@git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
	@cd /tmp/bats-core && sudo ./install.sh /usr/local
