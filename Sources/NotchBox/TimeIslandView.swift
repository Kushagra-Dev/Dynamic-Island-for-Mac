import SwiftUI

struct TimeIslandView: View {
    @ObservedObject var timeManager: TimeManager
    
    @State private var isEditingCustomTimer = false
    @State private var customTimerHours: Int = 0
    @State private var customTimerMinutes: Int = 10
    @State private var customTimerSeconds: Int = 0
    
    let expandedWidth: CGFloat = LayoutConstants.expandedWidth
    
    var body: some View {
        VStack(spacing: 0) {
            // Premium Segmented Mode Switcher
            modeSwitcher
                .padding(.top, 34)
                .padding(.bottom, 10)
            
            // Active Mode Content
            switch timeManager.activeMode {
            case .clock:
                clockView
            case .stopwatch:
                stopwatchView
            case .timer:
                timerView
            }
        }
        .padding(.bottom, 20)
        .frame(width: expandedWidth)
        .background(Color.black)
    }
    
    // MARK: - Mode Switcher (iOS-style segmented control)
    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(TimeMode.allCases, id: \.self) { mode in
                Text(mode.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .kerning(0.5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(timeManager.activeMode == mode
                                  ? Color.orange.opacity(0.25)
                                  : Color.white.opacity(0.06))
                    )
                    .foregroundColor(timeManager.activeMode == mode ? .orange : .white.opacity(0.45))
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            timeManager.setMode(mode)
                        }
                    }
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Clock View
    private var clockView: some View {
        VStack(spacing: 6) {
            // Main time display
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(timeManager.clockTimeString)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeManager.clockSeconds)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .monospacedDigit()
                    
                    Text(timeManager.clockAMPM)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.orange.opacity(0.7))
                }
                .padding(.leading, 4)
            }
            
            // Date line
            Text(timeManager.clockDateString)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .kerning(0.3)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Stopwatch View
    private var stopwatchView: some View {
        VStack(spacing: 10) {
            // Time display
            Text(timeManager.stopwatchString)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .monospacedDigit()
            
            // Buttons
            HStack(spacing: 36) {
                // Reset
                InteractiveButton(systemName: "arrow.counterclockwise", size: 18) {
                    timeManager.stopwatchReset()
                }
                
                // Play/Pause (larger)
                ZStack {
                    Circle()
                        .fill(timeManager.stopwatchRunning ? Color.orange.opacity(0.15) : Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    InteractiveButton(systemName: timeManager.stopwatchRunning ? "pause.fill" : "play.fill", size: 22) {
                        timeManager.stopwatchToggle()
                    }
                }
                
                // Lap
                InteractiveButton(systemName: "flag.fill", size: 18) {
                    timeManager.stopwatchLap()
                }
                .opacity(timeManager.stopwatchRunning ? 1.0 : 0.3)
                .disabled(!timeManager.stopwatchRunning)
            }
            
            // Lap list
            if !timeManager.laps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(timeManager.laps.prefix(3).enumerated()), id: \.offset) { index, lap in
                        HStack {
                            Text("Lap \(timeManager.laps.count - index)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                            Text(timeManager.formatLapTime(lap))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                        
                        if index < min(timeManager.laps.count, 3) - 1 {
                            Divider()
                                .background(Color.white.opacity(0.08))
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Timer View
    private var timerView: some View {
        VStack(spacing: 12) {
            // Circular progress ring with time in center
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                
                // Progress ring with gradient
                Circle()
                    .trim(from: 0, to: CGFloat(timeManager.timerProgress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.orange, .red, .orange]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: timeManager.timerProgress)
                
                // Time in center
                VStack(spacing: 2) {
                    Text(timeManager.timerString)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(timeManager.timerFinished ? .red : .white)
                        .monospacedDigit()
                    
                    if timeManager.timerFinished {
                        Text("DONE")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.red)
                            .kerning(1)
                    }
                }
            }
            .frame(width: 110, height: 110)
            
            // Preset buttons (only when not running)
            if !timeManager.timerRunning {
                if isEditingCustomTimer {
                    HStack(spacing: 16) {
                        // Hours
                        VStack(spacing: 2) {
                            InteractiveButton(systemName: "chevron.up", size: 14) {
                                if customTimerHours < 23 { customTimerHours += 1; updateCustomTimer() }
                            }
                            Text("\(customTimerHours)h")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            InteractiveButton(systemName: "chevron.down", size: 14) {
                                if customTimerHours > 0 { customTimerHours -= 1; updateCustomTimer() }
                            }
                        }
                        
                        // Minutes
                        VStack(spacing: 2) {
                            InteractiveButton(systemName: "chevron.up", size: 14) {
                                if customTimerMinutes < 59 { customTimerMinutes += 1 } else { customTimerMinutes = 0 }
                                updateCustomTimer()
                            }
                            Text("\(customTimerMinutes)m")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .frame(width: 35)
                            InteractiveButton(systemName: "chevron.down", size: 14) {
                                if customTimerMinutes > 0 { customTimerMinutes -= 1 } else { customTimerMinutes = 59 }
                                updateCustomTimer()
                            }
                        }
                        
                        // Seconds
                        VStack(spacing: 2) {
                            InteractiveButton(systemName: "chevron.up", size: 14) {
                                if customTimerSeconds < 59 { customTimerSeconds += 1 } else { customTimerSeconds = 0 }
                                updateCustomTimer()
                            }
                            Text("\(customTimerSeconds)s")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .frame(width: 35)
                            InteractiveButton(systemName: "chevron.down", size: 14) {
                                if customTimerSeconds > 0 { customTimerSeconds -= 1 } else { customTimerSeconds = 59 }
                                updateCustomTimer()
                            }
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isEditingCustomTimer = false
                            }
                        }) {
                            Text("Done")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.orange))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    HStack(spacing: 10) {
                        ForEach([60, 300, 900], id: \.self) { seconds in
                            let isSelected = Int(timeManager.timerInitial) == seconds && !isEditingCustomTimer
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    timeManager.setTimerDuration(TimeInterval(seconds))
                                }
                            }) {
                                Text(formatPreset(seconds))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.orange : Color.white.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isEditingCustomTimer = true
                                updateCustomTimer()
                            }
                        }) {
                            Text("Custom")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            
            // Controls
            HStack(spacing: 40) {
                InteractiveButton(systemName: "arrow.counterclockwise", size: 18) {
                    timeManager.timerReset()
                }
                
                ZStack {
                    Circle()
                        .fill(timeManager.timerRunning ? Color.orange.opacity(0.15) : Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    InteractiveButton(systemName: timeManager.timerRunning ? "pause.fill" : "play.fill", size: 22) {
                        timeManager.timerToggle()
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func formatPreset(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m"
    }
    
    private func updateCustomTimer() {
        let totalSeconds = TimeInterval(customTimerHours * 3600 + customTimerMinutes * 60 + customTimerSeconds)
        timeManager.setTimerDuration(max(1, totalSeconds))
    }
}
