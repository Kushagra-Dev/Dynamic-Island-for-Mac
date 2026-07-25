import Foundation

let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) else { exit(1) }

guard let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString) else { exit(1) }
typealias IsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
let isPlayingFunc = unsafeBitCast(pointer, to: IsPlayingFunction.self)

// Wait a bit for XPC connection
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    isPlayingFunc(DispatchQueue.main) { isPlaying in
        print("Is Playing: \(isPlaying)")
        exit(0)
    }
}

RunLoop.main.run()
