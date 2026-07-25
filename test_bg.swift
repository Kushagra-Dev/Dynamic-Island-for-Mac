import SwiftUI
import AppKit

struct ContentView: View {
    @State var isExpanded = false
    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                Text("Content")
            }
            .frame(width: 200, height: 200)
            .opacity(isExpanded ? 1 : 0)
        }
        .frame(width: isExpanded ? 200 : 185)
        .frame(minHeight: 32, maxHeight: isExpanded ? .infinity : 32, alignment: .top)
        .background(Color.black)
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
window.isOpaque = false
window.backgroundColor = .clear
window.contentView = NSHostingView(rootView: ContentView())
window.makeKeyAndOrderFront(nil)

// Capture image
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    if let cgImage = window.contentView?.bitmapImageRepForCachingDisplay(in: window.contentView!.bounds) {
        window.contentView?.cacheDisplay(in: window.contentView!.bounds, to: cgImage)
        let props = [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]
        if let data = cgImage.representation(using: .png, properties: props) {
            try? data.write(to: URL(fileURLWithPath: "test_bg.png"))
        }
    }
    NSApplication.shared.terminate(nil)
}
NSApplication.shared.run()
