import CoreGraphics

struct LayoutConstants {
    // Dynamic values for collapsed state based on physical screen notch
    static var collapsedWidth: CGFloat {
        return NotchGeometry.getNotchRect().width
    }
    
    static var collapsedHeight: CGFloat {
        return NotchGeometry.getNotchRect().height
    }
    
    // Make these computed properties so they scale perfectly on ANY device
    static var expandedWidth: CGFloat {
        let notchWidth = collapsedWidth
        // Keep the exact same wide aspect ratio relative to the device's actual notch!
        return max(CGFloat(420.0), notchWidth * 2.27)
    }
    
    static var expandedHeight: CGFloat {
        let notchHeight = NotchGeometry.getNotchRect().height
        return notchHeight * 5.1
    }
}
