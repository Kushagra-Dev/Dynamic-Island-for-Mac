import SwiftUI

struct ContentView: View {
    @State private var showingVolume = false
    @State private var showingLyrics = false
    @ObservedObject var musicController: MusicController
    @ObservedObject var islandManager: IslandManager
    @ObservedObject var timeManager: TimeManager
    @ObservedObject var weatherManager: WeatherManager
    @ObservedObject var teleprompterManager: TeleprompterManager
    
    @State private var isSwiping: Bool = false
    @State private var hasTriggeredPageSwitch: Bool = false
    @State private var dragOffset: CGFloat = 0
    
    // Exact notch size calculated dynamically
    let collapsedWidth: CGFloat = LayoutConstants.collapsedWidth
    let collapsedHeight: CGFloat = LayoutConstants.collapsedHeight
    
    private var currentExpandedWidth: CGFloat {
        if islandManager.currentMode == .teleprompter {
            return LayoutConstants.expandedWidth + 70
        }
        return LayoutConstants.expandedWidth
    }
    let expandedHeight: CGFloat = LayoutConstants.expandedHeight
    
    private var activePageIndex: Int {
        switch islandManager.currentMode {
        case .music: return 0
        case .time: return 1
        case .weather: return 2
        case .teleprompter: return 3
        case .alert: return 0
        }
    }
    
    @State private var intrinsicHeight: CGFloat = 160.0
    
    private var targetHeight: CGFloat {
        if !islandManager.isExpanded {
            return collapsedHeight
        }
        return intrinsicHeight
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // ==========================================
            // 1. HIDDEN MEASUREMENT LAYER
            // ==========================================
            // This layer is permanently expanded to measure the exact
            // natural height of the content. Because it never collapses,
            // it never triggers state changes during the contraction/expansion
            // animation, allowing SwiftUI's physics engine to run flawlessly.
            Group {
                switch islandManager.currentMode {
                case .music:
                    MusicIslandView(musicController: musicController, showingVolume: $showingVolume, showingLyrics: $showingLyrics, islandManager: islandManager)
                case .time:
                    TimeIslandView(timeManager: timeManager)
                case .weather:
                    WeatherIslandView(weatherManager: weatherManager)
                case .teleprompter:
                    TeleprompterIslandView(manager: teleprompterManager, islandManager: islandManager)
                case .alert(let title, let systemImage):
                    AlertIslandView(title: title, systemImage: systemImage)
                }
            }
            .frame(width: currentExpandedWidth)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(ViewHeightKey.self) { height in
                DispatchQueue.main.async {
                    let newHeight = max(height, 100)
                    if abs(self.intrinsicHeight - newHeight) > 1.0 {
                        self.intrinsicHeight = newHeight
                        self.islandManager.dynamicHeight = newHeight
                    }
                }
            }
            .opacity(0)
            .allowsHitTesting(false)
            
            // ==========================================
            // 2. VISIBLE INTERACTIVE LAYER
            // ==========================================
            ZStack(alignment: .top) {
                Group {
                    switch islandManager.currentMode {
                    case .music:
                        MusicIslandView(musicController: musicController, showingVolume: $showingVolume, showingLyrics: $showingLyrics, islandManager: islandManager)
                    case .time:
                        TimeIslandView(timeManager: timeManager)
                    case .weather:
                        WeatherIslandView(weatherManager: weatherManager)
                    case .teleprompter:
                        TeleprompterIslandView(manager: teleprompterManager, islandManager: islandManager)
                    case .alert(let title, let systemImage):
                        AlertIslandView(title: title, systemImage: systemImage)
                    }
                }
                .id(islandManager.currentMode)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: islandManager.transitionEdge).combined(with: .opacity),
                        removal: .move(edge: islandManager.transitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
                    )
                )
                .offset(x: dragOffset)
                
