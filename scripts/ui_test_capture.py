#!/usr/bin/env python3
import sys
import os
import time

from PyQt6.QtCore import QUrl, QTimer, Qt
from PyQt6.QtGui import QGuiApplication, QKeyEvent, QIcon
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtQuick import QQuickWindow

def main():
    print("==================================================")
    print(" Bigfin Headless UI Verification & Screenshot Capture")
    print("==================================================")

    os.environ["QT_QPA_PLATFORM"] = "offscreen"

    app = QGuiApplication(sys.argv)
    app.setOrganizationName("Bigfin")
    app.setOrganizationDomain("bigfin.org")
    app.setApplicationName("org.bigfin.client")
    app.setDesktopFileName("org.bigfin.client")

    # Project root directory (one level up from scripts/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    logo_path = os.path.join(project_root, 'Logo.png')
    if os.path.exists(logo_path):
        app.setWindowIcon(QIcon(logo_path))

    engine = QQmlApplicationEngine()

    qml_dir = os.path.join(project_root, 'ui', 'qml')
    engine.addImportPath(qml_dir)

    for path in ['/usr/lib64/qt6/qml', '/usr/lib/qt6/qml', '/usr/lib/qt5/qml']:
        if os.path.exists(path):
            engine.addImportPath(path)

    qml_file = os.path.join(qml_dir, 'tst_VisualNavigation.qml')
    engine.load(QUrl.fromLocalFile(qml_file))

    if not engine.rootObjects():
        print("[!] QML Engine failed to load root window.")
        sys.exit(-1)

    window = engine.rootObjects()[0]
    if isinstance(window, QQuickWindow):
        window.show()

    output_dir = os.environ.get("UI_CAPTURE_DIR", os.path.join(project_root, "screenshots"))
    os.makedirs(output_dir, exist_ok=True)

    def capture_step(filename):
        if isinstance(window, QQuickWindow):
            img = window.grabWindow()
            out_path = os.path.join(output_dir, filename)
            img.save(out_path)
            print(f"[SUCCESS] Saved UI Screenshot: {out_path}")

    def step1_home_screen():
        capture_step("home_view_updated.png")
        app.quit()

    QTimer.singleShot(800, step1_home_screen)
    app.exec()

if __name__ == '__main__':
    main()
