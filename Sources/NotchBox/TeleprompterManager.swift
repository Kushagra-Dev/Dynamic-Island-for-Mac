import Foundation
import Combine
import SwiftUI

class TeleprompterManager: ObservableObject {
    // MARK: - Teleprompter Mode
    @Published var text: String = "Welcome to the Notch Teleprompter!\n\nPaste your script here and use the controls to adjust the scrolling speed.\n\nEnjoy a seamless reading experience right from your dynamic island!"
    @Published var scrollSpeed: Double = 30.0 // Pixels per second
    @Published var isPlaying: Bool = false
    @Published var scrollOffset: CGFloat = 0.0
    @Published var maxScrollOffset: CGFloat = 1000.0 // Set by view
    
    // MARK: - AI Mode
    @Published var isAIMode: Bool = false
    @Published var aiInputText: String = ""
    @Published var isWaitingForAI: Bool = false
    @Published var showAPIKeyPrompt: Bool = false
    @Published var apiKeyInput: String = ""
    @Published var aiError: String? = nil
    @Published var aiScrollOffset: CGFloat = 0.0
    @Published var aiMaxScrollOffset: CGFloat = 1000.0
    
    // MARK: - Voice Recognition
    let voiceManager = VoiceRecognitionManager()
    /// When true, the mic stays on and auto-sends questions after silence
    @Published var continuousListening: Bool = false
    /// The live transcript shown while the user is speaking
    @Published var liveTranscript: String = ""
    
    let chatService = ChatGPTService()
    
    private var timer: AnyCancellable?
    private var lastTick: Date?
    private var voiceCancellables = Set<AnyCancellable>()
    
    init() {
        setupVoiceCallbacks()
    }
    
    // MARK: - Voice Setup
    
    private func setupVoiceCallbacks() {
        // Mirror the live transcript from voiceManager
        voiceManager.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.liveTranscript = text
            }
            .store(in: &voiceCancellables)
        
        // When silence is detected and auto-send is on, send the transcribed question
        voiceManager.onSilenceDetected = { [weak self] transcribedText in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.liveTranscript = ""
                self.sendAIMessageFromVoice(transcribedText)
            }
        }
    }
    
    // MARK: - Teleprompter Controls
    
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
    
    // MARK: - AI Mode Controls
    
    func toggleAIMode() {
        isAIMode.toggle()
        if isAIMode {
            // Pause teleprompter when switching to AI
            stopTimer()
            isPlaying = false
            
            // Check for API key
            if !APIKeyManager.shared.hasAPIKey {
                showAPIKeyPrompt = true
            }
            
            if chatService.conversationHistory.count <= 1 {
                chatService.conversationHistory.append(ChatGPTService.Message(role: "assistant", content: "Ask me anything.\n\nType your question below or tap the microphone to speak.\n\nEnable continuous listening for automatic answers during interviews."))
            }
        } else {
            // Stop listening when leaving AI mode
            voiceManager.stopListening()
            continuousListening = false
            liveTranscript = ""
        }
    }
    
    func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let success = APIKeyManager.shared.saveAPIKey(trimmed)
        if success {
            showAPIKeyPrompt = false
            apiKeyInput = ""
            aiError = nil
        }
    }
    
    func sendAIMessage() {
        var message = aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty {
            message = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !message.isEmpty else { return }
        
        guard APIKeyManager.shared.hasAPIKey else {
            showAPIKeyPrompt = true
            return
        }
        
        // Clear input and prepare the response area
        aiInputText = ""
        liveTranscript = ""
        
        if voiceManager.isListening {
            voiceManager.stopListening()
        }
        
        sendToAI(message)
    }
    
    func sendAIMessageFromVoice(_ message: String) {
        guard !message.isEmpty else {
            // If continuous listening, restart
            if continuousListening {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.voiceManager.startListening()
                }
            }
            return
        }
        
        guard APIKeyManager.shared.hasAPIKey else {
            showAPIKeyPrompt = true
            return
        }
        
        sendToAI(message)
    }
    
    private func sendToAI(_ message: String) {
        aiError = nil
        isWaitingForAI = true
        aiScrollOffset = 0.0
        
        chatService.sendMessage(
            message,
            onToken: { [weak self] token in
                guard let self = self else { return }
                self.isWaitingForAI = false
            },
            onComplete: { [weak self] error in
                guard let self = self else { return }
                self.isWaitingForAI = false
                if let error = error {
                    self.aiError = error.localizedDescription
                    // If there was an error, replace the empty assistant message with the error message
                    if let lastIndex = self.chatService.conversationHistory.indices.last, self.chatService.conversationHistory[lastIndex].content.isEmpty {
                        self.chatService.conversationHistory[lastIndex].content = "Error: \(error.localizedDescription)"
                    } else {
                        self.chatService.conversationHistory.append(ChatGPTService.Message(role: "assistant", content: "Error: \(error.localizedDescription)"))
                    }
                }
                
                // If continuous listening is on, restart the mic after the AI finishes responding
                if self.continuousListening {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.voiceManager.startListening()
                    }
                }
            }
        )
    }
    
    func toggleMic() {
        if voiceManager.isListening {
            continuousListening = false
            voiceManager.autoSendEnabled = false
            voiceManager.stopListening()
            
            // Move any spoken text into the text field so the user can edit it
            let transcript = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                if aiInputText.isEmpty {
                    aiInputText = transcript
                } else {
                    aiInputText += " " + transcript
                }
                liveTranscript = ""
            }
        } else {
            voiceManager.startListening()
        }
    }
    
    func toggleContinuousListening() {
        continuousListening.toggle()
        if continuousListening {
            // Start listening immediately
            voiceManager.autoSendEnabled = true
            voiceManager.startListening()
        } else {
            voiceManager.autoSendEnabled = false
            voiceManager.stopListening()
            
            let transcript = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                if aiInputText.isEmpty {
                    aiInputText = transcript
                } else {
                    aiInputText += " " + transcript
                }
                liveTranscript = ""
            }
        }
    }
    
    func clearAIConversation() {
        chatService.clearHistory()
        chatService.conversationHistory.append(ChatGPTService.Message(role: "assistant", content: "Ask me anything.\n\nType your question below or tap the microphone to speak.\n\nEnable continuous listening for automatic answers during interviews."))
        aiScrollOffset = 0.0
        aiError = nil
    }
}
