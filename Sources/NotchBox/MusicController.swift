import Foundation
import Combine
import AppKit
import SwiftUI
import CoreImage

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: Double // in seconds
    let text: String
}

class MusicController: ObservableObject {
    @Published var trackName: String = "No track playing"
    @Published var artistName: String = ""
    @Published var isPlaying: Bool = false
    @Published var artwork: NSImage?
    @Published var dominantColor: Color = .green
    
    @Published var currentTime: Double = 0
    @Published var duration: Double = 1
    
    @Published var volume: Double = 50
    
    @Published var lyrics: [LyricLine] = []
    @Published var isFetchingLyrics: Bool = false
    @Published var lyricsUnavailable: Bool = false
    
    private var timer: AnyCancellable?
    private var interpolationTimer: Timer?
    private var lastTimerTick: Date = Date()
    
    // MediaRemote bindings for artwork
    typealias MRGetNowPlayingInfo = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
    private var getNowPlayingInfoFunc: MRGetNowPlayingInfo?
    
    init() {
        loadMediaRemote()
        
        // Start polling every 1.5 seconds for track changes and major syncs
        timer = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateNowPlaying()
                self?.updateVolume()
            }
            
        // Local interpolation for smooth lyrics and scrubber
        lastTimerTick = Date()
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            let delta = now.timeIntervalSince(self.lastTimerTick)
            self.lastTimerTick = now
            
