import AppKit

for i in 1...5 {
    if let sound = NSSound(named: "Tink")?.copy() as? NSSound {
        sound.volume = 0.5
        sound.play()
        print("Played \(i)")
    }
    Thread.sleep(forTimeInterval: 0.1)
}
Thread.sleep(forTimeInterval: 1.0)
