import Cocoa
import SwiftUI
import Combine

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    var window: NotchWindow!
    static weak var sharedWindow: NotchWindow?
    
    // Shared State Objects
    let musicController = MusicController()
    let islandManager = IslandManager()
    let timeManager = TimeManager()
    let weatherManager = WeatherManager()
    
    var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let notchRect = NotchGeometry.getNotchRect()
        let expandedWidth: CGFloat = LayoutConstants.expandedWidth
        let expandedHeight: CGFloat = 300 // Increased bounding box to allow for dynamic heights!
        
        let windowRect = NSRect(
            x: notchRect.midX - (expandedWidth / 2),
            y: notchRect.maxY - expandedHeight,
            width: expandedWidth,
            height: expandedHeight
        )
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView(
            musicController: musicController,
            islandManager: islandManager,
            timeManager: timeManager,
            weatherManager: weatherManager
        )
        
        // Create the custom window with the exact notch size
        window = NotchWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure the window
        window.isOpaque = false
        window.backgroundColor = .clear
        // Using maximumWindow level ensures it sits securely on top of the menu bar natively
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.hasShadow = false
        window.ignoresMouseEvents = false // We need to detect hover
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        // Position window at the top of the screen centered on the notch
        window.setFrameOrigin(windowRect.origin)
        
        AppDelegate.sharedWindow = window
        
        // Add the SwiftUI view using our custom hit-testing host view
        let hostingView = PassThroughHostingView(rootView: contentView)
        hostingView.islandManager = islandManager
        
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenRect = screen.frame
        
        let width = expandedWidth
        let height = expandedHeight
        let x = screenRect.midX - (width / 2.0)
        let y = screenRect.maxY - height
        let newFrame = NSRect(x: x, y: y, width: width, height: height)
        window.setFrame(newFrame, display: true)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("UpdateIgnoresMouseEvents"), object: nil, queue: .main) { [weak window] notification in
            if let shouldIgnore = notification.object as? Bool {
                if window?.ignoresMouseEvents != shouldIgnore {
                    window?.ignoresMouseEvents = shouldIgnore
                }
            }
        }
        
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        
        // Force the app to activate and come to the front
        NSApp.activate(ignoringOtherApps: true)
        
        // Hide the app from the Dock
        NSApp.setActivationPolicy(.accessory)
        
        print("Window positioned at: \\(window.frame)")
    }
}

// Custom window to allow clicking through transparent areas if needed
class NotchWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // CRITICAL: Prevent macOS from constraining the window below the menu bar
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

// Custom NSHostingView that dynamically ignores clicks on its transparent background
class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    weak var islandManager: IslandManager?
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Find which view was hit
        let view = super.hitTest(point)
        
        guard let manager = islandManager else {
            return view
        }
        
        // Convert point to local coordinates (origin at top-left because NSHostingView is flipped)
        let localPoint = self.convert(point, from: self.superview)
        
        let collapsedWidth: CGFloat = 185
        let collapsedHeight: CGFloat = 38
        
        let isExpanded = manager.isExpanded
        let width = isExpanded ? LayoutConstants.expandedWidth : collapsedWidth
        
        let viewWidth = self.bounds.width
        
        // Compute the EXACT visual height based on the dynamic intrinsic height so we don't hoard clicks below the island
        var visualHeight: CGFloat = collapsedHeight
        if isExpanded {
            visualHeight = manager.dynamicHeight
        }
        
        let minX = (viewWidth - width) / 2.0
        let maxX = minX + width
        let minY = 0.0
        let maxY = visualHeight
        
        let contains = localPoint.x >= minX && localPoint.x <= maxX && localPoint.y >= minY && localPoint.y <= maxY
        
        FileLogger.shared.log("hitTest: point=\(point), localPoint=\(localPoint), expanded=\(isExpanded), bounds=\(minX)...\(maxX), \(minY)...\(maxY), contains=\(contains), superViewResult=\(view != nil)")
        
        // Check if the click is inside the island's actual visual bounds
        if contains {
            return view // Keep the click
        }
        
        // Otherwise, drop the click so it passes through the transparent window to the menu bar/other apps!
        return nil
    }
}

// Helper to dynamically calculate notch geometry
struct NotchGeometry {
    static func getNotchRect() -> NSRect {
        let screen = NSScreen.screens.first(where: {
            if #available(macOS 12.0, *) {
                return $0.auxiliaryTopLeftArea != nil
            }
            return false
        }) ?? NSScreen.main ?? NSScreen.screens.first
        
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1512, height: 982)
        
        if #available(macOS 12.0, *) {
            if let s = screen,
               let leftArea = s.auxiliaryTopLeftArea,
               let rightArea = s.auxiliaryTopRightArea {
                let leftWidth = leftArea.width
                let rightWidth = rightArea.width
                let notchWidth = screenFrame.width - leftWidth - rightWidth
                let notchHeight: CGFloat = s.safeAreaInsets.top > 0 ? s.safeAreaInsets.top : 38
                
                let x = screenFrame.origin.x + leftWidth
                let y = screenFrame.maxY - notchHeight
                return NSRect(x: x, y: y, width: notchWidth, height: notchHeight)
            }
        }
        
        // Fallback for non-notched Macs or external monitors
        let fallbackWidth: CGFloat = 185
        let fallbackHeight: CGFloat = 38
        return NSRect(
            x: screenFrame.origin.x + (screenFrame.width - fallbackWidth) / 2.0,
            y: screenFrame.maxY - fallbackHeight,
            width: fallbackWidth,
            height: fallbackHeight
        )
    }
}
