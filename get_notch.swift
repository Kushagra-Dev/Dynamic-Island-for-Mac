import AppKit

let app = NSApplication.shared
if let screen = NSScreen.screens.first {
    print("Screen frame: \(screen.frame)")
    print("Screen visibleFrame: \(screen.visibleFrame)")
    if #available(macOS 12.0, *) {
        print("Safe Area Insets: \(screen.safeAreaInsets)")
        print("Auxiliary Top Left Area: \(screen.auxiliaryTopLeftArea?.debugDescription ?? "none")")
        print("Auxiliary Top Right Area: \(screen.auxiliaryTopRightArea?.debugDescription ?? "none")")
    }
} else {
    print("No screens found")
}
