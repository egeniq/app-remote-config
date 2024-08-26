import Foundation

/// Lists supported platforms
public enum Platform: String, CaseIterable {
    /// iOS in any of its variants
    case iOS = "iOS"
    
    /// iOS on an iPhone
    case iOS_iPhone = "iOS.iPhone"
    
    /// iOS on an iPad
    case iOS_iPad = "iOS.iPad"
    
    /// iOS on an Apple TV
    case iOS_tv = "iOS.TV"
    
    /// iOS on CarPlay
    case iOS_carplay = "iOS.CarPlay"
    
    /// iOS on an a Mac using Catalyst
    case iOS_mac = "iOS.Mac"
    
    /// Linux
    case linux = "Linux"
    
    /// macOS
    case macOS = "macOS"
    
    /// watchOS
    case watchOS = "watchOS"
    
    /// visionOS
    case visionOS = "visionOS"
    
    /// Android in any of its variants
    case android = "Android"
    
    /// Android on a phone
    case android_phone = "Android.phone"
    
    /// Android on a table
    case android_tablet = "Android.tablet"
    
    /// Android on a tv
    case android_tv = "Android.TV"
    
    /// WearOS
    case wearOS = "WearOS"
    
    /// Windows
    case windows = "Windows"
    
    /// Unknown
    case unknown
    
    func applies(to other: Platform) -> Bool {
        // self can be ios
        // other can be ios.iphone
        // then match
        
        // self can be ios.iphone
        // other can be ios
        // then DO NOT match
        
        switch self {
        case .iOS:
            other.rawValue.hasPrefix(Platform.iOS.rawValue)
        case .android:
            other.rawValue.hasPrefix(Platform.android.rawValue)
        case .unknown:
            false
        default:
            self == other
        }
    }
}
