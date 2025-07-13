import Foundation
import CoreData
import CoreLocation
import UIKit

// MARK: - Place Entity Extensions for Embeddings
extension Place {
    
    // MARK: - Embedding Management
    
    /// Get the embedding vector as float array
    var embeddingVector: [Float]? {
        guard let embeddingData = self.value(forKey: "imageEmbedding") as? Data else {
            return nil
        }
        return ImageEmbeddingService.shared.dataToEmbedding(embeddingData)
    }
    
    /// Set the embedding vector from float array  
    func setEmbeddingVector(_ embedding: [Float]) {
        let data = ImageEmbeddingService.shared.embeddingToData(embedding)
        self.setValue(data, forKey: "imageEmbedding")
    }
    
    /// Check if this place has an embedding computed
    var hasEmbedding: Bool {
        return self.value(forKey: "imageEmbedding") as? Data != nil
    }
    
    /// Compute and store embedding for this place's image
    func computeEmbedding() async -> Bool {
        guard let imageData = self.imageData,
              let image = UIImage(data: imageData) else {
            print("No image data available for embedding computation")
            return false
        }
        
        // Use the basic embedding service which is more reliable
        if let embedding = await ImageEmbeddingService.shared.computeBasicEmbedding(for: image) {
            setEmbeddingVector(embedding)
            return true
        } else {
            print("Failed to compute embedding for place")
            return false
        }
    }
    
    /// Find similar places based on embedding similarity
    func findSimilarPlaces(in context: NSManagedObjectContext, threshold: Float = 0.8, limit: Int = 10) -> [PlaceSimilarity] {
        guard let targetEmbedding = self.embeddingVector else {
            print("No embedding available for comparison")
            return []
        }
        
        let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "imageEmbedding != nil AND self != %@", self)
        
        do {
            let places = try context.fetch(fetchRequest)
            var similarities: [PlaceSimilarity] = []
            
            for place in places {
                if let embedding = place.embeddingVector {
                    let similarity = ImageEmbeddingService.shared.cosineSimilarity(targetEmbedding, embedding)
                    if similarity >= threshold {
                        similarities.append(PlaceSimilarity(place: place, similarity: similarity))
                    }
                }
            }
            
            // Sort by similarity (highest first) and limit results
            similarities.sort { $0.similarity > $1.similarity }
            return Array(similarities.prefix(limit))
            
        } catch {
            print("Failed to fetch places for similarity comparison: \(error)")
            return []
        }
    }
}

// MARK: - Supporting Types

struct PlaceSimilarity {
    let place: Place
    let similarity: Float
    
    var percentage: Int {
        return Int(similarity * 100)
    }
}

// MARK: - Place Creation with Embedding

extension Place {
    
    /// Create a new Place with automatic embedding computation
    static func createWithEmbedding(
        context: NSManagedObjectContext,
        imageData: Data,
        location: CLLocation? = nil,
        post: String? = nil,
        url: String? = nil,
        dateAdded: Date? = nil
    ) async -> Place {
        let place = Place(context: context)
        place.imageData = imageData
        place.location = location?.encodedData
        place.post = post
        place.url = url
        place.dateAdded = dateAdded ?? Date()
        
        // Compute embedding in background
        Task.detached {
            if let image = UIImage(data: imageData) {
                if let embedding = await ImageEmbeddingService.shared.computeBasicEmbedding(for: image) {
                    await MainActor.run {
                        place.setEmbeddingVector(embedding)
                        do {
                            try context.save()
                        } catch {
                            print("Failed to save embedding: \(error)")
                        }
                    }
                }
            }
        }
        
        return place
    }
}

// Helper extension for CLLocation encoding
extension CLLocation {
    var encodedData: Data? {
        return try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
    }
}

// MARK: - Embedding Management Service

class PlaceEmbeddingManager {
    static let shared = PlaceEmbeddingManager()
    
    private init() {}
    
    /// Compute embeddings for all places that don't have them
    func computeMissingEmbeddings(in context: NSManagedObjectContext) async {
        let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "imageEmbedding == nil AND imageData != nil")
        
        do {
            let placesWithoutEmbeddings = try context.fetch(fetchRequest)
            print("Found \(placesWithoutEmbeddings.count) places without embeddings")
            
            for place in placesWithoutEmbeddings {
                let success = await place.computeEmbedding()
                if success {
                    print("Computed embedding for place: \(place.post ?? "Unknown")")
                    
                    // Save periodically to avoid memory issues
                    try context.save()
                } else {
                    print("Failed to compute embedding for place: \(place.post ?? "Unknown")")
                }
            }
            
            // Final save
            try context.save()
            print("Finished computing embeddings")
            
        } catch {
            print("Failed to fetch places or save embeddings: \(error)")
        }
    }
    
    /// Find duplicate or very similar images
    func findDuplicateImages(in context: NSManagedObjectContext, threshold: Float = 0.95) -> [DuplicateGroup] {
        let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "imageEmbedding != nil")
        
        do {
            let places = try context.fetch(fetchRequest)
            var duplicateGroups: [DuplicateGroup] = []
            var processedPlaces: Set<NSManagedObjectID> = []
            
            for place in places {
                if processedPlaces.contains(place.objectID) { continue }
                
                let similarities = place.findSimilarPlaces(in: context, threshold: threshold)
                if !similarities.isEmpty {
                    let duplicateGroup = DuplicateGroup(original: place, duplicates: similarities)
                    
                    // Mark all places in this group as processed
                    processedPlaces.insert(place.objectID)
                    for similarity in similarities {
                        processedPlaces.insert(similarity.place.objectID)
                    }
                    
                    duplicateGroups.append(duplicateGroup)
                }
            }
            
            return duplicateGroups
            
        } catch {
            print("Failed to find duplicate images: \(error)")
            return []
        }
    }
    
    /// Get embedding statistics
    func getEmbeddingStats(in context: NSManagedObjectContext) -> EmbeddingStats {
        let totalFetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        totalFetchRequest.predicate = NSPredicate(format: "imageData != nil")
        
        let embeddingFetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        embeddingFetchRequest.predicate = NSPredicate(format: "imageEmbedding != nil")
        
        do {
            let totalCount = try context.count(for: totalFetchRequest)
            let embeddingCount = try context.count(for: embeddingFetchRequest)
            
            return EmbeddingStats(
                totalImages: totalCount,
                imagesWithEmbeddings: embeddingCount,
                coverage: totalCount > 0 ? Float(embeddingCount) / Float(totalCount) : 0.0
            )
        } catch {
            print("Failed to get embedding stats: \(error)")
            return EmbeddingStats(totalImages: 0, imagesWithEmbeddings: 0, coverage: 0.0)
        }
    }
}

// MARK: - Supporting Types

struct DuplicateGroup {
    let original: Place
    let duplicates: [PlaceSimilarity]
    
    var allPlaces: [Place] {
        return [original] + duplicates.map { $0.place }
    }
    
    var count: Int {
        return duplicates.count + 1
    }
}

struct EmbeddingStats {
    let totalImages: Int
    let imagesWithEmbeddings: Int
    let coverage: Float
    
    var coveragePercentage: Int {
        return Int(coverage * 100)
    }
}