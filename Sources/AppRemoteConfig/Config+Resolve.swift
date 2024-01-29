import Foundation

extension Config {
    
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
