import SwiftUI

struct VolumeScrubberView: View {
    var volume: Double
    let onSeek: (Double) -> Void
    
    @State private var localVolume: Double = 0
    @State private var isDragging: Bool = false
    @State private var dragVolume: Double = 0
    
    private var progress: Double {
        let currentVol = isDragging ? dragVolume : localVolume
        return min(max(currentVol / 100.0, 0), 1)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 11, weight: .medium, design: .rounded))
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
                                    let percent = value.location.x / geometry.size.width
                                    dragVolume = min(max(Double(percent) * 100.0, 0), 100.0)
                                    onSeek(dragVolume) // update instantly
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    localVolume = dragVolume
                                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                                }
                        )
                }
                .frame(height: geometry.size.height, alignment: .center)
            }
            .frame(height: 24) // Total height of the scrubber area including hit box
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 40, alignment: .trailing)
        }
        .onChange(of: volume) { newVol in
            if !isDragging && abs(localVolume - newVol) > 2.0 {
                localVolume = newVol
            }
        }
        .onAppear {
            localVolume = volume
        }
    }
}
