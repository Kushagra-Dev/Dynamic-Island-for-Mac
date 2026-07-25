import AppKit
import Foundation

let sounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
for sound in sounds {
    if NSSound(named: NSSound.Name(sound)) != nil {
        print("Found: \(sound)")
    }
}
