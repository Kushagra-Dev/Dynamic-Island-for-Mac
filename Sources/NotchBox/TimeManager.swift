import Foundation
import Combine
import AppKit

enum TimeMode: String, Equatable, CaseIterable {
    case clock = "Clock"
    case stopwatch = "Stopwatch"
    case timer = "Timer"
}

class TimeManager: ObservableObject {
    @Published var activeMode: TimeMode = .clock
    
    // Global tick timer
    private var cancellable: AnyCancellable?
    private var timerSound: NSSound?
    
    // --- CLOCK STATE ---
    @Published var clockTimeString: String = ""
    @Published var clockDateString: String = ""
    @Published var clockSeconds: String = ""
    @Published var colonVisible: Bool = true
    
    // Cached formatters (created once, not every tick)
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()
    private let secondsFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ss"
        return f
    }()
    private let ampmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f
    }()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
    
    // --- STOPWATCH STATE ---
    @Published var stopwatchRunning: Bool = false
    @Published var stopwatchElapsed: TimeInterval = 0
    @Published var laps: [TimeInterval] = []
    private var stopwatchStartTime: Date?
    private var lapStartElapsed: TimeInterval = 0
    
    // --- TIMER STATE ---
    @Published var timerRunning: Bool = false
    @Published var timerRemaining: TimeInterval = 5 * 60
    @Published var timerInitial: TimeInterval = 5 * 60
    @Published var timerFinished: Bool = false
    private var timerEndTime: Date?
    
    // Colon blink timer
    private var colonTimer: AnyCancellable?
    
    init() {
        updateClock()
        cancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        
        // Blink the colon every 0.5 seconds for the clock
        colonTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.colonVisible.toggle()
            }
    }
    
    private var lastSecond: Int = -1
    
    private func tick() {
        let now = Date()
        let currentSecond = Int(now.timeIntervalSince1970)
        
        // Throttle string formatting to once per second (reduces @Published updates by 95%)
        if currentSecond != lastSecond {
            lastSecond = currentSecond
            updateClock(now: now)
        }
        
        if stopwatchRunning, let start = stopwatchStartTime {
            stopwatchElapsed = now.timeIntervalSince(start)
        }
        
        if timerRunning, let end = timerEndTime {
            let remaining = end.timeIntervalSince(now)
            if remaining <= 0 {
                timerRemaining = 0
                timerRunning = false
                timerFinished = true
                if let sound = NSSound(named: "Glass") {
                    sound.volume = 1.0
                    sound.loops = true
                    sound.play()
                    self.timerSound = sound
                } else {
                    NSSound.beep()
                }
            } else {
                timerRemaining = remaining
            }
        }
    }
    
    // --- MODE SWITCHING ---
    func setMode(_ mode: TimeMode) {
        activeMode = mode
    }
    
    func nextMode() {
        let all = TimeMode.allCases
        guard let idx = all.firstIndex(of: activeMode) else { return }
        let nextIdx = (idx + 1) % all.count
        setMode(all[nextIdx])
    }
    
    // --- CLOCK LOGIC ---
    private func updateClock(now: Date = Date()) {
        clockTimeString = timeFormatter.string(from: now)
        clockSeconds = secondsFormatter.string(from: now)
        clockDateString = dateFormatter.string(from: now)
    }
    
    var clockAMPM: String {
        ampmFormatter.string(from: Date())
    }
    
    // --- STOPWATCH LOGIC ---
    func stopwatchToggle() {
        if stopwatchRunning {
            stopwatchRunning = false
            stopwatchStartTime = nil
        } else {
            stopwatchRunning = true
            stopwatchStartTime = Date().addingTimeInterval(-stopwatchElapsed)
        }
    }
    
    func stopwatchReset() {
        stopwatchRunning = false
        stopwatchElapsed = 0
        stopwatchStartTime = nil
        laps.removeAll()
        lapStartElapsed = 0
    }
    
    func stopwatchLap() {
        guard stopwatchRunning else { return }
        let lapTime = stopwatchElapsed - lapStartElapsed
        laps.insert(lapTime, at: 0) // Most recent first
        lapStartElapsed = stopwatchElapsed
    }
    
    var stopwatchString: String {
        let minutes = Int(stopwatchElapsed) / 60
        let seconds = Int(stopwatchElapsed) % 60
        let centiseconds = Int((stopwatchElapsed.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
    
    func formatLapTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let centiseconds = Int((interval.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
    
    // --- TIMER LOGIC ---
    func timerToggle() {
        self.timerSound?.stop()
        if timerRunning {
            timerRunning = false
            timerEndTime = nil
        } else {
            if timerRemaining <= 0 {
                timerRemaining = timerInitial
                timerFinished = false
            }
            timerRunning = true
            timerEndTime = Date().addingTimeInterval(timerRemaining)
        }
    }
    
    func timerReset() {
        self.timerSound?.stop()
        timerRunning = false
        timerRemaining = timerInitial
        timerEndTime = nil
        timerFinished = false
    }
    
    func setTimerDuration(_ seconds: TimeInterval) {
        self.timerSound?.stop()
        timerRunning = false
        timerEndTime = nil
        timerInitial = seconds
        timerRemaining = seconds
        timerFinished = false
    }
    
    var timerString: String {
        let totalSeconds = Int(timerRemaining)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var timerProgress: Double {
        guard timerInitial > 0 else { return 0 }
        return max(0, min(1, 1.0 - (timerRemaining / timerInitial)))
    }
}