                // Page Indicator Dots (Music, Clock, Weather)
                if islandManager.isExpanded {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(Array(islandManager.swipableModes.enumerated()), id: \.offset) { idx, mode in
                                Capsule()
                                    .fill(activePageIndex == idx ? Color.white : Color.white.opacity(0.25))
                                    .frame(width: activePageIndex == idx ? 14 : 5, height: 5)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activePageIndex)
                            }
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }
                }
            }
            .contentShape(Rectangle()) // Helps with drag gesture hit testing
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if islandManager.isExpanded {
                            guard !hasTriggeredPageSwitch, !islandManager.isSwipingLocked else { return }
                            
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            
                            isSwiping = true
                            dragOffset = value.translation.width * 0.7
                            
                            let midSwipeThreshold: CGFloat = 15
                            if value.translation.width < -midSwipeThreshold {
                                hasTriggeredPageSwitch = true
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                    islandManager.swipeNext()
                                }
                            } else if value.translation.width > midSwipeThreshold {
                                hasTriggeredPageSwitch = true
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                    islandManager.swipePrevious()
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        if islandManager.isExpanded && !hasTriggeredPageSwitch {
                            guard !islandManager.isSwipingLocked, abs(value.translation.width) > abs(value.translation.height) else {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                }
                                hasTriggeredPageSwitch = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    isSwiping = false
                                }
                                return
                            }
                            
                            let translation = value.translation.width
                            let predicted = value.predictedEndTranslation.width
                            
                            let threshold: CGFloat = 8
                            let predictedThreshold: CGFloat = 15
                            
                            if translation < -threshold || predicted < -predictedThreshold {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                    islandManager.swipeNext()
                                }
                            } else if translation > threshold || predicted > predictedThreshold {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                    islandManager.swipePrevious()
                                }
                            } else {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                }
                            }
                        }
                        
                        hasTriggeredPageSwitch = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            isSwiping = false
                        }
                    }
            )
            .frame(width: currentExpandedWidth, height: intrinsicHeight, alignment: .top)
            .opacity(islandManager.isExpanded ? 1.0 : 0.0)
            .scaleEffect(islandManager.isExpanded ? 1.0 : 0.92, anchor: .top)
            .allowsHitTesting(islandManager.isExpanded)
        }
        .frame(width: islandManager.isExpanded ? currentExpandedWidth : collapsedWidth)
        .frame(height: targetHeight, alignment: .top)
        .background(Color.black)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: islandManager.isExpanded ? 40 : collapsedHeight * 0.5,
            bottomTrailingRadius: islandManager.isExpanded ? 40 : collapsedHeight * 0.5,
            topTrailingRadius: 0,
            style: .continuous
        ))
        .contentShape(UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: islandManager.isExpanded ? 40 : collapsedHeight * 0.5,
            bottomTrailingRadius: islandManager.isExpanded ? 40 : collapsedHeight * 0.5,
            topTrailingRadius: 0,
            style: .continuous
        ))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()

        .padding(.top, 0)
        .onAppear {
            musicController.updateNowPlaying()
        }
        .onChange(of: islandManager.isExpanded) { isExpanded in
            if isExpanded {
                musicController.updateNowPlaying()
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
            if islandManager.isExpanded {
                musicController.updateNowPlaying()
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: islandManager.isExpanded)
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: intrinsicHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: islandManager.currentMode)
        .onChange(of: timeManager.alarmRinging) { isRinging in
            islandManager.isLockedExpanded = isRinging
            if isRinging {
                DispatchQueue.main.async {
                    islandManager.switchTo(mode: .time)
                    if !islandManager.isExpanded {
                        islandManager.isExpanded = true
                    }
                }
            }
        }
        .onChange(of: timeManager.timerFinished) { isFinished in
            islandManager.isLockedExpanded = isFinished
            if isFinished {
                DispatchQueue.main.async {
                    islandManager.switchTo(mode: .time)
                    if !islandManager.isExpanded {
                        islandManager.isExpanded = true
                    }
                }
            }
        }
    }
}

// Removed IslandShape as we now use native RoundedRectangle with an overlay

// Interactive Button with Scale Effect
struct InteractiveButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size + 20, height: size + 20) // Generous hit area
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.85 : 1.0)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.5), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                action()
            })
            .simultaneousGesture(TapGesture().onEnded {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                action()
            })
    }
}

// Animated Waveform View
struct WaveformView: View {
    var isPlaying: Bool
    var color: Color
    
    @State private var heights: [CGFloat] = [6, 6, 6, 6]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(color)
                    .brightness(0.4) // Increased brightness further
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1) // Sharp border
                    )
                    .shadow(color: color, radius: 6) // Intense inner glow
                    .shadow(color: color.opacity(0.6), radius: 12) // Wide outer glow
                    .frame(width: 6, height: isPlaying ? heights[index] : 6)
                    .animation(.easeInOut(duration: 0.15), value: heights[index])
                    .animation(.easeInOut(duration: 0.15), value: isPlaying)
            }
        }
        .frame(height: 32)
        .task(id: isPlaying) {
            if isPlaying {
                while !Task.isCancelled {
                    for i in 0..<4 {
                        heights[i] = CGFloat.random(in: 8...32)
                    }
                    try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s
                }
            } else {
                heights = [6, 6, 6, 6]
            }
        }
    }
}
