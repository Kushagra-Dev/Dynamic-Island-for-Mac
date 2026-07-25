import AppKit

let url = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/Ringtones/Opening.m4r")
if let sound = NSSound(contentsOf: url, byReference: false) {
    sound.volume = 1.0
    sound.play()
    print("Playing...")
    Thread.sleep(forTimeInterval: 3.0)
} else {
    print("Failed to load sound")
}
