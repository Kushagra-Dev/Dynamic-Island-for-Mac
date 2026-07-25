import Foundation

let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) else {
    print("Failed to load MediaRemote bundle")
    exit(1)
}

guard let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else {
    print("Failed to get function pointer")
    exit(1)
}

typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
let getNowPlayingInfo = unsafeBitCast(pointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)

getNowPlayingInfo(DispatchQueue.main) { info in
    print("Now Playing Info: \(info)")
    exit(0)
}

// Run the main runloop for 2 seconds
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    print("Timeout")
    exit(1)
}
RunLoop.main.run()
