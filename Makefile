# Makefile for harness - Fork of harness/harness
# Provides common development tasks and CI/CD helpers

.PHONY: all build test lint fmt vet clean docker-build docker-run help

# Go parameters
GOCMD   := go
GOBUILD := $(GOCMD) build
GOTEST  := $(GOCMD) test
GOVET   := $(GOCMD) vet
GOFMT   := gofmt
GOLINT  := golangci-lint

# Build parameters
BINARY_NAME := harness
BUILD_DIR   := ./bin
CMD_DIR     := ./cmd/harness
VERSION     ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT      ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME  ?= $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')

# Linker flags
LDFLAGS := -ldflags "-X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.buildTime=$(BUILD_TIME)"

# Docker parameters
DOCKER_IMAGE := harness
DOCKER_TAG   ?= $(VERSION)

all: fmt vet lint test build ## Run fmt, vet, lint, test, and build

build: ## Build the binary
	@echo "==> Building $(BINARY_NAME) $(VERSION)..."
	@mkdir -p $(BUILD_DIR)
	$(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) $(CMD_DIR)
	@echo "==> Binary available at $(BUILD_DIR)/$(BINARY_NAME)"

test: ## Run unit tests
	@echo "==> Running tests..."
	$(GOTEST) -v -race -count=1 ./...

test-cover: ## Run tests with coverage report
	@echo "==> Running tests with coverage..."
	$(GOTEST) -v -race -count=1 -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "==> Coverage report available at coverage.html"

lint: ## Run golangci-lint
	@echo "==> Running linter..."
	$(GOLINT) run ./...

fmt: ## Format Go source files
	@echo "==> Formatting code..."
	$(GOFMT) -s -w .

fmt-check: ## Check formatting without modifying files
	@echo "==> Checking code formatting..."
	@test -z "$(shell $(GOFMT) -s -l . | tee /dev/stderr)" || (echo "==> Please run 'make fmt' to fix formatting" && exit 1)

vet: ## Run go vet
	@echo "==> Running go vet..."
	$(GOVET) ./...

clean: ## Remove build artifacts
	@echo "==> Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -f coverage.out coverage.html
	$(GOCMD) clean -cache

docker-build: ## Build Docker image
	@echo "==> Building Docker image $(DOCKER_IMAGE):$(DOCKER_TAG)..."
	docker build \
		--build-arg VERSION=$(VERSION) \
		--build-arg COMMIT=$(COMMIT) \
		--build-arg BUILD_TIME=$(BUILD_TIME) \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) \
		-t $(DOCKER_IMAGE):latest \
		.

docker-run: ## Run the Docker container
	@echo "==> Running Docker container $(DOCKER_IMAGE):$(DOCKER_TAG)..."
	docker run --rm -it $(DOCKER_IMAGE):$(DOCKER_TAG)

tidy: ## Tidy Go module dependencies
	@echo "==> Tidying Go modules..."
	$(GOCMD) mod tidy

download: ## Download Go module dependencies
	@echo "==> Downloading Go modules..."
	$(GOCMD) mod download

help: ## Display this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
