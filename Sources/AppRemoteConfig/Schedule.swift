import Foundation

/// A schedule describes a period of time.
///
/// Omitting `from` means distant past and omitting `until` means distant future. Omitting both means the schedule will never be matched.
public struct Schedule {
    let matchNever: Bool
    
    /// Date-time from which onwards the settings should be applied.
    public let from: Date?
    
    /// Date-time from which onwards the settings should not be applied anymore.
    public let until: Date?
    
    static let dateFormatter = ISO8601DateFormatter()
    
    init(json: [String: Any]) {
        if let fromJSON = json["from"] {
            if let fromString = fromJSON as? String, let date = Self.dateFormatter.date(from: fromString) {
                from = date
            } else {
                matchNever = true
                from = nil
                until = nil
                return
            }
        } else {
            from = nil
        }
        
        if let untilJSON = json["until"] {
            if let untilString = untilJSON as? String, let date = Self.dateFormatter.date(from: untilString)  {
                until = date
            } else {
                matchNever = true
                until = nil
                return
            }
        } else {
            until = nil
        }
        
        matchNever = false
    }
    
    func contains(date: Date) -> Bool {
        if matchNever {
            return false
        }
        
        if let from, date.compare(from) == ComparisonResult.orderedAscending {
            return false
        }
        if let until, date.compare(until) != ComparisonResult.orderedAscending {
            return false
        }
        return true
    }
}
