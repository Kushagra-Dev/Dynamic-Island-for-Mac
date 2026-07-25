import Foundation

let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) else { exit(1) }

guard let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString) else { exit(1) }
typealias IsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
let isPlayingFunc = unsafeBitCast(pointer, to: IsPlayingFunction.self)

guard let cmdPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else { exit(1) }
typealias SendCommandFunction = @convention(c) (Int, Any?) -> Bool
let sendCommandFunc = unsafeBitCast(cmdPointer, to: SendCommandFunction.self)

isPlayingFunc(DispatchQueue.main) { isPlaying in
    print("Is Playing: \(isPlaying)")
    
    // Toggle play pause: 2
    let success = sendCommandFunc(2, nil)
    print("Sent TogglePlayPause: \(success)")
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        exit(0)
    }
}

RunLoop.main.run()
