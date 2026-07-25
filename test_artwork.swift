import Foundation

let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) else { exit(1) }

guard let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else { exit(1) }
typealias InfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
let infoFunc = unsafeBitCast(pointer, to: InfoFunction.self)

infoFunc(DispatchQueue.main) { info in
    if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
        print("Found artwork data of size \(data.count)")
    } else {
        print("No artwork data found in info dictionary")
        print("Keys present: \(info.keys.joined(separator: ", "))")
    }
    exit(0)
}

RunLoop.main.run()
