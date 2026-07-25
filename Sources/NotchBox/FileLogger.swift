import Foundation

class FileLogger {
    static let shared = FileLogger()
    let logFile: URL
    
    private init() {
        logFile = URL(fileURLWithPath: "/tmp/notchbox_hittest.log")
        try? "".write(to: logFile, atomically: true, encoding: .utf8)
    }
    
    func log(_ message: String) {
        let msg = "\(message)\n"
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            if let data = msg.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }
}
