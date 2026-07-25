import Foundation

/// A lightweight ChatGPT streaming client using URLSession only — zero dependencies.
class ChatGPTService: ObservableObject {
    
    struct Message: Identifiable, Equatable {
        let id = UUID()
        let role: String   // "system", "user", or "assistant"
        var content: String
    }
    
    @Published var isStreaming: Bool = false
    
    /// Conversation history for multi-turn chat
    @Published var conversationHistory: [Message] = [
        Message(role: "system", content: "You are a helpful, concise assistant embedded in a macOS Dynamic Island app called Notch. Keep answers clear and well-formatted. Use short paragraphs. When the user asks a question, answer directly.")
    ]
    
    private var currentTask: URLSessionDataTask?
    
    /// Send a user message and stream the response back token-by-token via a callback.
    /// The `onToken` callback is called on the main thread for each new chunk of text.
    /// The `onComplete` callback is called when the stream finishes.
    func sendMessage(
        _ userMessage: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Error?) -> Void
    ) {
        guard let apiKey = APIKeyManager.shared.getAPIKey(), !apiKey.isEmpty else {
            onComplete(ChatGPTError.noAPIKey)
            return
        }
        
        // Add user message to history
        conversationHistory.append(Message(role: "user", content: userMessage))
        
        // Build the request
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        // Add an empty assistant message placeholder that we will update
        let assistantMessageIndex = conversationHistory.count
        conversationHistory.append(Message(role: "assistant", content: ""))
        
        let messages = conversationHistory.dropLast().map { msg in
            ["role": msg.role, "content": msg.content]
        }
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": Array(messages),
            "stream": true,
            "max_tokens": 2048
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        DispatchQueue.main.async {
            self.isStreaming = true
        }
        
        // Use a streaming URLSession delegate
        let delegate = StreamingDelegate(
            onToken: { [weak self] token in
                DispatchQueue.main.async {
                    self?.conversationHistory[assistantMessageIndex].content += token
                    onToken(token)
                }
            },
            onComplete: { [weak self] fullResponse, error in
                DispatchQueue.main.async {
                    self?.isStreaming = false
                    // Already added incrementally to conversationHistory
                    onComplete(error)
                }
            }
        )
        
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        currentTask = task
        task.resume()
    }
    
    /// Cancel the current streaming request
    func cancelStream() {
        currentTask?.cancel()
        currentTask = nil
        DispatchQueue.main.async {
            self.isStreaming = false
        }
    }
    
    /// Clear conversation history (keep system prompt)
    func clearHistory() {
        let systemPrompt = conversationHistory.first
        conversationHistory = []
        if let prompt = systemPrompt {
            conversationHistory.append(prompt)
        }
    }
    
    enum ChatGPTError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case apiError(String)
        
        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No API key found. Please add your OpenAI API key."
            case .invalidResponse:
                return "Invalid response from ChatGPT."
            case .apiError(let msg):
                return "API Error: \(msg)"
            }
        }
    }
}

// MARK: - Streaming URLSession Delegate

/// Handles Server-Sent Events (SSE) from OpenAI's streaming API.
/// Parses `data: {...}` lines and extracts content deltas.
private class StreamingDelegate: NSObject, URLSessionDataDelegate {
    let onToken: (String) -> Void
    let onComplete: (String?, Error?) -> Void
    
    private var buffer = ""
    private var fullResponse = ""
    
    init(
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String?, Error?) -> Void
    ) {
        self.onToken = onToken
        self.onComplete = onComplete
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        
        buffer += text
        
        // Process complete lines from the buffer
        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])
            
            processLine(line)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Process any remaining buffer
        if !buffer.isEmpty {
            processLine(buffer)
            buffer = ""
        }
        
        if let error = error as? URLError, error.code == .cancelled {
            onComplete(fullResponse, nil)
        } else {
            onComplete(fullResponse, error)
        }
    }
    
    private func processLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines and SSE comments
        guard trimmed.hasPrefix("data: ") else { return }
        
        let jsonString = String(trimmed.dropFirst(6))
        
        // Check for stream end
        if jsonString == "[DONE]" { return }
        
        // Parse the JSON chunk
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }
        
        // Check for error response first
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            onComplete(nil, ChatGPTService.ChatGPTError.apiError(message))
            return
        }
        
        // Extract content if available
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            fullResponse += content
            onToken(content)
        }
    }
}
