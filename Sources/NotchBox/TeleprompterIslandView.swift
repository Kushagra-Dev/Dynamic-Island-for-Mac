import SwiftUI

struct TeleprompterIslandView: View {
    @ObservedObject var manager: TeleprompterManager
    @ObservedObject var islandManager: IslandManager
    let expandedWidth: CGFloat = LayoutConstants.expandedWidth + 70
    @State private var lastDragValue: CGFloat = 0
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)
                    Text("TELEPROMPTER")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .kerning(1.0)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                
                Spacer()
                
                InteractiveButton(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill", size: 18) {
                    withAnimation {
                        isEditing.toggle()
                        if isEditing {
                            manager.isPlaying = false // pause when editing
                        }
                    }
                }
                .padding(.trailing, 8)
                .foregroundColor(isEditing ? .green : .white)
                
                InteractiveButton(systemName: islandManager.isSwipingLocked ? "lock.fill" : "lock.open.fill", size: 18) {
                    islandManager.isSwipingLocked.toggle()
                    islandManager.isLockedExpanded = islandManager.isSwipingLocked
                }
                .padding(.trailing, 8)
                .foregroundColor(islandManager.isSwipingLocked ? .orange : .white)
                
                // Speed Scrubber
                SpeedScrubberView(speed: $manager.scrollSpeed, range: 2...200)
                
                // Play/Pause Control
                InteractiveButton(systemName: manager.isPlaying ? "pause.circle.fill" : "play.circle.fill", size: 18) {
                    manager.togglePlayPause()
                }
                
                InteractiveButton(systemName: "arrow.counterclockwise.circle.fill", size: 18) {
                    manager.reset()
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 38)
            .padding(.bottom, 10)
            
            if isEditing {
                // Edit Mode UI
                VStack(spacing: 12) {
                    TextEditor(text: $manager.text)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(height: 120)
                    
                    
                    // No slider in edit mode since we have the dynamic scrubber in the header
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            } else {
                // Scrolling Text Area
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Text(manager.text)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .frame(width: geo.size.width, alignment: .top)
                        .background(
                            GeometryReader { textGeo in
                                Color.clear.onAppear {
                                    manager.maxScrollOffset = max(0, textGeo.size.height + 45)
                                }
                                .onChange(of: textGeo.size.height) { newHeight in
                                    manager.maxScrollOffset = max(0, newHeight + 45)
                                }
                            }
                        )
                        .offset(y: 45 - manager.scrollOffset)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .contentShape(Rectangle())
                .clipped()
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if abs(value.translation.height) > abs(value.translation.width) {
                                if lastDragValue == 0 {
                                    lastDragValue = manager.scrollOffset
                                }
                                manager.scrollOffset = max(0, min(manager.maxScrollOffset, lastDragValue - value.translation.height))
                            }
                        }
                        .onEnded { _ in
                            lastDragValue = 0
                        }
                )
            }
            .frame(height: 220)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.2),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                // Scrubbable Progress Bar moved outside the mask so it remains clickable
                GeometryReader { barGeo in
                    let totalHeight = max(1, manager.maxScrollOffset + 140)
                    let barHeight = max(10, barGeo.size.height * (barGeo.size.height / totalHeight))
                    let barOffset = (manager.scrollOffset / max(1, manager.maxScrollOffset)) * (barGeo.size.height - barHeight)
                    
                    ZStack(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 6, height: barGeo.size.height)
                        
                        Capsule()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 6, height: barHeight)
                            .offset(y: barOffset.isNaN ? 0 : barOffset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill the 20px hit area
                    .contentShape(Rectangle()) // Make entire area clickable
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let progress = min(1, max(0, value.location.y / barGeo.size.height))
                                manager.scrollOffset = progress * manager.maxScrollOffset
                            }
                    )
                }
                .frame(width: 20) // wider hit area for dragging
                .padding(.trailing, 8)
                .padding(.vertical, 8),
                
                alignment: .trailing
            )
            .padding(.bottom, 22)
            }
        }
        .frame(width: expandedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.black)
    }
}
