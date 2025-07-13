import Foundation
import CoreData
import Photos
import Vision
import UIKit
import CryptoKit

class PhotoEmbeddingService {
    static let shared = PhotoEmbeddingService()
    
    private init() {}
    
    // MARK: - Core Embedding Operations
    
    /// Compute embedding for a PHAsset and store in Core Data
    func computeAndStoreEmbedding(for asset: PHAsset, in context: NSManagedObjectContext) async -> Bool {
        // Check if embedding already exists and is up to date
        let existingEmbedding = await getEmbedding(for: asset, in: context)
        if let existing = existingEmbedding, existing.embedding != nil {
            // Check if photo was modified since last computation
            let assetModDate = asset.modificationDate ?? asset.creationDate ?? Date.distantPast
            let embeddingDate = existing.computedAt ?? Date.distantPast
            
            if assetModDate <= embeddingDate {
                print("⏭️ Embedding already exists and is up to date for asset: \(asset.localIdentifier)")
                return true
            } else {
                print("🔄 Photo modified since last embedding, recomputing for asset: \(asset.localIdentifier)")
            }
        }
        
        // Load image from asset
        guard let image = await loadImage(from: asset) else {
            print("Failed to load image for asset: \(asset.localIdentifier)")
            return false
        }
        
        // Compute embedding
        guard let embedding = await ImageEmbeddingService.shared.computeBasicEmbedding(for: image) else {
            print("Failed to compute embedding for asset: \(asset.localIdentifier)")
            return false
        }
        
        // Store in Core Data
        await MainActor.run {
            let photoEmbedding = existingEmbedding ?? PhotoEmbedding(context: context)
            photoEmbedding.localIdentifier = asset.localIdentifier
            setEmbeddingVector(embedding, for: photoEmbedding)
            photoEmbedding.computedAt = Date()
            photoEmbedding.creationDate = asset.creationDate
            photoEmbedding.modificationDate = asset.modificationDate
            photoEmbedding.imageHash = generateImageHash(image)
            
            do {
                try context.save()
                print("Successfully stored embedding for asset: \(asset.localIdentifier)")
            } catch {
                print("Failed to save embedding: \(error)")
            }
        }
        
        return true
    }
    
