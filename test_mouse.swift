import Cocoa

let monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { event in
    print("Moved: \(NSEvent.mouseLocation)")
}
print("Monitor set: \(monitor != nil)")
