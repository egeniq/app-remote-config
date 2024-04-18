import Foundation

public enum Platform: String, CaseIterable {
    case iOS = "iOS"
    case iOS_iPhone = "iOS.iPhone"
    case iOS_iPad = "iOS.iPad"
    case iOS_tv = "iOS.TV"
    case iOS_carplay = "iOS.CarPlay"
    case iOS_mac = "iOS.Mac"
    case linux = "Linux"
    case macOS = "macOS"
    case watchOS = "watchOS"
    case visionOS = "visionOS"
    case android = "Android"
    case android_phone = "Android.phone"
    case android_tablet = "Android.tablet"
    case android_tv = "Android.TV"
    case wearOS = "WearOS"
    case windows = "Windows"
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
