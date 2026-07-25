import Foundation
import AppKit

func getVolume() -> Double {
    let script = "output volume of (get volume settings)"
    if let result = runAppleScript(script) {
        return Double(result) ?? 0.0
    }
    return 0.0
}

func setVolume(_ volume: Double) {
    let script = "set volume output volume \(Int(volume))"
    _ = runAppleScript(script)
}

func runAppleScript(_ script: String) -> String? {
    var error: NSDictionary?
    if let appleScript = NSAppleScript(source: script) {
        let result = appleScript.executeAndReturnError(&error)
        if error == nil {
            return result.stringValue
        }
    }
    return nil
}

print("Current Volume: \(getVolume())")
setVolume(50)
print("New Volume: \(getVolume())")
