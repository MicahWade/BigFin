# Bigfin - Native Jellyfin Media Client Makefile

GO ?= $(shell command -v go 2>/dev/null || echo /tmp/go_bin/go/bin/go)

.PHONY: all build test run clean help

all: build test

## build: Compile Go binaries (bigfin_app, test_player_bin)
build:
	@echo "==> Building Bigfin Go binaries..."
	mkdir -p bin
	$(GO) build -o bin/bigfin_app ./cmd/bigfin
	cp bin/bigfin_app ./bigfin
	$(GO) build -o bin/test_player_bin ./cmd/test_player

## test: Run Go unit tests
test:
	@echo "==> Running Go unit tests..."
	$(GO) test -v ./...

## run: Launch Bigfin client
run: build
	@echo "==> Launching Bigfin Client..."
	./run_bigfin.sh

## clean: Remove build binaries and test output
clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf bin/ bigfin_app test_player_bin screenshots/

## help: Display available Makefile targets
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':'
