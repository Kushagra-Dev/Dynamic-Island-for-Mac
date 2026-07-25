import SwiftUI

struct SpeedScrubberView: View {
    @Binding var speed: Double
    let range: ClosedRange<Double>
    
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false
    @State private var dragSpeed: Double = 0
    
    private var progress: Double {
        let currentSpeed = isDragging ? dragSpeed : speed
        // Inverse of quadratic mapping to find the scrubber position (0...1)
        let normalized = (currentSpeed - range.lowerBound) / (range.upperBound - range.lowerBound)
        return sqrt(max(0, normalized))
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hare.fill")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(isHovering || isDragging ? 0.9 : 0.6))
            
            if isHovering || isDragging {
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
                        
                        // Invisible hit area
                        Rectangle()
                            .fill(Color.black.opacity(0.001))
                            .frame(height: 24)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDragging = true
                                        let percent = value.location.x / geometry.size.width
                                        let clampedPercent = min(max(Double(percent), 0), 1)
                                        // Quadratic mapping: lower half of the bar covers the lower 25% of the speed range
                                        dragSpeed = range.lowerBound + pow(clampedPercent, 2) * (range.upperBound - range.lowerBound)
                                        speed = dragSpeed // update instantly
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )
                    }
                    .frame(height: 24)
                }
                .frame(width: 80)
                .transition(.asymmetric(insertion: .scale(scale: 0.1, anchor: .leading).combined(with: .opacity), removal: .scale(scale: 0.1, anchor: .leading).combined(with: .opacity)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity((isHovering || isDragging) ? 0.15 : 0.0)))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
}
