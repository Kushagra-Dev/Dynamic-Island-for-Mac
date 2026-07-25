import SwiftUI
import AppKit

struct LyricsScrollerView: View {
    @ObservedObject var musicController: MusicController
    
    @State private var isUserScrolling = false
    @State private var scrollingTimer: Timer? = nil
    @State private var eventMonitor: Any?
    @State private var isHovering = false
    @State private var lastActivationTime: Date = Date.distantPast
    
    // Find the currently active lyric line
    private var activeIndex: Int {
        let time = musicController.currentTime
        let lines = musicController.lyrics
        // Find the last lyric line where its time is less than or equal to current time
        var active = -1
        for (index, line) in lines.enumerated() {
            if line.time <= time + 0.2 { // Add 0.2s buffer to perfectly sync with singing
                active = index
            } else {
                break
            }
        }
        return active
    }
    
    var body: some View {
        VStack {
            if musicController.isFetchingLyrics {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if musicController.lyricsUnavailable || musicController.lyrics.isEmpty {
                Text("Lyrics unavailable for this song")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .center, spacing: 14) {
                            // Top padding so first lyric can be perfectly centered
                            Color.clear.frame(height: 100)
                            
                            ForEach(Array(musicController.lyrics.enumerated()), id: \.element.id) { index, line in
                                let isActive = index == activeIndex
                                let isPast = index < activeIndex
                                
                                Text(line.text)
                                    .font(.system(size: isActive ? 22 : 18, weight: isActive ? .bold : .medium, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white.opacity(isActive ? 1.0 : (isPast ? 0.2 : 0.6)))
                                    .scaleEffect(isActive ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isActive)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isUserScrolling = false
                                        scrollingTimer?.invalidate()
                                        musicController.seek(to: line.time)
                                    }
                                    .id(index)
                            }
                            
                            // Bottom padding so last lyric can be perfectly centered
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .onHover { hovering in
                        isHovering = hovering
                    }
                    .onChange(of: activeIndex) { newIndex in
                        if newIndex >= 0 && !isUserScrolling {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        // Reset scrolling state so we don't get stuck from previous interactions
                        isUserScrolling = false
                        scrollingTimer?.invalidate()
                        
                        if activeIndex >= 0 {
                            // Continuously update the scroll position during the window expansion animation
                            // to ensure the active lyric stays perfectly anchored in the center of the growing view.
                            let expansionDuration = 0.5
                            let fps = 60.0
                            let interval = 1.0 / fps
                            var elapsed = 0.0
                            
                            Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                                elapsed += interval
                                // Always force scroll during expansion
                                proxy.scrollTo(activeIndex, anchor: .center)
                                
                                if elapsed >= expansionDuration {
                                    timer.invalidate()
                                    // Final polish with a spring animation
                                    DispatchQueue.main.async {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            proxy.scrollTo(activeIndex, anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Only catch scroll wheel events to avoid catching the initial click that opens the notch
                        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { event in
                            // Ignore scroll events within 0.5s of space switch (filters out space-switching trackpad swipes)
                            let isRecentSpaceSwitch = Date().timeIntervalSince(lastActivationTime) < 0.5
                            
                            if isHovering && !isRecentSpaceSwitch {
                                let dy = abs(event.scrollingDeltaY)
                                let dx = abs(event.scrollingDeltaX)
                                // Only count predominantly vertical scrolls as lyric interactions (filters horizontal space swipes)
                                if dy > 2 && dy > dx * 1.2 {
                                    userDidInteract(proxy: proxy)
                                }
                            }
                            return event
                        }
                    }
                    .onDisappear {
                        if let monitor = eventMonitor {
                            NSEvent.removeMonitor(monitor)
                            eventMonitor = nil
                        }
                    }
                    .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
                        lastActivationTime = Date()
                    }
                }
            }
        }
        .frame(height: 220)
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.15),
                    .init(color: .black, location: 0.85),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func userDidInteract(proxy: ScrollViewProxy) {
        isUserScrolling = true
        scrollingTimer?.invalidate()
        scrollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            isUserScrolling = false
            // Once the user stops scrolling for 3 seconds, snap immediately back to the current active lyric!
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    proxy.scrollTo(activeIndex, anchor: .center)
                }
            }
        }
    }
}
