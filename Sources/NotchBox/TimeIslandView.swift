import SwiftUI
import AppKit

enum Haptic {
    static func click() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        DispatchQueue.main.async {
            // Using .copy() allows the sounds to overlap flawlessly on rapid fires
            if let sound = NSSound(named: "Tink")?.copy() as? NSSound {
                sound.volume = 0.25 
                sound.play()
            }
        }
    }

    static func level() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        DispatchQueue.main.async {
            // Using .copy() allows rapid scrolling to play a distinct tick for every single number
            if let sound = NSSound(named: "Tink")?.copy() as? NSSound {
                sound.volume = 0.15 // Loud enough to be a clear click, but softer than a button tap
                sound.play()
            }
        }
    }
}

struct TimeIslandView: View {
    @ObservedObject var timeManager: TimeManager
    
    let expandedWidth: CGFloat = LayoutConstants.expandedWidth
    
    var body: some View {
        VStack(spacing: 0) {
            if !timeManager.timerFinished && !timeManager.alarmRinging {
                // Premium Segmented Mode Switcher
                modeSwitcher
                    .padding(.top, 34)
                    .padding(.bottom, 10)
            }
            
            // Active Mode Content
            if timeManager.timerFinished || timeManager.alarmRinging {
                stopRingingView
            } else {
                switch timeManager.activeMode {
                case .clock:
                    clockView
                case .stopwatch:
                    stopwatchView
                case .timer:
                    timerView
                case .alarm:
                    alarmView
                }
            }
        }
        .padding(.bottom, 20)
        .frame(width: expandedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
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
                if timeManager.isEditingCustomTimer {
                    HStack(spacing: 16) {
                        // Hours
                        CustomWheelPicker(selection: $timeManager.customTimerHours, range: 0...23, format: "%d", suffix: "h", mainFontSize: 16, sideFontSize: 12, spacing: 2, itemHeight: 20)
                            .frame(width: 45)
                            .onChange(of: timeManager.customTimerHours) { _ in updateCustomTimer() }
                        
                        // Minutes
                        CustomWheelPicker(selection: $timeManager.customTimerMinutes, range: 0...59, format: "%d", suffix: "m", mainFontSize: 16, sideFontSize: 12, spacing: 2, itemHeight: 20)
                            .frame(width: 45)
                            .onChange(of: timeManager.customTimerMinutes) { _ in updateCustomTimer() }
                        
                        // Seconds
                        CustomWheelPicker(selection: $timeManager.customTimerSeconds, range: 0...59, format: "%d", suffix: "s", mainFontSize: 16, sideFontSize: 12, spacing: 2, itemHeight: 20)
                            .frame(width: 45)
                            .onChange(of: timeManager.customTimerSeconds) { _ in updateCustomTimer() }


                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                timeManager.isEditingCustomTimer = false
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
                            let isSelected = Int(timeManager.timerInitial) == seconds && !timeManager.isEditingCustomTimer
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
                                timeManager.isEditingCustomTimer = true
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
            HStack {
                // Cancel Button
                Button(action: {
                    withAnimation { timeManager.timerReset() }
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(timeManager.timerRunning || timeManager.timerProgress > 0 ? Color(white: 0.6) : Color(white: 0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color(white: 0.2)))
                }
                .buttonStyle(.plain)
                .disabled(!timeManager.timerRunning && timeManager.timerProgress == 0)
                
                Spacer()
                
                // Start / Pause / Resume Button
                let isRunning = timeManager.timerRunning
                let hasProgress = timeManager.timerProgress > 0
                let isPause = isRunning
                
                Button(action: {
                    withAnimation { timeManager.timerToggle() }
                }) {
                    Text(isPause ? "Pause" : (hasProgress ? "Resume" : "Start"))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(isPause ? .orange : .green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(isPause ? Color.orange.opacity(0.2) : Color.green.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
        }
    }
    
    // MARK: - Helpers
    private func formatPreset(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m"
    }
    
    private func updateCustomTimer() {
        let totalSeconds = TimeInterval(timeManager.customTimerHours * 3600 + timeManager.customTimerMinutes * 60 + timeManager.customTimerSeconds)
        timeManager.setTimerDuration(max(1, totalSeconds))
    }
    
    // MARK: - Stop Ringing View
    private var stopRingingView: some View {
        HStack(alignment: .center) {
            if timeManager.alarmRinging {
                // Alarm Ringing UI
                HStack(spacing: 12) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                        // Simple ringing animation effect can be added if desired
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeManager.clockTimeString)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2)) // Darker orange/brown text
                        Text("Alarm")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            timeManager.snoozeAlarm()
                        }
                    }) {
                        Image(systemName: "zzz")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.orange)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Color(red: 0.3, green: 0.15, blue: 0.05)))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            timeManager.stopSound()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Color(white: 0.25)))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Timer Finished UI
                Text("Timer")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            timeManager.stopSound()
                            timeManager.timerToggle() // Restart the timer
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.orange)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Color(red: 0.3, green: 0.15, blue: 0.05)))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            timeManager.stopSound()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Color(white: 0.25)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 40) // Add extra top padding so the physical notch doesn't clip the content
        .padding(.bottom, 20)
        // Let the content dictate the height to properly clear the physical notch
    }
    
    // MARK: - Alarm View
    private var alarmView: some View {
        VStack(spacing: 12) {
            if timeManager.isAddingAlarm {
                HStack(spacing: 20) {
                    // Hour picker (12-hour format underlying 0-23)
                    CustomWheelPicker(selection: $timeManager.newAlarmHour, range: 0...23, displayMapper: { val in
                        let h = val % 12
                        return "\(h == 0 ? 12 : h)"
                    })
                    .frame(width: 45)
                    
                    Text(":")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .offset(y: -4) // Align with the center number visually
                    
                    // Minute picker
                    CustomWheelPicker(selection: $timeManager.newAlarmMinute, range: 0...59)
                        .frame(width: 45)
                    
                    let amPmBinding = Binding<Int>(
                        get: { timeManager.newAlarmHour >= 12 ? 1 : 0 },
                        set: { newValue in
                            let isNowPM = newValue == 1
                            let isCurrentlyPM = timeManager.newAlarmHour >= 12
                            if isNowPM && !isCurrentlyPM {
                                timeManager.newAlarmHour += 12
                            } else if !isNowPM && isCurrentlyPM {
                                timeManager.newAlarmHour -= 12
                            }
                        }
                    )
                    
                    StringWheelPicker(selection: amPmBinding, items: ["AM", "PM"])
                        .frame(width: 45)
                }
                .padding(.vertical, 8)
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        withAnimation { timeManager.isAddingAlarm = false }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation {
                            timeManager.alarms.append(Alarm(hour: timeManager.newAlarmHour, minute: timeManager.newAlarmMinute))
                            timeManager.isAddingAlarm = false
                        }
                    }) {
                        Text("Save")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                if timeManager.alarms.isEmpty {
                    Text("No alarms set")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 20)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            let visibleAlarms = timeManager.alarms.enumerated().filter { !$0.element.isEphemeral }
                            ForEach(visibleAlarms, id: \.element.id) { index, alarm in
                                HStack {
                                    let h12 = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12
                                    let amPm = alarm.hour >= 12 ? "PM" : "AM"
                                    Text(String(format: "%02d:%02d %@", h12, alarm.minute, amPm))
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(alarm.isEnabled ? .white : .white.opacity(0.4))
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { timeManager.alarms[index].isEnabled },
                                        set: { timeManager.alarms[index].isEnabled = $0 }
                                    ))
                                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                                    .labelsHidden()
                                    
                                    InteractiveButton(systemName: "trash.fill", size: 12) {
                                        withAnimation {
                                            let removeIndex = index as Int
                                            timeManager.alarms.remove(at: removeIndex)
                                        }
                                    }
                                    .foregroundColor(.red.opacity(0.7))
                                    .padding(.leading, 8)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Color(NSColor(white: 1.0, alpha: 0.05)))
                                .cornerRadius(12)
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
                
                Button(action: {
                    withAnimation { timeManager.isAddingAlarm = true }
                }) {
                    Text("+ New Alarm")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Wheel Scroller Engine
class WheelScroller: ObservableObject {
    @Published var dragOffset: CGFloat = 0
    var accumulatedScroll: CGFloat = 0
    var timer: Timer?
    var lastDragTime: Date = Date()
    
    func onDrag(location: CGFloat, selection: Binding<Int>, range: ClosedRange<Int>, itemHeight: CGFloat, wrap: Bool = true) {
        timer?.invalidate()
        let now = Date()
        let delta = location - accumulatedScroll
        lastDragTime = now
        accumulatedScroll = location
        dragOffset += delta
        processOffset(selection: selection, range: range, itemHeight: itemHeight, wrap: wrap)
    }
    
    @discardableResult
    func processOffset(selection: Binding<Int>, range: ClosedRange<Int>, itemHeight: CGFloat, wrap: Bool = true) -> CGFloat {
        let initialSelection = selection.wrappedValue
        var wrappedAmount: CGFloat = 0
        
        while dragOffset >= itemHeight {
            if selection.wrappedValue > range.lowerBound {
                dragOffset -= itemHeight
                wrappedAmount += itemHeight
                selection.wrappedValue -= 1
            } else if wrap {
                dragOffset -= itemHeight
                wrappedAmount += itemHeight
                selection.wrappedValue = range.upperBound
            } else {
                dragOffset = itemHeight
                break
            }
        }
        while dragOffset <= -itemHeight {
            if selection.wrappedValue < range.upperBound {
                dragOffset += itemHeight
                wrappedAmount -= itemHeight
                selection.wrappedValue += 1
            } else if wrap {
                dragOffset += itemHeight
                wrappedAmount -= itemHeight
                selection.wrappedValue = range.lowerBound
            } else {
                dragOffset = -itemHeight
                break
            }
        }
        
        if selection.wrappedValue != initialSelection {
            triggerHaptic()
        }
        return wrappedAmount
    }
    
    func triggerHaptic() {
        // Direct, un-throttled haptic dispatch ensures it is perfectly in sync with the visual tick.
        Haptic.level()
    }
    
    func onEnded(velocity: CGFloat, selection: Binding<Int>, range: ClosedRange<Int>, itemHeight: CGFloat, wrap: Bool = true) {
        accumulatedScroll = 0
        timer?.invalidate()
        
        // Scale velocity proportional to item size for consistent feel
        let scaleFactor: CGFloat = 0.007 * (itemHeight / 30.0)
        var vel = velocity * scaleFactor
        let maxVel: CGFloat = 18 * (itemHeight / 30.0)
        vel = max(-maxVel, min(maxVel, vel))
        
        // Transition threshold: relative to item size
        let settleThreshold: CGFloat = max(0.4, 0.8 * (itemHeight / 30.0))
        
        // If gesture ended with negligible velocity, skip friction phase
        var isSettling = abs(vel) < settleThreshold
        
        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            
            if !isSettling {
                // ── PHASE 1: Friction deceleration ──
                // 0.96 gives a heavier, more satisfying deceleration (like a real metal wheel)
                vel *= 0.96
                self.dragOffset += vel
                self.processOffset(selection: selection, range: range, itemHeight: itemHeight, wrap: wrap)
                
                if abs(vel) < settleThreshold {
                    // Commit to nearest slot before settling
                    self.commitNearestSlot(selection: selection, range: range, itemHeight: itemHeight, wrap: wrap)
                    isSettling = true
                }
            } else {
                // ── PHASE 2: Smooth exponential ease toward 0 ──
                // Decay rate of 0.88 gives a gentle ~0.25s settle
                self.dragOffset *= 0.88
                
                if abs(self.dragOffset) < 0.1 {
                    self.dragOffset = 0
                    timer.invalidate()
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }
    
    /// When transitioning from friction to settle, commit to the nearest slot
    /// by adjusting selection + offset atomically. Visually nothing moves.
    private func commitNearestSlot(selection: Binding<Int>, range: ClosedRange<Int>, itemHeight: CGFloat, wrap: Bool) {
        if dragOffset > itemHeight * 0.5 {
            // Scrolled past halfway toward previous item
            if selection.wrappedValue > range.lowerBound {
                selection.wrappedValue -= 1
                dragOffset -= itemHeight
                triggerHaptic()
            } else if wrap {
                selection.wrappedValue = range.upperBound
                dragOffset -= itemHeight
                triggerHaptic()
            }
            // else: at boundary, non-wrapping — ease back to 0
        } else if dragOffset < -itemHeight * 0.5 {
            // Scrolled past halfway toward next item
            if selection.wrappedValue < range.upperBound {
                selection.wrappedValue += 1
                dragOffset += itemHeight
                triggerHaptic()
            } else if wrap {
                selection.wrappedValue = range.lowerBound
                dragOffset += itemHeight
                triggerHaptic()
            }
        }
    }
}

// MARK: - Custom Wheel Picker
struct CustomWheelPicker: View {
    @Binding var selection: Int
    let range: ClosedRange<Int>
    var format: String = "%02d"
    var suffix: String = ""
    var mainFontSize: CGFloat = 28
    var sideFontSize: CGFloat = 16
    var spacing: CGFloat = 4
    var itemHeight: CGFloat = 30 // Distance between items (approx center to center)
    var displayMapper: ((Int) -> String)? = nil
    
    @StateObject private var scroller = WheelScroller()
    
    private var previousValue: Int {
        selection > range.lowerBound ? selection - 1 : range.upperBound
    }
    
    private var nextValue: Int {
        selection < range.upperBound ? selection + 1 : range.lowerBound
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ▲ Up arrow button — go to previous value
            Button(action: {
                withAnimation(.easeOut(duration: 0.15)) { selection = previousValue }
                Haptic.click()
            }) {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: max(8, sideFontSize * 0.45), weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 32, height: max(14, sideFontSize * 0.8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Scrollable number area
            VStack(spacing: spacing) {
                Text(displayMapper?(previousValue) ?? (String(format: format, previousValue) + suffix))
                    .font(.system(size: sideFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { selection = previousValue }
                        Haptic.click()
                    }
                
                Text(displayMapper?(selection) ?? (String(format: format, selection) + suffix))
                    .font(.system(size: mainFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                
                Text(displayMapper?(nextValue) ?? (String(format: format, nextValue) + suffix))
                    .font(.system(size: sideFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { selection = nextValue }
                        Haptic.click()
                    }
            }
            .offset(y: scroller.dragOffset)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let selectionBinding = Binding(
                            get: { self.selection },
                            set: { self.selection = $0 }
                        )
                        scroller.onDrag(location: gesture.translation.height, selection: selectionBinding, range: range, itemHeight: itemHeight)
                    }
                    .onEnded { gesture in
                        let selectionBinding = Binding(
                            get: { self.selection },
                            set: { self.selection = $0 }
                        )
                        scroller.onEnded(velocity: gesture.velocity.height, selection: selectionBinding, range: range, itemHeight: itemHeight)
                    }
            )
            
            // ▼ Down arrow button — go to next value
            Button(action: {
                withAnimation(.easeOut(duration: 0.15)) { selection = nextValue }
                Haptic.click()
            }) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: max(8, sideFontSize * 0.45), weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
                    .frame(width: 32, height: max(14, sideFontSize * 0.8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - String Wheel Picker
struct StringWheelPicker: View {
    @Binding var selection: Int
    let items: [String]
    var mainFontSize: CGFloat = 24
    var sideFontSize: CGFloat = 14
    var spacing: CGFloat = 4
    var itemHeight: CGFloat = 30
    
    @StateObject private var scroller = WheelScroller()
    
    private var previousValue: Int? {
        selection > 0 ? selection - 1 : nil
    }
    
    private var nextValue: Int? {
        selection < items.count - 1 ? selection + 1 : nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ▲ Up arrow button — go to previous value (hidden at boundary)
            Button(action: {
                if let prev = previousValue {
                    withAnimation(.easeOut(duration: 0.15)) { selection = prev }
                    Haptic.click()
                }
            }) {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: max(8, sideFontSize * 0.45), weight: .regular))
                    .foregroundColor(.white.opacity(previousValue != nil ? 0.35 : 0.08))
                    .frame(width: 32, height: max(14, sideFontSize * 0.8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Scrollable area
            VStack(spacing: spacing) {
                if let prev = previousValue {
                    Text(items[prev])
                        .font(.system(size: sideFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) { selection = prev }
                            Haptic.click()
                        }
                } else {
                    Text(" ")
                        .font(.system(size: sideFontSize, weight: .semibold, design: .rounded))
                }
                
                Text(items[selection])
                    .font(.system(size: mainFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                
                if let next = nextValue {
                    Text(items[next])
                        .font(.system(size: sideFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) { selection = next }
                            Haptic.click()
                        }
                } else {
                    Text(" ")
                        .font(.system(size: sideFontSize, weight: .semibold, design: .rounded))
                }
            }
            .offset(y: scroller.dragOffset)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let selectionBinding = Binding(
                            get: { self.selection },
                            set: { self.selection = $0 }
                        )
                        scroller.onDrag(location: gesture.translation.height, selection: selectionBinding, range: 0...(items.count - 1), itemHeight: itemHeight, wrap: false)
                    }
                    .onEnded { gesture in
                        let selectionBinding = Binding(
                            get: { self.selection },
                            set: { self.selection = $0 }
                        )
                        scroller.onEnded(velocity: gesture.velocity.height, selection: selectionBinding, range: 0...(items.count - 1), itemHeight: itemHeight, wrap: false)
                    }
            )
            
            // ▼ Down arrow button — go to next value (hidden at boundary)
            Button(action: {
                if let next = nextValue {
                    withAnimation(.easeOut(duration: 0.15)) { selection = next }
                    Haptic.click()
                }
            }) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: max(8, sideFontSize * 0.45), weight: .regular))
                    .foregroundColor(.white.opacity(nextValue != nil ? 0.35 : 0.08))
                    .frame(width: 32, height: max(14, sideFontSize * 0.8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
