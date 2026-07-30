# Bigfin - Native Jellyfin Media Client Makefile

GO ?= $(shell command -v go 2>/dev/null || echo /tmp/go_bin/go/bin/go)
PYTHON ?= python3

.PHONY: all build test test-ui run clean help

all: build test

## build: Compile Go binaries (bigfin_app, test_player_bin)
build:
	@echo "==> Building Bigfin Go binaries..."
	mkdir -p bin
	$(GO) build -o bin/bigfin_app ./cmd/bigfin
	$(GO) build -o bin/test_player_bin ./cmd/test_player

## test: Run Go unit tests
test:
	@echo "==> Running Go unit tests..."
	$(GO) test -v ./...

## test-ui: Run Python QML UI syntax check & headless screenshot test
test-ui:
	@echo "==> Verifying Python UI components..."
	$(PYTHON) -m py_compile preview_ui.py scripts/test_video_player.py scripts/ui_test_capture.py
	@echo "==> Running headless UI capture test..."
	$(PYTHON) scripts/ui_test_capture.py

## run: Launch Bigfin native UI via Python launcher
run:
	@echo "==> Launching Bigfin UI..."
	./run_bigfin.sh

## clean: Remove build binaries, python cache, and test output
clean:
	@echo "==> Cleaning build artifacts and cache..."
	rm -rf bin/ bigfin_app test_player_bin screenshots/ __pycache__/ *.pyc
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

## help: Display available Makefile targets
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':'
