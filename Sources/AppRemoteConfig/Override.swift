import Foundation

/// Override containing the settings to apply when it matches and/or is scheduled.
///
/// When an app matches with one of the conditions and if a schedule is set it contains the current time, the settings will override the default settings. The settings must use keys that are in use in the default settings or are listed as deprecated keys.
public struct Override {
    /// To be considered an override should match at least one of the conditions.
    public let conditions: [Condition]?
    
    /// Schedule to limit overriding settings in time
    public let schedule: Schedule?
    
    /// The additional settings that are applied when the override is applied. The keys should be either in use or listed as deprecated.
    public let settings: [String: Any]
    
    init(json: [String: Any]) {
        let matching = (json["matching"] as? [[String: Any]])?.map(Condition.init(json:))
        self.conditions = matching
        
        if let schedule = json["schedule"] as? [String: Any] {
            self.schedule = Schedule(json: schedule)
        } else {
            self.schedule = nil
        }
 
        if let settings = json["settings"] as? [String: Any] {
            self.settings = settings
        } else {
            settings = [:]
        }
    }
}
