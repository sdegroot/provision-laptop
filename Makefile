.PHONY: help vm-download vm-create vm-start vm-ssh vm-destroy vm-kickstart vm-reset test check apply plan

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# --- VM Management ---

vm-download: ## Download Fedora Silverblue ISO
	@bash tests/vm/download-iso.sh

vm-create: ## Create the test VM
	@bash tests/vm/create-vm.sh

vm-start: ## Start the test VM
	@bash tests/vm/start-vm.sh

vm-ssh: ## SSH into the test VM
	@bash tests/vm/ssh-vm.sh

vm-destroy: ## Destroy the test VM
	@bash tests/vm/destroy-vm.sh

vm-kickstart: ## Automated Fedora Silverblue install via kickstart
	@bash tests/vm/kickstart-install.sh

vm-reset: vm-destroy vm-create vm-start ## Destroy and recreate the VM

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
