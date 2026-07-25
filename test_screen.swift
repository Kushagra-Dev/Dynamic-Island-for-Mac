import AppKit

let screens = NSScreen.screens
for screen in screens {
    print("Screen:")
    print("  frame: \(screen.frame)")
    print("  visibleFrame: \(screen.visibleFrame)")
    print("  safeAreaInsets: \(screen.safeAreaInsets)")
}
