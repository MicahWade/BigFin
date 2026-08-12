package main

/*
#cgo CXXFLAGS: -std=c++17 -I/usr/include/qt6 -I/usr/include/qt6/QtCore -I/usr/include/qt6/QtGui -I/usr/include/qt6/QtQml -I/usr/include/qt6/QtNetwork -I/usr/include/qt6/QtDBus
#cgo LDFLAGS: -lQt6Qml -lQt6Gui -lQt6Core -lQt6Network -lQt6DBus
#include "qml_bridge.h"
#include <stdlib.h>
*/
import "C"
import "unsafe"

func launchNativeQtQml(qmlPath string) int {
	cPath := C.CString(qmlPath)
	defer C.free(unsafe.Pointer(cPath))
	return int(C.LaunchNativeQtQml(cPath))
}
