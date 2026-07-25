import Cocoa

let src = CGEventSource(stateID: .hidSystemState)
let loc = CGPoint(x: 756, y: 50) // Top center, 50 points down from top
let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: loc, mouseButton: .left)
let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: loc, mouseButton: .left)

down?.post(tap: .cghidEventTap)
up?.post(tap: .cghidEventTap)
