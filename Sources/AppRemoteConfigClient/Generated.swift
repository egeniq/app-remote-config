import Dependencies
import Foundation
import Sharing

// @SharedReader(.appRemoteConfig("showPromo")) var showPromo = false
// @SharedReader(.newFeature) var newFeature

public extension SharedReaderKey where Self == AppRemoteConfigKey<Bool>.Default {
    static var newFeature: Self {
        Self[.appRemoteConfig("newFeature"), default: false]
    }
}

enum AppRemoteConfigClientKey: DependencyKey {
    static var liveValue: any AppRemoteConfigClient {
        LiveAppRemoteConfigClient(
            url: URL(string: "")!,
            publicKey: "",
            minimumRefreshInterval: 30,
            automaticRefreshInterval: 600,
            bundleIdentifier: "asdas",
            verificationHandler: { settings in
                var allKeys = Set(settings.keys)
                var incorrectKeys = Set<String>()
                var missingKeys = Set<String>()
        
                if let _ = settings["newFeature"] as? Bool  {
                    allKeys.remove("newFeature")
                } else {
                    if allKeys.contains("newFeature") {
                        allKeys.remove("newFeature")
                        incorrectKeys.insert("newFeature")
                    } else {
                        missingKeys.insert("newFeature")
                    }
                }
        
                if !allKeys.isEmpty || !incorrectKeys.isEmpty || !missingKeys.isEmpty {
                    throw AppRemoteConfigServiceError.keysMismatch(unhandled: allKeys, incorrect: incorrectKeys, missing: missingKeys)
                }
            }
        )
    }
}
