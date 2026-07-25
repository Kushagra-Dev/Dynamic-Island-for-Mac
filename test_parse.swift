import Foundation

let jsonStr = """
{
  "syncedLyrics": "[00:11.06] Something we all adore\n[00:13.69] One thing we're living for\n[00:16.58] Nothing but struggle\n[00:17.75] Stuck in this trouble\n[00:19.38] Trying for more and more"
}
"""

struct LyricLine {
    let time: Double
    let text: String
}

func parseLRC(_ lrc: String) -> [LyricLine] {
    var result: [LyricLine] = []
    let lines = lrc.components(separatedBy: .newlines)
    
    let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
    
    for line in lines {
        if let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
            if let minRange = Range(match.range(at: 1), in: line),
               let secRange = Range(match.range(at: 2), in: line),
               let msRange = Range(match.range(at: 3), in: line),
               let textRange = Range(match.range(at: 4), in: line) {
                
                let min = Double(line[minRange]) ?? 0
                let sec = Double(line[secRange]) ?? 0
                let msStr = String(line[msRange])
                let ms = (Double(msStr) ?? 0) / (msStr.count == 3 ? 1000.0 : 100.0)
                
                let time = (min * 60) + sec + ms
                let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
                
                if !text.isEmpty {
                    result.append(LyricLine(time: time, text: text))
                }
            }
        }
    }
    return result
}

let data = jsonStr.data(using: .utf8)!
let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
let syncedLyrics = json["syncedLyrics"] as! String

let parsed = parseLRC(syncedLyrics)
for line in parsed {
    print("\(line.time): \(line.text)")
}

let time = 44.0
var active = -1
for (index, line) in parsed.enumerated() {
    if line.time <= time + 0.2 {
        active = index
    } else {
        break
    }
}
print("Active index for 44.0 is \(active)")
