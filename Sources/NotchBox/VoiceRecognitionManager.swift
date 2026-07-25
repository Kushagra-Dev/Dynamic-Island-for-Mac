import Foundation
import AVFoundation
import Speech
import Combine

/// Captures live microphone audio, transcribes it in real-time using Apple's on-device
/// SFSpeechRecognizer, and auto-detects end-of-speech (silence) to trigger a send.
class VoiceRecognitionManager: ObservableObject {
    
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var micPermissionGranted: Bool = false
    @Published var errorMessage: String? = nil
    
    /// When true, the manager will automatically send the transcript after silence is detected
    @Published var autoSendEnabled: Bool = true
    
    /// Called when silence is detected and transcript is ready to send
    var onSilenceDetected: ((String) -> Void)?
    
    // Lazy so they don't crash the app on init if Speech framework isn't available
    private lazy var speechRecognizer: SFSpeechRecognizer? = {
        SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private lazy var audioEngine: AVAudioEngine = AVAudioEngine()
    
    /// Timer to detect silence — fires when the user stops speaking
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.0 // seconds of silence before auto-send
    
    init() {
        // Don't call checkPermissions here — defer to first use
    }
    
    // MARK: - Permissions
    
    func checkPermissions() {
        // Check speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
        }
        
        // Check microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            DispatchQueue.main.async { self.micPermissionGranted = true }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async { self?.micPermissionGranted = granted }
            }
        default:
            DispatchQueue.main.async { self.micPermissionGranted = false }
        }
    }
    
    /// Request both permissions and then auto-start listening once granted
    private func requestPermissionsAndStart() {
        // Request speech recognition
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
            
            // Then request microphone
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.micPermissionGranted = granted
                    // Now try to start if both are granted
                    self?.startListening()
                }
            }
        }
    }
    
    // MARK: - Start / Stop Listening
    
    private var permissionsRequested = false
    
    func startListening() {
        guard !isListening else { return }
        
        // Request permissions on first call
        if !permissionsRequested {
            permissionsRequested = true
            requestPermissionsAndStart()
            return
        }
        
        // Verify permissions
        guard authorizationStatus == .authorized else {
            errorMessage = "Speech recognition not authorized. Please grant permission in System Settings > Privacy > Speech Recognition."
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    if status == .authorized {
                        self?.startListening()
                    }
                }
            }
            return
        }
        
        guard micPermissionGranted else {
            errorMessage = "Microphone access not granted. Please allow in System Settings > Privacy > Microphone."
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.micPermissionGranted = granted
                    if granted {
                        self?.startListening()
                    }
                }
            }
            return
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available."
            return
        }
        
        errorMessage = nil
        transcript = ""
        
        do {
            try startAudioSession()
        } catch {
            errorMessage = "Failed to start audio: \(error.localizedDescription)"
            return
        }
        
        DispatchQueue.main.async {
            self.isListening = true
        }
    }
    
    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    // MARK: - Audio Session & Recognition
    
    private func startAudioSession() throws {
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create the recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceRecognition", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Use on-device recognition if available (faster, more private)
        if #available(macOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false // Allow cloud for better accuracy
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install a tap on the audio input to feed audio buffers to the recognizer
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition
        guard let recognizer = speechRecognizer else { return }
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                DispatchQueue.main.async {
                    self.transcript = text
                    // Reset the silence timer every time we get new text
                    self.resetSilenceTimer()
                }
                
                if result.isFinal {
                    DispatchQueue.main.async {
                        self.handleFinalTranscript(text)
                    }
                }
            }
            
            if let error = error {
                // Don't report cancellation as an error
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                    // Request was cancelled — this is normal
                    return
                }
                
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.stopListening()
                }
            }
        }
    }
    
    // MARK: - Silence Detection
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        
        guard autoSendEnabled else { return }
        
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                let text = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    self.handleFinalTranscript(text)
                }
            }
        }
    }
    
    private func handleFinalTranscript(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Stop listening while we process
        stopListening()
        
        // Notify the callback
        onSilenceDetected?(text)
    }
}
