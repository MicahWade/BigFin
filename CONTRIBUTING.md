# Contributing to Bigfin

Thank you for your interest in contributing to **Bigfin**! Bigfin is a native 10-foot Jellyfin media client built for Linux desktop environments and KDE Plasma Bigscreen.

This document provides guidelines and instructions for contributing to the repository.

---

## Table of Contents

- [Development Environment Setup](#development-environment-setup)
- [Project Architecture](#project-architecture)
- [Building & Running](#building--running)
- [Running Tests](#running-tests)
- [Coding Guidelines](#coding-guidelines)
- [Submitting Pull Requests](#submitting-pull-requests)

---

## Development Environment Setup

### Prerequisites

To build and run Bigfin locally, ensure you have the following installed:

1. **Go** (version 1.22 or higher)
2. **Python 3** (3.8+)
3. **PyQt6** and **Qt6 QML** packages
4. **Kirigami2 / Kirigami Addons** (for KDE 10-foot spatial UI components)
5. **mpv** or **ffplay** (for media playback acceleration)

#### Dependencies on Fedora / RHEL:
```bash
sudo dnf install go python3 python3-pyqt6 qt6-qtdeclarative-devel kf6-kirigami-devel mpv
```

#### Dependencies on Ubuntu / Debian:
```bash
sudo apt update
sudo apt install golang-go python3 python3-pyqt6 qml-module-org-kde-kirigami2 mpv
```

---

## Project Architecture

```
Bigfin/
├── cmd/                # Main application entrypoints (Go)
│   ├── bigfin/         # Bigfin Go backend service launcher
│   └── test_player/    # Media engine CLI testing binary
├── pkg/                # Reusable Go packages
│   ├── jellyfin/       # Jellyfin REST API client (Auth, Items, HLS URLs)
│   └── player/         # Media player engine wrapper (mpv / IPC socket)
├── ui/                 # User Interface assets & QML source
│   ├── qml/            # Kirigami QML 10-foot TV interfaces & views
│   └── assets/         # Poster art and UI icons
├── scripts/            # Development, testing, and capture utilities
│   ├── test_video_player.py  # HLS playlist verification script
│   └── ui_test_capture.py    # Headless QML UI screenshot testing tool
├── preview_ui.py       # PyQt6 QML application launcher & SessionBridge
├── run_bigfin.sh       # Linux desktop launcher & desktop integration
├── Makefile            # Build, test, run, and clean automation
└── README.md           # Main documentation
```

---

## Building & Running

You can use the provided `Makefile` to simplify common development commands:

- **Build Go binaries**:
  ```bash
  make build
  ```
  Binaries will be output to `bin/bigfin_app` and `bin/test_player_bin`.

- **Run the UI application**:
  ```bash
  make run
  # or directly:
  ./run_bigfin.sh
  ```

- **Clean build artifacts**:
  ```bash
  make clean
  ```

---

## Running Tests

### Go Unit Tests
Run all unit tests across the codebase:
```bash
make test
```

To run tests for a specific package:
```bash
go test -v ./pkg/jellyfin
go test -v ./pkg/player
```

### Testing Live Streams (Optional)
To run live Jellyfin streaming verification tests against your server:
```bash
JELLYFIN_TEST_SERVER="http://your-jellyfin-server:8096" JELLYFIN_TEST_TOKEN="your-access-token" go test -v ./pkg/player
```

### UI Verification Tests
To test the Python UI launcher and capture headless UI screenshots:
```bash
make test-ui
```

---

## Coding Guidelines

- **Go Code**:
  - Follow standard `gofmt` and Go idioms.
  - Handle errors explicitly and avoid swallow/ignoring errors.
  - Ensure all new API client methods or player features include corresponding unit tests in `*_test.go`.

- **QML / UI Code**:
  - Keep 10-foot TV navigation top of mind. All UI components must be fully navigable via keyboard arrow keys (D-Pad) and Enter.
  - Maintain fluid focus indicators (active border colors, scale transforms on focus).
  - Prefer Kirigami visual controls and custom component styling over browser-style controls.

- **Python Launcher (`preview_ui.py`)**:
  - Keep `SessionBridge` Qt slots clean and safe for concurrency.
  - Store config in `~/.config/bigfin/` and cache in `~/.cache/bigfin/`.

---

## Submitting Pull Requests

1. **Fork the repository** and create a feature branch (`git checkout -b feature/amazing-feature`).
2. **Commit your changes** with clear, descriptive commit messages.
3. **Verify tests pass**: Run `make test` and `make test-ui` locally.
4. **Push to your fork** (`git push origin feature/amazing-feature`).
5. **Open a Pull Request** against the `main` branch with a summary of changes and visual screenshots if altering UI components.

Thank you for helping make Bigfin better!
