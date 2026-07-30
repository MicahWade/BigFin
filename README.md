<div align="center">

  <img src="Logo.png" alt="Bigfin Logo" width="160" />

  # Bigfin

  **Native 10-Foot Spatial Jellyfin Media Client for Linux & KDE Plasma Bigscreen**

  [![Go Version](https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat-square&logo=go)](https://go.dev/)
  [![Qt Version](https://img.shields.io/badge/Qt-6.0+-41CD52?style=flat-square&logo=qt)](https://www.qt.io/)
  [![KDE Kirigami](https://img.shields.io/badge/UI-KDE%20Kirigami-1D99F3?style=flat-square&logo=kde)](https://kde.org/products/kirigami/)
  [![License](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](LICENSE)

</div>

---

## 📖 Overview

**Bigfin** is a native 10-foot TV media client specifically built for modern Linux desktop environments, living-room PCs, and **KDE Plasma Bigscreen**. 

Combining a **Go** backend engine for REST API interactions and low-latency `libmpv` playback control with a fluid **Qt6 / Kirigami QML** spatial interface, Bigfin delivers a smooth, remote-friendly home theater experience for Jellyfin servers.

---

## ✨ Features

- 🛋️ **10-Foot Spatial Navigation**: Designed from the ground up for TV screens, D-Pad remotes, and controllers.
- ⚡ **Go Engine & libmpv Integration**: Hardware-accelerated video playback with sub-second IPC socket controls.
- 📺 **Jellyfin Integration**:
  - Full user library views (Movies, TV Shows, Music, Collections)
  - **Next Up** and **Continue Watching** queues
  - Adaptive HLS playlist streaming and direct playback
  - Automatic watch progress synchronization back to server
- 🔑 **Multi-Session Management**: Save and seamlessly switch between multiple Jellyfin servers and user accounts.
- 🎨 **Dynamic Themes & Spatial UI**: Glassmorphic dark themes, dynamic ambient backgrounds, customizable poster sizing, and smooth view transitions.
- 🔍 **Unified Search & Favorites**: Instantly search media items across libraries or mark favorites.
- 🛠️ **Fallback Media Engine**: Built-in fallback support for `mpv`, `ffplay`, `vlc`, and `QtMultimedia`.

---

## 🏗️ Architecture Overview

Bigfin is structured into decoupled subsystem layers:

```
                  ┌─────────────────────────────────────┐
                  │    PyQt6 QML Spatial TV Interface   │
                  │ (Kirigami / Main.qml / HomeView)    │
                  └──────────────────┬──────────────────┘
                                     │ SessionBridge (Qt Signals & Slots)
                  ┌──────────────────┴──────────────────┐
                  │          Session Manager            │
                  │    (~/.config/bigfin/sessions.json) │
                  └──────────────────┬──────────────────┘
                                     │
                  ┌──────────────────┴──────────────────┐
                  │     Go Core Engine (cmd & pkg)      │
                  ├──────────────────┬──────────────────┤
                  │  pkg/jellyfin    │    pkg/player    │
                  │  (REST API Client│   (mpv Engine    │
                  │   & Auth Store)  │   & IPC Socket)  │
                  └──────────────────┴──────────────────┘
```

---

## 📁 Repository Structure

```
.
├── cmd/                      # Go binary entrypoints
│   ├── bigfin/               # Main Bigfin backend engine launcher
│   └── test_player/          # CLI stream & player verification tool
├── pkg/                      # Reusable Go packages
│   ├── jellyfin/             # Jellyfin REST API client (Auth, Items, HLS, Progress)
│   └── player/               # Media player controller (mpv IPC, ffplay fallback)
├── ui/                       # Front-end user interface
│   ├── qml/                  # Kirigami QML views & spatial components
│   │   ├── components/       # VideoPlayer, MediaGrid, ItemDetails, ServerAuth
│   │   └── assets/           # Icons and preview poster assets
│   └── assets/               # Mock poster SVGs for offline previews
├── scripts/                  # Development & testing scripts
│   ├── test_video_player.py  # HLS playlist verification script
│   └── ui_test_capture.py    # Headless QML UI capture utility
├── preview_ui.py             # Main PyQt6 / QML UI launcher script & SessionBridge
├── run_bigfin.sh             # Linux launcher & desktop entry installer
├── Makefile                  # Build, test, run, and clean tasks
├── CONTRIBUTING.md           # Developer setup and contribution guide
└── LICENSE                   # License information
```

---

## ⚙️ Prerequisites & Dependencies

Before running or building Bigfin, ensure your system has the following installed:

| Dependency | Minimum Version | Description |
| :--- | :--- | :--- |
| **Go** | 1.22+ | Backend compilation and player engine |
| **Python 3** | 3.8+ | PyQt6 QML runtime launcher |
| **PyQt6 & Qt6 QML** | 6.0+ | UI engine & declarative Qt components |
| **KDE Kirigami** | 2.15+ / 6.0+ | Spatial 10-foot UI framework |
| **mpv** | 0.34+ | Primary hardware-accelerated video player |

### Package Manager Installation

#### Fedora / RHEL:
```bash
sudo dnf install go python3 python3-pyqt6 qt6-qtdeclarative-devel kf6-kirigami-devel mpv
```

#### Ubuntu / Debian:
```bash
sudo apt update
sudo apt install golang-go python3 python3-pyqt6 qml-module-org-kde-kirigami2 mpv
```

---

## 🚀 Installation & Usage

### 1. Clone the Repository
```bash
git clone https://github.com/MicahWade/BigFin.git
cd BigFin
```

### 2. Build Go Binaries
```bash
make build
```

### 3. Launch Bigfin
You can launch Bigfin directly using the launcher script:
```bash
./run_bigfin.sh
```
*Note: Running `run_bigfin.sh` automatically installs desktop entries (`bigfin.desktop`) and icons into `~/.local/share/applications/` so Bigfin appears in your system application menu.*

---

## 🎮 Remote & D-Pad Keyboard Navigation

Bigfin is engineered for seamless operation using a TV D-Pad remote or keyboard:

| Action | Keyboard Key | D-Pad / Remote |
| :--- | :--- | :--- |
| **Navigate Options** | `Arrow Keys` (`Up`, `Down`, `Left`, `Right`) | `D-Pad Directional` |
| **Select / Activate** | `Enter` / `Return` | `Select` / `OK` |
| **Play / Pause Video** | `Spacebar` / `P` | `Play / Pause` |
| **Seek Forward (+10s)** | `Right Arrow` (in playback) | `Fast Forward` |
| **Seek Backward (-10s)**| `Left Arrow` (in playback) | `Rewind` |
| **Back / Exit View** | `Escape` / `Backspace` | `Back` |
| **Toggle OSD / HUD** | `D` | `Info` / `Menu` |
| **Session Switcher** | `S` | `Yellow Button` |

---

## 🧪 Testing & Verification

Bigfin includes test suites for Go engine logic, API communication, and UI compilation.

### Run Go Unit Tests
```bash
make test
```

### Run Live Jellyfin Stream Verification (Optional)
To test streaming against an active Jellyfin server:
```bash
JELLYFIN_TEST_SERVER="http://your-server:8096" JELLYFIN_TEST_TOKEN="your-token" go test -v ./pkg/player
```

### Run Python & QML UI Verification
```bash
make test-ui
```

---

## 🛠️ Configuration & Storage

Bigfin stores application state locally:

- **Sessions & Server Config**: `~/.config/bigfin/sessions.json`
- **Cached Images & Posters**: `~/.cache/bigfin/images/`

---

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) for developer setup details and code submission guidelines.

---

## 📄 License

Bigfin is released under the GPL-3.0 License. See the [LICENSE](LICENSE) file for more details.