import Foundation

public struct Override {
    var conditions: [Condition]?
    var schedule: Schedule?
    var settings: [String: Any]
    
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
