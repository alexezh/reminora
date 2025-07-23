import Foundation
import CoreData
import CoreLocation

/**
 * Service for filtering and searching pin entries with fuzzy matching
 */
class PinFilterService: ObservableObject {
    static let shared = PinFilterService()
    
    private init() {}
    
    /**
     * Performs fuzzy search on pin entries by location and title
     * @param places Array of Place objects to filter
     * @param searchText Text to search for
     * @param threshold Similarity threshold for fuzzy matching (0.0 to 1.0)
     * @return Filtered array of places matching the search criteria
     */
    func filterPins(_ places: [Place], searchText: String, threshold: Double = 0.6) -> [Place] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return places
        }
        
        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return places.filter { place in
            // Search in post/title
            if let post = place.post?.lowercased(), 
               containsFuzzy(text: post, query: query, threshold: threshold) {
                return true
            }
            
            // Search in location name/URL
            if let url = place.url?.lowercased(),
               containsFuzzy(text: url, query: query, threshold: threshold) {
                return true
            }
            
            // Search in locations field
            if let locations = place.locations?.lowercased(),
               containsFuzzy(text: locations, query: query, threshold: threshold) {
                return true
            }
            
            // Search in user names
            if let originalDisplayName = place.value(forKey: "originalDisplayName") as? String,
               containsFuzzy(text: originalDisplayName.lowercased(), query: query, threshold: threshold) {
                return true
            }
            
            if let originalUsername = place.value(forKey: "originalUsername") as? String,
               containsFuzzy(text: originalUsername.lowercased(), query: query, threshold: threshold) {
                return true
            }
            
            return false
        }
    }
    
    /**
     * Performs case-insensitive fuzzy string matching
     * @param text The text to search in
     * @param query The search query
     * @param threshold Minimum similarity score (0.0 to 1.0)
     * @return True if the query matches the text with given threshold
     */
    private func containsFuzzy(text: String, query: String, threshold: Double) -> Bool {
        // Handle edge cases
        guard !text.isEmpty && !query.isEmpty else { return false }
        guard threshold >= 0.0 && threshold <= 1.0 else { return false }
        
        // Exact match
        if text.contains(query) {
            return true
        }
        
        // Skip fuzzy matching for very short queries to avoid performance issues
        guard query.count >= 2 else { return false }
        
        // Calculate similarity using Levenshtein distance
        let similarity = calculateSimilarity(text: text, query: query)
        return similarity >= threshold
    }
    
    /**
     * Calculates similarity between two strings using normalized Levenshtein distance
     * @param text First string
     * @param query Second string
     * @return Similarity score between 0.0 and 1.0
     */
    private func calculateSimilarity(text: String, query: String) -> Double {
        let distance = levenshteinDistance(text, query)
        let maxLength = max(text.count, query.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /**
     * Calculates Levenshtein distance between two strings
     * @param s1 First string
     * @param s2 Second string
     * @return Edit distance between the strings
     */
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        // Handle empty string cases
        if s1.isEmpty { return s2.count }
        if s2.isEmpty { return s1.count }
        if s1 == s2 { return 0 }
        
        let string1 = Array(s1)
        let string2 = Array(s2)
        let length1 = string1.count
        let length2 = string2.count
        
        // Ensure non-negative lengths
        guard length1 >= 0 && length2 >= 0 else { return 0 }
        
        // Create matrix with bounds checking
        var matrix = Array(repeating: Array(repeating: 0, count: length2 + 1), count: length1 + 1)
        
        // Initialize first row and column
        for i in 0...length1 {
            matrix[i][0] = i
        }
        for j in 0...length2 {
            matrix[0][j] = j
        }
        
        // Calculate edit distance
        for i in 1...length1 {
            for j in 1...length2 {
                // Bounds check before accessing array elements
                guard i > 0 && j > 0 && i <= string1.count && j <= string2.count else { continue }
                
                let cost = string1[i - 1] == string2[j - 1] ? 0 : 1
                
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[length1][length2]
    }
    
    /**
     * Sorts filtered results by relevance
     * @param places Filtered places
     * @param searchText Original search query
     * @return Places sorted by relevance (best matches first)
     */
    func sortByRelevance(_ places: [Place], searchText: String) -> [Place] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return places.sorted { place1, place2 in
            let score1 = calculateRelevanceScore(place: place1, query: query)
            let score2 = calculateRelevanceScore(place: place2, query: query)
            return score1 > score2
        }
    }
    
    /**
     * Calculates relevance score for sorting search results
     * @param place Place to score
     * @param query Search query
     * @return Relevance score (higher is better)
     */
    private func calculateRelevanceScore(place: Place, query: String) -> Double {
        var score: Double = 0.0
        
        // Exact match in title gets highest score
        if let post = place.post?.lowercased(), post.contains(query) {
            score += post.hasPrefix(query) ? 10.0 : 5.0
        }
        
        // Location match gets medium score
        if let url = place.url?.lowercased(), url.contains(query) {
            score += url.hasPrefix(query) ? 8.0 : 3.0
        }
        
        // Locations field match gets medium score
        if let locations = place.locations?.lowercased(), locations.contains(query) {
            score += locations.hasPrefix(query) ? 7.0 : 3.5
        }
        
        // User name match gets lower score
        if let originalDisplayName = place.value(forKey: "originalDisplayName") as? String,
           originalDisplayName.lowercased().contains(query) {
            score += 2.0
        }
        
        if let originalUsername = place.value(forKey: "originalUsername") as? String,
           originalUsername.lowercased().contains(query) {
            score += 1.0
        }
        
        // Boost score for more recent pins
        if let dateAdded = place.dateAdded {
            let daysSinceAdded = Date().timeIntervalSince(dateAdded) / (24 * 60 * 60)
            score += max(0, 1.0 - (daysSinceAdded / 30.0)) // Decay over 30 days
        }
        
        return score
    }
}