import Foundation
import Combine
import SwiftUI

enum IslandMode: Hashable, Equatable {
    case music
    case time
    case weather
    case alert(title: String, systemImage: String)
    case teleprompter
}

class IslandManager: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var islandFrame: CGRect = .zero
    @Published var currentMode: IslandMode = .music
    @Published var transitionEdge: Edge = .trailing
    @Published var dynamicHeight: CGFloat = 194.0
    @Published var isLockedExpanded: Bool = false
    @Published var isSwipingLocked: Bool = false
    
    init() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleIdentifier = app.bundleIdentifier else { return }
            
            switch bundleIdentifier {
            case "com.apple.Music", "com.spotify.client":
                self.startLiveActivity(mode: .music)
            case "com.apple.weather":
                self.startLiveActivity(mode: .weather)
            default:
                break
            }
        }
        
        setupMouseTracking()
    }
    
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private func setupMouseTracking() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved]
        
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseMoved(location: NSEvent.mouseLocation)
        }
        
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseMoved(location: NSEvent.mouseLocation)
            return event
        }
    }
    
    private func handleMouseMoved(location: NSPoint) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        
        // Convert to top-left origin for easier math
        let yFromTop = screen.frame.height - location.y
        let x = location.x
        
        let expandedWidth: CGFloat = currentMode == .teleprompter ? (LayoutConstants.expandedWidth + 70) : LayoutConstants.expandedWidth
        let collapsedWidth: CGFloat = LayoutConstants.collapsedWidth
        let currentWidth = isExpanded ? expandedWidth : collapsedWidth
        
        let minX = screen.frame.midX - (currentWidth / 2) - 20
        let maxX = screen.frame.midX + (currentWidth / 2) + 20
        
        // Use a uniform hover height when expanded to prevent accidental collapses when swiping between modes of different heights.
        // We use the dynamicHeight plus some padding to accommodate all views like the Timer.
        let hoverHeight = isExpanded ? max(215.0, self.dynamicHeight + 20.0) : 44.0
        
        let isHovering = x >= minX && x <= maxX && yFromTop >= 0 && yFromTop <= hoverHeight
        
        if isHovering {
            if !isExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isExpanded = true
                }
            }
        } else {
            if isExpanded && !isLockedExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            }
        }// Define INTERACTIVE bounds for click-through
        var visualHeight: CGFloat = LayoutConstants.collapsedHeight
        if isExpanded {
            visualHeight = self.dynamicHeight + 10.0 // Add slight padding for interactive bounds
        }
        let updatedWidth = isExpanded ? expandedWidth : collapsedWidth
        let currentMinX = screen.frame.midX - (updatedWidth / 2.0)
        let currentMaxX = screen.frame.midX + (updatedWidth / 2.0)
        
        let isInsideVisual = x >= currentMinX && x <= currentMaxX && yFromTop >= 0 && yFromTop <= visualHeight
        
        // If the mouse is OUTSIDE the visual bounds, tell the window to ignore mouse events!
        // This instantly lets the user click apps behind the invisible 420x300 window!
        NotificationCenter.default.post(name: NSNotification.Name("UpdateIgnoresMouseEvents"), object: !isInsideVisual)
    }
    
    // Stack of active background activities
    private var activeActivities: [IslandMode] = []
    
    private var lastActiveMode: IslandMode = .music
    private var alertTimer: AnyCancellable?
    
    func modeIndex(_ mode: IslandMode) -> Int {
        switch mode {
        case .music: return 0
        case .time: return 1
        case .weather: return 2
        case .teleprompter: return 3
        case .alert: return 0
        }
    }
    
    func switchTo(mode: IslandMode) {
        let currentIdx = modeIndex(currentMode)
        let targetIdx = modeIndex(mode)
        if targetIdx != currentIdx {
            transitionEdge = targetIdx > currentIdx ? .trailing : .leading
        }
        self.currentMode = mode
    }
    
    func showAlert(title: String, systemImage: String, duration: TimeInterval = 3.0) {
        // Don't interrupt an existing alert
        if case .alert = currentMode { return }
        
        lastActiveMode = currentMode
        switchTo(mode: .alert(title: title, systemImage: systemImage))
        
        alertTimer?.cancel()
        alertTimer = Just(())
            .delay(for: .seconds(duration), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.switchTo(mode: self.lastActiveMode)
            }
    }
    
    // Live Activity API
    func startLiveActivity(mode: IslandMode) {
        if !activeActivities.contains(mode) {
            activeActivities.append(mode)
        }
        switchTo(mode: mode)
    }
    
    func endLiveActivity(mode: IslandMode) {
        activeActivities.removeAll { $0 == mode }
        if let nextMode = activeActivities.last {
            switchTo(mode: nextMode)
        } else {
            switchTo(mode: .music)
        }
    }
    
    // MARK: - Swipe Navigation
    var swipableModes: [IslandMode] {
        return [.music, .time, .weather, .teleprompter]
    }
    
    func swipeNext() {
        let modes = swipableModes
        let currentIndex = modeIndex(currentMode)
        let nextIndex = (currentIndex + 1) % modes.count
        transitionEdge = .trailing
        self.currentMode = modes[nextIndex]
    }
    
    func swipePrevious() {
        let modes = swipableModes
        let currentIndex = modeIndex(currentMode)
        let prevIndex = (currentIndex - 1 + modes.count) % modes.count
        transitionEdge = .leading
        self.currentMode = modes[prevIndex]
    }
}
