import Foundation
import CoreData

// MARK: - PinData Extensions
extension LocationInfo {
    
    /// Returns a safe address string, with fallback if address is nil
    var addressSafe: String {
        return address ?? "Not available"
    }
    
    var categorySafe: String {
        return category ?? ""
    }
}
