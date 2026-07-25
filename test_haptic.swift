import Foundation
import AudioToolbox
import AppKit

print("Testing AudioServicesPlaySystemSound(1520)...")
AudioServicesPlaySystemSound(1520) // iOS strong haptic

print("Testing Tink...")
AudioServicesPlaySystemSound(1053) // Tink

RunLoop.current.run(until: Date().addingTimeInterval(1.0))
