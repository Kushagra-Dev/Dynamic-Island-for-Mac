import SwiftUI
import Combine

struct ScrubberView: View {
    var currentTime: Double
    var isPlaying: Bool
    let duration: Double
    let onSeek: (Double) -> Void
    @ObservedObject var islandManager: IslandManager
    
    @State private var localTime: Double = 0
    @State private var isDragging: Bool = false
    @State private var dragTime: Double = 0
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private var progress: Double {
        if duration <= 0 { return 0 }
        let time = isDragging ? dragTime : localTime
        return min(max(time / duration, 0), 1)
    }
    
    private func formatTime(_ time: Double) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(formatTime(isDragging ? dragTime : localTime))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 36, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: isDragging ? 10 : 6)
                        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: isDragging)
                    
                    // Progress fill
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(geometry.size.width * CGFloat(progress), 0), height: isDragging ? 10 : 6)
                        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: isDragging)
                    
                    // Invisible hit area for easier dragging
                    Rectangle()
                        .fill(Color.black.opacity(0.001))
                        .frame(height: 24)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    islandManager.isSwipingLocked = true
                                    let percent = value.location.x / geometry.size.width
                                    dragTime = min(max(Double(percent) * duration, 0), duration)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    islandManager.isSwipingLocked = false
                                    localTime = dragTime // Instantly update locally to avoid jumping
                                    onSeek(dragTime)
                                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                                }
                        )
                }
                .frame(height: geometry.size.height, alignment: .center)
            }
            .frame(height: 24) // Total height of the scrubber area including hit box
            
            Text("-" + formatTime(duration - (isDragging ? dragTime : localTime)))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 40, alignment: .trailing)
        }
        .onReceive(timer) { _ in
            guard isPlaying, !isDragging, localTime < duration else { return }
            localTime += 0.1
        }
        .onChange(of: currentTime) { newTime in
            // When MusicController sends a completely new authoritative time, sync up!
            if !isDragging && abs(localTime - newTime) > 1.5 {
                localTime = newTime
            }
        }
        .onAppear {
            localTime = currentTime
        }
    }
}
