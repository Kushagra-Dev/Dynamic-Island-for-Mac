import SwiftUI

struct MusicIslandView: View {
    @ObservedObject var musicController: MusicController
    @Binding var showingVolume: Bool
    
    let expandedWidth: CGFloat = LayoutConstants.expandedWidth
    let expandedHeight: CGFloat = LayoutConstants.expandedHeight
    let collapsedHeight: CGFloat = NotchGeometry.getNotchRect().height
    
    var body: some View {
        // Content VStack is the SOLE layout driver — its intrinsic height determines the island size.
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                // Album Art
                if let artwork = musicController.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: expandedHeight * 0.4, height: expandedHeight * 0.4)
                        .clipShape(RoundedRectangle(cornerRadius: expandedHeight * 0.1, style: .continuous))
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
                } else {
                    RoundedRectangle(cornerRadius: expandedHeight * 0.1, style: .continuous)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: expandedHeight * 0.4, height: expandedHeight * 0.4)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                // Track Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(musicController.trackName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(musicController.artistName)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Animated Waveform
                WaveformView(isPlaying: musicController.isPlaying, color: musicController.dominantColor)
                    .frame(width: 44, height: 32)
            }
            .padding(.horizontal, 24)
            .padding(.top, 38)
            
            if showingVolume {
                VolumeScrubberView(
                    volume: musicController.volume,
                    onSeek: { newVol in
                        musicController.setVolume(newVol)
                    }
                )
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                ScrubberView(
                    currentTime: musicController.currentTime,
                    isPlaying: musicController.isPlaying,
                    duration: musicController.duration,
                    onSeek: { newTime in
                        musicController.seek(to: newTime)
                    }
                )
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
                            
            // Controls
            ZStack {
                HStack(spacing: 40) {
                    InteractiveButton(systemName: "backward.fill", size: 20) {
                        musicController.previousTrack()
                    }
                    
                    InteractiveButton(systemName: musicController.isPlaying ? "pause.fill" : "play.fill", size: 28) {
                        musicController.togglePlayPause()
                    }
                    
                    InteractiveButton(systemName: "forward.fill", size: 20) {
                        musicController.nextTrack()
                    }
                }
                
                // Volume Toggle Button
                HStack {
                    Spacer()
                    InteractiveButton(systemName: showingVolume ? "music.note" : "speaker.wave.2.fill", size: 16) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingVolume.toggle()
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 6) // Reduced padding for compactness
        }
        .padding(.bottom, 10) // Reduced overall padding to make it compact
        .frame(width: expandedWidth)
        // Blurred artwork glow as BACKGROUND
        .background(
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // 1. SOLID BLACK BASE
                    Color.black
                    
                    // 2. Artwork glow ON TOP
                    if let artwork = musicController.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .blur(radius: 40)
                            .opacity(0.8)
                        
                        // 3. PURE BLACK OVERLAY AT TOP TO HIDE PHYSICAL NOTCH
                        // The macOS notch is 38 points tall. We ensure the top 44 points are pitch black
                        // and then fade out into the artwork theme.
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 44) // fully black to hide notch
                            
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black.opacity(0.8), location: 0.15),
                                    .init(color: .black.opacity(0.4), location: 0.5),
                                    .init(color: .clear, location: 0.9)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    }
                }
            }
            .clipped()
        )
    }
}
