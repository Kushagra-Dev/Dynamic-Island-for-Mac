import Foundation

let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) else { exit(1) }

guard let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationPlaybackState" as CFString) else { exit(1) }
typealias StateFunction = @convention(c) (DispatchQueue, @escaping (UInt32) -> Void) -> Void
let stateFunc = unsafeBitCast(pointer, to: StateFunction.self)

stateFunc(DispatchQueue.main) { state in
    print("Playback State: \(state)")
    exit(0)
}

RunLoop.main.run()
