import SwiftUI

struct TeleprompterIslandView: View {
    @ObservedObject var manager: TeleprompterManager
    @ObservedObject var islandManager: IslandManager
    let expandedWidth: CGFloat = LayoutConstants.expandedWidth + 70
    @State private var lastDragValue: CGFloat = 0
    @State private var isEditing: Bool = false
    @State private var aiLastDragValue: CGFloat = 0
    @State private var micPulse: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        manager.isAIMode.toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: manager.isAIMode ? "sparkles" : "text.quote")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(manager.isAIMode ? .cyan : .purple)
                        Text(manager.isAIMode ? "AI ASSISTANT" : "TELEPROMPTER")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .kerning(1.0)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if manager.isAIMode {
                    InteractiveButton(systemName: "trash.circle.fill", size: 18) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            manager.clearAIConversation()
                        }
                    }
                    .padding(.trailing, 4)
                    .foregroundColor(.white)
                    
                    InteractiveButton(systemName: islandManager.isSwipingLocked ? "lock.fill" : "lock.open.fill", size: 18) {
                        islandManager.isSwipingLocked.toggle()
                        islandManager.isLockedExpanded = islandManager.isSwipingLocked
                    }
                    .padding(.trailing, 4)
                    .foregroundColor(islandManager.isSwipingLocked ? .orange : .white)
                    
                    // Continuous Listening toggle (Interview Mode)
                    InteractiveButton(systemName: manager.continuousListening ? "waveform.circle.fill" : "waveform.circle", size: 18) {
                        manager.toggleContinuousListening()
                    }
                    .padding(.trailing, 4)
                    .foregroundColor(manager.continuousListening ? .green : .white)
                } else {
                    // Teleprompter Mode buttons
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
                
                // AI/Teleprompter mode toggle — always visible
                InteractiveButton(systemName: manager.isAIMode ? "text.quote" : "sparkles", size: 18) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        manager.isAIMode.toggle()
                    }
                }
                .padding(.leading, 8)
                .foregroundColor(manager.isAIMode ? .white : .cyan)
            }
            .padding(.horizontal, 24)
            .padding(.top, 38)
            .padding(.bottom, 10)
            
            if manager.isAIMode {
                // AI Mode Content
                if manager.showAPIKeyPrompt {
                    apiKeyPromptView
                } else {
                    VStack(spacing: 0) {
                        aiOutputView
                        
                        if !manager.liveTranscript.isEmpty {
                            liveTranscriptView
                        }
                        
                        aiInputView
                    }
                }
            } else {
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
        }
        .frame(width: expandedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.black)
    }
    
    // MARK: - AI Mode Views
    
    private var apiKeyPromptView: some View {
        VStack(spacing: 16) {
            Text("OpenAI API Key Required")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Please enter your OpenAI API key to use the AI Assistant. Your key is stored securely in your keychain.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            SecureField("sk-...", text: $manager.apiKeyInput)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .padding(10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
            
            if let error = manager.aiError {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }
            
            Button(action: {
                manager.saveAPIKey()
            }) {
                Text("Save Key")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.cyan)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .disabled(manager.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.bottom, 24)
        }
        .frame(height: 220)
    }
    
    private var aiOutputView: some View {
        let displayMessages = manager.chatService.conversationHistory.filter { $0.role != "system" }
        
        return GeometryReader { geo in
            VStack(spacing: 16) {
                if displayMessages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundColor(.cyan.opacity(0.5))
                        Text("How can I help you today?")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(displayMessages) { msg in
                        chatBubble(for: msg)
                    }
                    
                    if manager.isWaitingForAI || manager.chatService.isStreaming {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    if let error = manager.aiError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .frame(width: geo.size.width, alignment: .top)
            .background(
                GeometryReader { contentGeo in
                    Color.clear.onAppear {
                        updateAIContentHeight(contentGeo.size.height, viewportHeight: geo.size.height)
                    }
                    .onChange(of: contentGeo.size.height) { newHeight in
                        updateAIContentHeight(newHeight, viewportHeight: geo.size.height)
                    }
                    .onChange(of: manager.chatService.conversationHistory.count) { _ in
                        // Auto-scroll to bottom on new message
                        withAnimation {
                            manager.aiScrollOffset = manager.aiMaxScrollOffset
                        }
                    }
                }
            )
            .offset(y: -manager.aiScrollOffset)
        }
        .frame(height: 160) // fixed height for output area
        .contentShape(Rectangle())
        .clipped()
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if abs(value.translation.height) > abs(value.translation.width) {
                        if aiLastDragValue == 0 {
                            aiLastDragValue = manager.aiScrollOffset
                        }
                        manager.aiScrollOffset = max(0, min(manager.aiMaxScrollOffset, aiLastDragValue - value.translation.height))
                    }
                }
                .onEnded { _ in
                    aiLastDragValue = 0
                }
        )
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.1),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func updateAIContentHeight(_ contentHeight: CGFloat, viewportHeight: CGFloat) {
        manager.aiMaxScrollOffset = max(0, contentHeight - viewportHeight + 40)
        // Keep scrolled to bottom if we were already at bottom
        if manager.aiScrollOffset >= manager.aiMaxScrollOffset - 50 {
            manager.aiScrollOffset = manager.aiMaxScrollOffset
        }
    }
    
    private func chatBubble(for message: ChatGPTService.Message) -> some View {
        let isUser = message.role == "user"
        
        return HStack {
            if isUser { Spacer(minLength: 40) }
            
            Text(message.content)
                .font(.system(size: 14, weight: isUser ? .medium : .regular, design: .rounded))
                .foregroundColor(isUser ? .white : .white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isUser ? Color.blue.opacity(0.8) : Color.white.opacity(0.1))
                )
            
            if !isUser { Spacer(minLength: 40) }
        }
    }
    
    private var liveTranscriptView: some View {
        HStack(spacing: 8) {
            // Pulsing mic indicator
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(micPulse ? 1.3 : 0.8)
                .opacity(micPulse ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: micPulse)
                .onAppear { micPulse = true }
                .onDisappear { micPulse = false }
            
            Text(manager.liveTranscript)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 6)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var aiInputView: some View {
        let isInputEmpty = manager.aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                           manager.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                           
        return HStack(spacing: 8) {
            // Mic button
            Button(action: {
                withAnimation {
                    manager.toggleMic()
                }
            }) {
                ZStack {
                    if manager.voiceManager.isListening {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .scaleEffect(micPulse ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: micPulse)
                            .onAppear { micPulse = true }
                            .onDisappear { micPulse = false }
                    }
                    
                    Image(systemName: manager.voiceManager.isListening ? "waveform" : "mic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(manager.voiceManager.isListening ? .cyan : .white.opacity(0.7))
                }
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            
            TextField("Ask anything...", text: $manager.aiInputText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .onSubmit {
                    manager.sendAIMessage()
                }
            
            // Send / Stop button
            if manager.chatService.isStreaming {
                Button(action: {
                    manager.chatService.cancelStream()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: {
                    manager.sendAIMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            isInputEmpty
                                ? LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isInputEmpty)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

// MARK: - Typing Indicator Animation

struct TypingIndicator: View {
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.cyan.opacity(0.7))
                    .frame(width: 6, height: 6)
                    .offset(y: dotOffsets[index])
            }
        }
        .task {
            while !Task.isCancelled {
                for i in 0..<3 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dotOffsets[i] = -5
                    }
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dotOffsets[i] = 0
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }
}
