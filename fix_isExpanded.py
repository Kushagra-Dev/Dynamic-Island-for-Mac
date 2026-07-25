import re

file_path = "Sources/NotchBox/LyricsScrollerView.swift"
with open(file_path, "r") as f:
    content = f.read()

# Replace the event monitor logic
old_code = """                        // Catch all scroll and drag events in the app to reliably detect user scrolling the lyrics
                        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .leftMouseDown, .leftMouseDragged]) { event in
                            userDidInteract()
                            return event
                        }"""
new_code = """                        // Only catch scroll wheel events to avoid catching the initial click that opens the notch
                        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { event in
                            userDidInteract()
                            return event
                        }"""
content = content.replace(old_code, new_code)

with open(file_path, "w") as f:
    f.write(content)
