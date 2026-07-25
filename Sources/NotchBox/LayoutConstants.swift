import CoreGraphics

struct LayoutConstants {
    // Make these computed properties so they scale perfectly on ANY device
    static var expandedWidth: CGFloat {
        let notchWidth = NotchGeometry.getNotchRect().width
        // Keep the exact same wide aspect ratio relative to the device's actual notch!
        return max(420, notchWidth * 2.27)
    }
    
    static var expandedHeight: CGFloat {
        let notchHeight = NotchGeometry.getNotchRect().height
        return notchHeight * 5.1
    }
}
