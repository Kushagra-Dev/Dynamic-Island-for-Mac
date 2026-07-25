import SwiftUI
import AppKit

struct ContentView: View {
    @State var isExpanded = false
    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                Text("Hello World")
                Text("This is tall")
            }
            .frame(height: 200)
            .opacity(isExpanded ? 1 : 0)
        }
        .frame(width: 200, height: isExpanded ? nil : 32, alignment: .top)
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.blue.opacity(0.3)) // To see the window background
    }
}

let app = NSApplication.shared
let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 300, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.contentView = NSHostingView(rootView: ContentView())
window.makeKeyAndOrderFront(nil)

// Run the loop for 2 seconds then exit
DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
    NSApplication.shared.terminate(nil)
}
app.run()