            if self.isPlaying {
                self.currentTime += delta
            }
        }
        
        updateNowPlaying()
        updateVolume()
    }
    
    private func loadMediaRemote() {
        let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        if let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) {
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
                getNowPlayingInfoFunc = unsafeBitCast(ptr, to: MRGetNowPlayingInfo.self)
            }
        }
    }
    
    func updateNowPlaying() {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                set current_state to player state as string
                if current_state is "playing" then
                    set track_name to name of current track
                    set artist_name to artist of current track
                    set artwork_url to artwork url of current track
                    set track_dur to duration of current track
                    set track_pos to player position
                    return "true|" & track_name & "|" & artist_name & "|" & artwork_url & "|" & track_dur & "|" & track_pos
                else if current_state is "paused" then
                    set track_name to name of current track
                    set artist_name to artist of current track
                    set artwork_url to artwork url of current track
                    set track_dur to duration of current track
                    set track_pos to player position
                    return "false|" & track_name & "|" & artist_name & "|" & artwork_url & "|" & track_dur & "|" & track_pos
                else
                    return "false|||||"
                end if
            end tell
        else if application "Music" is running then
            tell application "Music"
                set current_state to player state as string
                if current_state is "playing" then
                    set track_name to name of current track
                    set artist_name to artist of current track
                    set track_dur to duration of current track
                    set track_pos to player position
                    return "true|" & track_name & "|" & artist_name & "||" & track_dur & "|" & track_pos
                else if current_state is "paused" then
                    set track_name to name of current track
                    set artist_name to artist of current track
                    set track_dur to duration of current track
                    set track_pos to player position
                    return "false|" & track_name & "|" & artist_name & "||" & track_dur & "|" & track_pos
                else
                    return "false|||||"
                end if
            end tell
        end if
        return "none"
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                let output = scriptObject.executeAndReturnError(&error)
                if let resultStr = output.stringValue, resultStr != "none" {
                    let parts = resultStr.components(separatedBy: "|")
                    if parts.count >= 3 {
                        let isPlaying = parts[0] == "true"
                        let title = parts[1]
                        let artist = parts[2]
                        let artworkUrl = parts.count > 3 ? parts[3] : ""
                        
                        var dur: Double = 1
                        var pos: Double = 0
                        
                        if parts.count >= 6 {
                            if let d = Double(parts[4]), let p = Double(parts[5]) {
                                // Spotify duration is often in ms (e.g. 200000 for 200s)
                                dur = d > 10000 ? d / 1000.0 : d
                                pos = p
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.isPlaying = isPlaying
                            self.duration = max(dur, 1) // Prevent division by zero
                            
                            // Only sync position if the delta is significant to avoid stuttering against local interpolation.
                            // Since AppleScript takes time to execute, 'pos' might be slightly stale, so we trust local interpolation
                            // unless there's a major divergence (like user scrubbing or skipping).
                            if abs(self.currentTime - pos) > 2.0 {
                                self.currentTime = pos
                            }
                            
                            if title.isEmpty {
                                self.trackName = "No track playing"
                                self.artistName = ""
                            } else {
                                self.trackName = title
                                self.artistName = artist
                                self.fetchLyrics(track: title, artist: artist)
                            }
                            
                            if !artworkUrl.isEmpty {
                                self.fetchArtwork(from: artworkUrl)
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isPlaying = false
                        self.trackName = "No track playing"
                        self.artistName = ""
                    }
                }
            }
        }
    }
    
    private var currentArtworkURL: String = ""
    
    private func fetchArtwork(from urlString: String) {
        guard urlString != currentArtworkURL else { return }
        currentArtworkURL = urlString
        
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = NSImage(data: data) {
                // Extract dominant color in background
                let color = self.extractAverageColor(from: image)
                DispatchQueue.main.async {
                    self.artwork = image
                    self.dominantColor = color
                }
            }
        }.resume()
    }
    
    private func extractAverageColor(from image: NSImage) -> Color {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return .green }
              
        let filter = CIFilter(name: "CIAreaAverage")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        let extent = ciImage.extent
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter.outputImage else { return .green }
        
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return Color(red: Double(bitmap[0]) / 255.0,
                     green: Double(bitmap[1]) / 255.0,
                     blue: Double(bitmap[2]) / 255.0,
                     opacity: 1.0)
    }
    
    func togglePlayPause() {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify" to playpause
        else if application "Music" is running then
            tell application "Music" to playpause
        end if
        """
        executeApplescriptAsync(script)
        
        // Fast UI feedback
        isPlaying.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.updateNowPlaying() }
    }
    
    func nextTrack() {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify" to next track
        else if application "Music" is running then
            tell application "Music" to next track
        end if
        """
        executeApplescriptAsync(script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.updateNowPlaying() }
    }
    
    func previousTrack() {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify" to previous track
        else if application "Music" is running then
            tell application "Music" to previous track
        end if
        """
        executeApplescriptAsync(script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.updateNowPlaying() }
    }
    
    func seek(to time: Double) {
        currentTime = time
        let script = """
        if application "Spotify" is running then
            tell application "Spotify" to set player position to \(time)
        else if application "Music" is running then
            tell application "Music" to set player position to \(time)
        end if
        """
        executeApplescriptAsync(script)
        // Refresh soon after to sync properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.updateNowPlaying() }
    }
    
    private func updateVolume() {
        let script = "output volume of (get volume settings)"
        DispatchQueue.global(qos: .utility).async {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error)
                if error == nil, let valStr = result.stringValue, let val = Double(valStr) {
                    DispatchQueue.main.async {
                        // Only update if it's significantly different to avoid fighting the user's scrubbing
                        if abs(self.volume - val) > 2.0 {
                            self.volume = val
                        }
                    }
                }
            }
        }
    }
    
    func setVolume(_ newVolume: Double) {
        volume = newVolume
        let script = "set volume output volume \(Int(newVolume))"
        executeApplescriptAsync(script)
    }
    
    private var currentLyricsQuery: String = ""
    
    private func fetchLyrics(track: String, artist: String) {
        let query = "\(track)-\(artist)"
        guard query != currentLyricsQuery else { return }
        currentLyricsQuery = query
        
        DispatchQueue.main.async {
            self.isFetchingLyrics = true
            self.lyricsUnavailable = false
            self.lyrics = []
        }
        
        guard let encodedTrack = track.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/get?track_name=\(encodedTrack)&artist_name=\(encodedArtist)") else {
            DispatchQueue.main.async { self.lyricsUnavailable = true }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isFetchingLyrics = false
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let syncedLyrics = json["syncedLyrics"] as? String,
               !syncedLyrics.isEmpty {
                let parsed = self.parseLRC(syncedLyrics)
                DispatchQueue.main.async {
                    self.lyrics = parsed
                    self.lyricsUnavailable = parsed.isEmpty
                }
            } else {
                DispatchQueue.main.async {
                    self.lyricsUnavailable = true
                }
            }
        }.resume()
    }
    
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let lines = lrc.components(separatedBy: .newlines)
        
        // Regex to match [mm:ss.xx] or [mm:ss.xxx]
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
    
    private func executeApplescriptAsync(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
            }
        }
    }
}