    /// Get existing embedding for a PHAsset
    func getEmbedding(for asset: PHAsset, in context: NSManagedObjectContext) async -> PhotoEmbedding? {
        let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", asset.localIdentifier)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Failed to fetch embedding: \(error)")
            return nil
        }
    }
    
    /// Find similar photos for a given PHAsset
    func findSimilarPhotos(to asset: PHAsset, in context: NSManagedObjectContext, threshold: Float = 0.7, limit: Int = 20) async -> [PhotoSimilarity] {
        // Get or compute embedding for target asset
        var targetEmbedding: PhotoEmbedding?
        
        if let existing = await getEmbedding(for: asset, in: context) {
            targetEmbedding = existing
        } else {
            // Compute embedding on the fly
            if await computeAndStoreEmbedding(for: asset, in: context) {
                targetEmbedding = await getEmbedding(for: asset, in: context)
            }
        }
        
        guard let target = targetEmbedding,
              let targetVector = getEmbeddingVector(from: target) else {
            print("No embedding available for target asset")
            return []
        }
        
        // Get all other embeddings
        let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "localIdentifier != %@ AND embedding != nil", asset.localIdentifier)
        
        do {
            let allEmbeddings = try context.fetch(fetchRequest)
            var similarities: [PhotoSimilarity] = []
            
            for embedding in allEmbeddings {
                guard let vector = getEmbeddingVector(from: embedding),
                      isPhotoAvailable(for: embedding) else { continue }
                
                let similarity = ImageEmbeddingService.shared.cosineSimilarity(targetVector, vector)
                if similarity >= threshold {
                    similarities.append(PhotoSimilarity(embedding: embedding, similarity: similarity))
                }
            }
            
            // Sort by similarity (highest first) and limit results
            similarities.sort { $0.similarity > $1.similarity }
            return Array(similarities.prefix(limit))
            
        } catch {
            print("Failed to fetch embeddings for similarity search: \(error)")
            return []
        }
    }
    
    // MARK: - Batch Operations
    
    /// Compute embeddings for all photos in the library using waterline approach
    func computeAllEmbeddings(in context: NSManagedObjectContext, progressCallback: @escaping (Int, Int) -> Void = { _, _ in }) async {
        let waterline = getEmbeddingWaterline()
        print("📊 Current embedding waterline: \(waterline?.description ?? "none")")
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.includeHiddenAssets = false
        
        // Only fetch photos newer than waterline
        if let waterline = waterline {
            fetchOptions.predicate = NSPredicate(format: "creationDate > %@", waterline as NSDate)
            print("📊 Only scanning photos newer than waterline")
        }
        
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalCount = allPhotos.count
        
        if totalCount == 0 {
            print("📊 No new photos to process since waterline")
            return
        }
        
        print("📊 Found \(totalCount) photos to process (newer than waterline)")
        
        var processedCount = 0
        var latestProcessedDate: Date?
        
        for index in 0..<totalCount {
            let asset = allPhotos.object(at: index)
            
            // Skip if embedding already exists
            if let existingEmbedding = await getEmbedding(for: asset, in: context),
               existingEmbedding.embedding != nil {
                print("📊 Skipping \(asset.localIdentifier) - embedding already exists")
                processedCount += 1
                latestProcessedDate = asset.creationDate ?? latestProcessedDate
                
                await MainActor.run {
                    progressCallback(processedCount, totalCount)
                }
                continue
            }
            
            let success = await computeAndStoreEmbedding(for: asset, in: context)
            processedCount += 1
            
            if success {
                latestProcessedDate = asset.creationDate ?? latestProcessedDate
                print("📊 Processed \(processedCount)/\(totalCount): \(asset.localIdentifier)")
            } else {
                print("📊 Failed \(processedCount)/\(totalCount): \(asset.localIdentifier)")
            }
            
            await MainActor.run {
                progressCallback(processedCount, totalCount)
            }
        }
        
        // Update waterline to latest processed photo date
        if let latestDate = latestProcessedDate {
            setEmbeddingWaterline(latestDate)
            print("📊 Updated embedding waterline to: \(latestDate)")
        }
    }
    
    /// Get statistics about embedding coverage
    func getEmbeddingStats(in context: NSManagedObjectContext) -> PhotoEmbeddingStats {
        // Count total photos
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalPhotos = allPhotos.count
        
        // Count embeddings
        let embeddingFetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
        embeddingFetchRequest.predicate = NSPredicate(format: "embedding != nil")
        
        do {
            let embeddingCount = try context.count(for: embeddingFetchRequest)
            let coverage = totalPhotos > 0 ? Float(embeddingCount) / Float(totalPhotos) : 0.0
            
            return PhotoEmbeddingStats(
                totalPhotos: totalPhotos,
                photosWithEmbeddings: embeddingCount,
                coverage: coverage
            )
        } catch {
            print("Failed to get embedding stats: \(error)")
            return PhotoEmbeddingStats(totalPhotos: totalPhotos, photosWithEmbeddings: 0, coverage: 0.0)
        }
    }
    
    /// Clean up embeddings for photos that no longer exist
    func cleanupOrphanedEmbeddings(in context: NSManagedObjectContext) async -> Int {
        let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
        
        do {
            let allEmbeddings = try context.fetch(fetchRequest)
            var removedCount = 0
            
            for embedding in allEmbeddings {
                if !isPhotoAvailable(for: embedding) {
                    context.delete(embedding)
                    removedCount += 1
                }
            }
            
            if removedCount > 0 {
                try context.save()
                print("Removed \(removedCount) orphaned embeddings")
            }
            
            return removedCount
            
        } catch {
            print("Failed to cleanup orphaned embeddings: \(error)")
            return 0
        }
    }
    
    /// Find potential duplicate photos
    func findDuplicates(in context: NSManagedObjectContext, threshold: Float = 0.95) async -> [DuplicatePhotoGroup] {
        let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "embedding != nil")
        
        do {
            let embeddings = try context.fetch(fetchRequest)
            var duplicateGroups: [DuplicatePhotoGroup] = []
            var processedEmbeddings: Set<NSManagedObjectID> = []
            
            for embedding in embeddings {
                if processedEmbeddings.contains(embedding.objectID) { continue }
                guard let targetVector = getEmbeddingVector(from: embedding) else { continue }
                
                var similarEmbeddings: [PhotoSimilarity] = []
                
                for otherEmbedding in embeddings {
                    if otherEmbedding.objectID == embedding.objectID { continue }
                    if processedEmbeddings.contains(otherEmbedding.objectID) { continue }
                    
                    guard let otherVector = getEmbeddingVector(from: otherEmbedding) else { continue }
                    
                    let similarity = ImageEmbeddingService.shared.cosineSimilarity(targetVector, otherVector)
                    if similarity >= threshold {
                        similarEmbeddings.append(PhotoSimilarity(embedding: otherEmbedding, similarity: similarity))
                        processedEmbeddings.insert(otherEmbedding.objectID)
                    }
                }
                
                if !similarEmbeddings.isEmpty {
                    duplicateGroups.append(DuplicatePhotoGroup(original: embedding, duplicates: similarEmbeddings))
                    processedEmbeddings.insert(embedding.objectID)
                }
            }
            
            return duplicateGroups
            
        } catch {
            print("Failed to find duplicates: \(error)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadImage(from asset: PHAsset, targetSize: CGSize = CGSize(width: 512, height: 512)) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true
            
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    private func generateImageHash(_ image: UIImage) -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return UUID().uuidString
        }
        
        let digest = SHA256.hash(data: imageData)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Convert float array to Data for Core Data storage
    func embeddingToData(_ embedding: [Float]) -> Data {
        return Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)
    }
    
    /// Convert Data back to float array
    func dataToEmbedding(_ data: Data) -> [Float] {
        return data.withUnsafeBytes {
            Array(UnsafeBufferPointer(start: $0.bindMemory(to: Float.self).baseAddress, count: data.count / MemoryLayout<Float>.size))
        }
    }
    
    // MARK: - PhotoEmbedding Helper Methods
    
    /// Get embedding vector from PhotoEmbedding
    private func getEmbeddingVector(from photoEmbedding: PhotoEmbedding) -> [Float]? {
        guard let embeddingData = photoEmbedding.embedding else {
            return nil
        }
        return dataToEmbedding(embeddingData)
    }
    
    /// Set embedding vector for PhotoEmbedding
    private func setEmbeddingVector(_ embedding: [Float], for photoEmbedding: PhotoEmbedding) {
        let data = embeddingToData(embedding)
        photoEmbedding.embedding = data
    }
    
    /// Check if photo still exists in library
    private func isPhotoAvailable(for photoEmbedding: PhotoEmbedding) -> Bool {
        guard let localIdentifier = photoEmbedding.localIdentifier else { return false }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return fetchResult.firstObject != nil
    }
    
    /// Get PHAsset for PhotoEmbedding
    func getPhotoAsset(for photoEmbedding: PhotoEmbedding) -> PHAsset? {
        guard let localIdentifier = photoEmbedding.localIdentifier else { return nil }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return fetchResult.firstObject
    }
    
    // MARK: - Waterline Management
    
    private let waterlineKey = "PhotoEmbeddingWaterline"
    
    /// Get the current embedding waterline (last processed photo date)
    private func getEmbeddingWaterline() -> Date? {
        return UserDefaults.standard.object(forKey: waterlineKey) as? Date
    }
    
    /// Set the embedding waterline (last processed photo date)
    private func setEmbeddingWaterline(_ date: Date) {
        UserDefaults.standard.set(date, forKey: waterlineKey)
    }
    
    /// Reset the waterline to force full re-scan on next computation
    func resetEmbeddingWaterline() {
        UserDefaults.standard.removeObject(forKey: waterlineKey)
        print("📊 Reset embedding waterline - next scan will process all photos")
    }
}

// MARK: - Supporting Types

struct PhotoSimilarity {
    let embedding: PhotoEmbedding
    let similarity: Float
    
    var percentage: Int {
        return Int(similarity * 100)
    }
    
    var photoAsset: PHAsset? {
        return PhotoEmbeddingService.shared.getPhotoAsset(for: embedding)
    }
}

struct DuplicatePhotoGroup {
    let original: PhotoEmbedding
    let duplicates: [PhotoSimilarity]
    
    var allEmbeddings: [PhotoEmbedding] {
        return [original] + duplicates.map { $0.embedding }
    }
    
    var count: Int {
        return duplicates.count + 1
    }
}

struct PhotoEmbeddingStats {
    let totalPhotos: Int
    let photosWithEmbeddings: Int
    let coverage: Float
    
    var coveragePercentage: Int {
        return Int(coverage * 100)
    }
}