# Bigfin - Native Jellyfin Media Client Makefile

GO ?= $(shell if command -v go >/dev/null 2>&1; then command -v go; elif [ -f $$HOME/.local/go/bin/go ]; then echo $$HOME/.local/go/bin/go; else echo /tmp/go_bin/go/bin/go; fi)

MOC ?= $(shell command -v /usr/lib64/qt6/libexec/moc 2>/dev/null || command -v moc-qt6 2>/dev/null || command -v moc 2>/dev/null || echo moc)

.PHONY: all build test run clean help

all: build test

## build: Compile Go binaries (bigfin_app, test_player_bin)
build:
	@echo "==> Building Bigfin Go binaries..."
	mkdir -p bin
	$(MOC) cmd/bigfin/qml_bridge.cpp -o cmd/bigfin/qml_bridge.moc 2>/dev/null || true
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
