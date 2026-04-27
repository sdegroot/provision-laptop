.PHONY: help test check apply plan

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# --- Provisioning ---

check: ## Check system state against desired state
	@bin/check

apply: ## Apply desired state
	@bin/apply

plan: ## Show planned changes (dry-run)
	@bin/plan

# --- Testing ---

test: ## Run all tests
	@bash tests/run.sh
