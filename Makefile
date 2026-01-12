# Claude Code Container Makefile
# Build and run using Apple Container (macOS native containerization)

IMAGE_NAME := claude-code-sandbox
IMAGE_TAG := latest
FULL_IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)
OCI_FILE := $(IMAGE_NAME)-$(IMAGE_TAG).oci

.PHONY: help build shell export import clean info

help: ## Show this help message
	@echo "Claude Code Container (Apple Container)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the container image
	container build -t $(FULL_IMAGE) .

build-no-cache: ## Build the container image without cache
	container build --no-cache -t $(FULL_IMAGE) .

export: ## Export the container image to OCI archive
	@echo "Exporting $(FULL_IMAGE) to $(OCI_FILE)..."
	container image export $(FULL_IMAGE) $(OCI_FILE)
	@echo "Image exported to $(OCI_FILE)"
	@ls -lh $(OCI_FILE)

import: ## Import the container image from OCI archive
	@if [ ! -f "$(OCI_FILE)" ]; then \
		echo "Error: $(OCI_FILE) not found"; \
		exit 1; \
	fi
	container image import $(OCI_FILE)
	@echo "Image imported successfully"

clean: ## Remove the container image and archives
	-container rmi $(FULL_IMAGE) 2>/dev/null
	-rm -f $(OCI_FILE)
	@echo "Cleanup complete"

info: ## Show image information
	@echo "Image: $(FULL_IMAGE)"
	@container images | grep $(IMAGE_NAME) 2>/dev/null || echo "Image not found"

test: ## Test the container by running --version
	container run --rm $(FULL_IMAGE) --version
