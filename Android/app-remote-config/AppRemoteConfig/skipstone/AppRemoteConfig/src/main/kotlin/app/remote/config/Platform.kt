package app.remote.config

import skip.lib.*
import skip.lib.Array

import skip.foundation.*

enum class Platform(override val rawValue: String, @Suppress("UNUSED_PARAMETER") unusedp: Nothing? = null): CaseIterable, RawRepresentable<String> {
    iOS("iOS"),
    iOS_iPhone("iOS.iPhone"),
    iOS_iPad("iOS.iPad"),
    iOS_tv("iOS.TV"),
    iOS_carplay("iOS.CarPlay"),
    iOS_mac("iOS.Mac"),
    macOS("macOS"),
    watchOS("watchOS"),
    visionOS("visionOS"),
    android("Android"),
    android_phone("Android.phone"),
    android_tablet("Android.tablet"),
    android_tv("Android.TV"),
    wearOS("WearOS"),
    unknown("unknown");

    internal fun applies(to: Platform): Boolean {
        val other = to
        // self can be ios
        // other can be ios.iphone
        // then match

        // self can be ios.iphone
        // other can be ios
        // then DO NOT match

        return when (this) {
            Platform.iOS -> other.rawValue.hasPrefix(Platform.iOS.rawValue)
            Platform.android -> other.rawValue.hasPrefix(Platform.android.rawValue)
            Platform.unknown -> false
            else -> this == other
        }
    }

    companion object {
        val allCases: Array<Platform>
            get() = arrayOf(iOS, iOS_iPhone, iOS_iPad, iOS_tv, iOS_carplay, iOS_mac, macOS, watchOS, visionOS, android, android_phone, android_tablet, android_tv, wearOS, unknown)
    }
}

fun Platform(rawValue: String): Platform? {
    return when (rawValue) {
        "iOS" -> Platform.iOS
        "iOS.iPhone" -> Platform.iOS_iPhone
        "iOS.iPad" -> Platform.iOS_iPad
        "iOS.TV" -> Platform.iOS_tv
        "iOS.CarPlay" -> Platform.iOS_carplay
        "iOS.Mac" -> Platform.iOS_mac
        "macOS" -> Platform.macOS
        "watchOS" -> Platform.watchOS
        "visionOS" -> Platform.visionOS
        "Android" -> Platform.android
        "Android.phone" -> Platform.android_phone
        "Android.tablet" -> Platform.android_tablet
        "Android.TV" -> Platform.android_tv
        "WearOS" -> Platform.wearOS
        "unknown" -> Platform.unknown
        else -> null
    }
}
