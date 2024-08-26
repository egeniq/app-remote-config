import Foundation

extension Config {
    
    /// Resolves which settings should be used by an app within its context
    /// - Parameters:
    ///   - date: The date at which the settings are used
    ///   - platform: The platform on which the app runs
    ///   - platformVersion: The version of the platform on which the app runs
    ///   - appVersion: The version of the app that runs
    ///   - variant: The variant of the app that runs
    ///   - buildVariant: The build variant of the app that runs
    ///   - language: The language in which the app runs
    /// - Returns: Resolved settings
    public func resolve(date: Date, platform: Platform, platformVersion: OperatingSystemVersion, appVersion: Version, variant: String? = nil, buildVariant: BuildVariant, language: String? = nil) -> [String: Any] {
        overrides.reduce(into: settings) { partialResult, override in
            let isScheduled: Bool
            if let schedule = override.schedule {
                isScheduled = schedule.contains(date: date)
            } else {
                isScheduled = true
            }
            
            let matches: Bool
            if let conditions = override.conditions {
                matches = conditions.contains(where: {
                    $0.matches(
                        platform: platform,
                        platformVersion: platformVersion,
                        appVersion: appVersion,
                        variant: variant,
                        buildVariant: buildVariant,
                        language: language
                    )
                })
            } else {
                matches = true
            }
            
            if isScheduled && matches {
                partialResult.merge(override.settings) { _, override in override }
            }
        }
    }
    
    /// Lists all dates on which resolving the config could give other setings
    /// - Parameters:
    ///   - platform: The platform on which the app runs
    ///   - platformVersion: The version of the platform on which the app runs
    ///   - appVersion: The version of the app that runs
    ///   - variant: The variant of the app that runs
    ///   - buildVariant: The build variant of the app that runs
    ///   - language: The language in which the app runs
    /// - Returns: List of relevant dates
    public func relevantResolutionDates(platform: Platform, platformVersion: OperatingSystemVersion, appVersion: Version, variant: String? = nil, buildVariant: BuildVariant, language: String? = nil) -> [Date] {
        overrides.reduce(into: [Date](), { partialResult, override in
            guard let schedule = override.schedule else {
               return
            }
            
            let matches: Bool
            if let conditions = override.conditions {
                matches = conditions.contains(where: {
                    $0.matches(
                        platform: platform,
                        platformVersion: platformVersion,
                        appVersion: appVersion,
                        variant: variant,
                        buildVariant: buildVariant,
                        language: language
                    )
                })
            } else {
                matches = true
            }
            
            if matches {
                if let from = schedule.from {
                    partialResult.append(from)
                }
                if let until = schedule.until {
                    partialResult.append(until)
                }
            }
        })
        .sorted()
    }

}
