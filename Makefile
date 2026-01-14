# Claude Code Container Makefile
# Build and run using Docker (OrbStack/Docker Desktop)

IMAGE_NAME := claude-code-sandbox
IMAGE_TAG := latest
FULL_IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)
TAR_FILE := $(IMAGE_NAME)-$(IMAGE_TAG).tar

.PHONY: help build shell export import clean info

help: ## Show this help message
	@echo "Claude Code Container (Docker)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the container image
	docker buildx build -t $(FULL_IMAGE) --load .

build-no-cache: ## Build the container image without cache
	docker buildx build --no-cache -t $(FULL_IMAGE) --load .

export: ## Export the container image to tar archive
	@echo "Exporting $(FULL_IMAGE) to $(TAR_FILE)..."
	docker save -o $(TAR_FILE) $(FULL_IMAGE)
	@echo "Image exported to $(TAR_FILE)"
	@ls -lh $(TAR_FILE)

import: ## Import the container image from tar archive
	@if [ ! -f "$(TAR_FILE)" ]; then \
		echo "Error: $(TAR_FILE) not found"; \
		exit 1; \
	fi
	docker load -i $(TAR_FILE)
	@echo "Image imported successfully"

clean: ## Remove the container image and archives
	-docker rmi $(FULL_IMAGE) 2>/dev/null
	-rm -f $(TAR_FILE)
	@echo "Cleanup complete"

info: ## Show image information
	@echo "Image: $(FULL_IMAGE)"
	@docker images | grep $(IMAGE_NAME) 2>/dev/null || echo "Image not found"

test: ## Test the container by running --version
	docker run --rm $(FULL_IMAGE) --version
