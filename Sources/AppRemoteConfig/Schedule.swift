import Foundation

struct Schedule {
    let matchNever: Bool
    var from: Date?
    var until: Date?
    
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
