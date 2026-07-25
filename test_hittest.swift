import Cocoa
import SwiftUI

class TestView: NSHostingView<AnyView> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        print("hitTest received point: \(point)")
        let localPoint = self.convert(point, from: self.superview)
        print("localPoint: \(localPoint)")
        return super.hitTest(point)
    }
}

let app = NSApplication.shared
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300), styleMask: .borderless, backing: .buffered, defer: false)
let hostingView = TestView(rootView: AnyView(Color.black.frame(width: 420, height: 300)))
hostingView.frame = NSRect(x: 0, y: 0, width: 420, height: 300)
window.contentView = hostingView

// Let's simulate a click at the TOP of the window
// In Cocoa, the window's coordinate system originates at the BOTTOM-LEFT.
// So the top of a 300pt tall window is y = 300.
// A point just below the top (e.g. 10 points down) is y = 290.
let topPoint = NSPoint(x: 210, y: 290)
print("Simulating click at window point (from bottom-left): \(topPoint)")

let hit = hostingView.hitTest(topPoint)
print("Hit result: \(hit != nil)")

