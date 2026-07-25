import Foundation
import Combine
import SwiftUI

class TeleprompterManager: ObservableObject {
    @Published var text: String = "Welcome to the Notch Teleprompter!\n\nPaste your script here and use the controls to adjust the scrolling speed.\n\nEnjoy a seamless reading experience right from your dynamic island!"
    @Published var scrollSpeed: Double = 30.0 // Pixels per second
    @Published var isPlaying: Bool = false
    @Published var scrollOffset: CGFloat = 0.0
    
    @Published var maxScrollOffset: CGFloat = 1000.0 // Set by view
    
    private var timer: AnyCancellable?
    private var lastTick: Date?
    
    func togglePlayPause() {
        if scrollOffset >= maxScrollOffset && !isPlaying {
            scrollOffset = 0 // Restart if at the end
        }
        isPlaying.toggle()
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    func reset() {
        stopTimer()
        isPlaying = false
        scrollOffset = 0.0
    }
    
    private func startTimer() {
        lastTick = Date()
        timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common) // 60 FPS
            .autoconnect()
            .sink { [weak self] now in
                guard let self = self, let last = self.lastTick else { return }
                let elapsed = now.timeIntervalSince(last)
                self.lastTick = now
                
                // Increase scroll offset (which moves text up)
                self.scrollOffset += CGFloat(self.scrollSpeed * elapsed)
                
                if self.scrollOffset >= self.maxScrollOffset {
                    self.scrollOffset = self.maxScrollOffset
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
        lastTick = nil
    }
}
