import Foundation

let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) else { exit(1) }

guard let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else { exit(1) }
typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
let getNowPlayingInfo = unsafeBitCast(pointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)

getNowPlayingInfo(DispatchQueue.main) { info in
    let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
    print("Playback Rate: \(rate)")
    let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "No title"
    print("Title: \(title)")
    exit(0)
}

RunLoop.main.run()
