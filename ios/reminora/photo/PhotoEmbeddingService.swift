import Foundation
import CoreData
import Photos
import Vision
import UIKit
import CryptoKit

// compute embedding for photos
class PhotoEmbeddingService {
    static let shared = PhotoEmbeddingService()
    
    // Track failed assets to prevent infinite retry loops
    private var failedAssets: Set<String> = []
    private let maxRetryAttempts = 3
    private var retryAttempts: [String: Int] = [:]
    private let dataLock = NSLock() // Thread safety for failedAssets and retryAttempts
    
    private init() {}
    
    // MARK: - Core Embedding Operations
    
    /// Compute embedding for a PHAsset and store in Core Data
    func computeAndStoreEmbedding(for asset: PHAsset, in context: NSManagedObjectContext) async -> Bool {
        // Check if embeddings are supported on this device
        if !ImageEmbeddingService.shared.isEmbeddingSupported() {
            print("⏭️ Embedding computation not supported on this device")
            return false
        }
        
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
        
        // Check if this asset has failed too many times - thread-safe
        let assetId = asset.localIdentifier
        let (currentAttempts, shouldSkip) = dataLock.withLock {
            let attempts = retryAttempts[assetId] ?? 0
            let skip = failedAssets.contains(assetId) || attempts >= maxRetryAttempts
            return (attempts, skip)
        }
        
        if shouldSkip {
            print("⏭️ Skipping asset \(assetId) - failed \(currentAttempts) times, marked as permanently failed")
            return false
        }
        
        // Compute embedding
        guard let embedding = await ImageEmbeddingService.shared.computeBasicEmbedding(for: image) else {
            // Track the failure - thread-safe
            let newAttemptCount = currentAttempts + 1
            dataLock.withLock {
                retryAttempts[assetId] = newAttemptCount
                if newAttemptCount >= maxRetryAttempts {
                    failedAssets.insert(assetId)
                }
            }
            
            if newAttemptCount >= maxRetryAttempts {
                print("❌ Asset \(assetId) failed \(maxRetryAttempts) times, marking as permanently failed")
            } else {
                print("⚠️ Failed to compute embedding for asset: \(assetId) (attempt \(newAttemptCount)/\(maxRetryAttempts))")
            }
            return false
        }
        
        // Clear retry attempts on success - thread-safe
        _ = dataLock.withLock {
            retryAttempts.removeValue(forKey: assetId)
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
        return await withCheckedContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", asset.localIdentifier)
                fetchRequest.fetchLimit = 1
                
                do {
                    let results = try context.fetch(fetchRequest)
                    continuation.resume(returning: results.first)
                } catch {
                    print("Failed to fetch embedding: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Find similar photos for a given PHAsset
    func findSimilarPhotos(to asset: PHAsset, in context: NSManagedObjectContext, threshold: Float = 0.7, limit: Int = 20) async -> [PhotoSimilarity] {
        let findSimilarStartTime = CFAbsoluteTimeGetCurrent()
        
        // Get or compute embedding for target asset
        var targetEmbedding: PhotoEmbedding?
        var embeddingComputeTime: Double = 0
        
        if let existing = await getEmbedding(for: asset, in: context) {
            targetEmbedding = existing
            print("⚡ Using existing embedding for target asset")
        } else {
            // Compute embedding on the fly and time it
            let computeStartTime = CFAbsoluteTimeGetCurrent()
            let success = await computeAndStoreEmbedding(for: asset, in: context)
            embeddingComputeTime = CFAbsoluteTimeGetCurrent() - computeStartTime
            
            if success {
                targetEmbedding = await getEmbedding(for: asset, in: context)
                print("⏱️ Single embedding computation time: \(String(format: "%.3f", embeddingComputeTime)) seconds")
            }
        }
        
        guard let target = targetEmbedding,
              let targetVector = getEmbeddingVector(from: target) else {
            print("No embedding available for target asset")
            return []
        }
        
        // Get all other embeddings using thread-safe context access
        let allEmbeddings = await withCheckedContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "localIdentifier != %@ AND embedding != nil", asset.localIdentifier)
                
                do {
                    let embeddings = try context.fetch(fetchRequest)
                    continuation.resume(returning: embeddings)
                } catch {
                    print("Failed to fetch embeddings for similarity search: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
        
        var similarities: [PhotoSimilarity] = []
        
        for embedding in allEmbeddings {
            guard let embeddingData = embedding.embedding else {
                continue
            }
            
            // Calculate similarity safely outside the unsafe block
            let similarity: Float = embeddingData.withUnsafeBytes { bytes in
                let floats = bytes.bindMemory(to: Float.self)
                return ImageEmbeddingService.shared.cosineSimilarity2(targetVector, floats)
            }
            
            // Create PhotoSimilarity object outside the unsafe context
            if similarity >= threshold {
                similarities.append(PhotoSimilarity(embedding: embedding, similarity: similarity))
            }
        }
        
        // Sort by similarity (highest first) and limit results
        similarities.sort { $0.similarity > $1.similarity }
        let results = Array(similarities.prefix(limit))
        
        let totalTime = CFAbsoluteTimeGetCurrent() - findSimilarStartTime
        print("📊 findSimilarPhotos completed in \(String(format: "%.3f", totalTime)) seconds")
        print("📊 Found \(results.count) similar photos above threshold \(threshold)")
        if embeddingComputeTime > 0 {
            print("📊 Target embedding computation: \(String(format: "%.3f", embeddingComputeTime)) seconds")
        }
        
        return results
    }
    
    // MARK: - Batch Operations
    
    /// Compute embeddings for all photos in the library using waterline approach
    func computeAllEmbeddings(in context: NSManagedObjectContext, progressCallback: @escaping (Int, Int) -> Void = { _, _ in }) async {
        // Check if embeddings are supported on this device
        if !ImageEmbeddingService.shared.isEmbeddingSupported() {
            print("❌ Embedding computation not supported on this device - skipping batch processing")
            return
        }
        
        let batchStartTime = CFAbsoluteTimeGetCurrent()
        
        let waterline = getEmbeddingWaterline()
        print("📊 Current embedding waterline: \(waterline?.description ?? "none")")
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)] // Most recent first
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
        var totalComputeTime: Double = 0
        var actualComputeCount = 0
        
        for index in 0..<totalCount {
            let asset = allPhotos.object(at: index)
            
            // Skip if embedding already exists
            if let existingEmbedding = await getEmbedding(for: asset, in: context),
               existingEmbedding.embedding != nil {
                //print("📊 Skipping \(asset.localIdentifier) - embedding already exists")
                processedCount += 1
                latestProcessedDate = asset.creationDate ?? latestProcessedDate
                
                await MainActor.run {
                    progressCallback(processedCount, totalCount)
                }
                continue
            }
            
            // Skip if asset has permanently failed - thread-safe
            if dataLock.withLock { failedAssets.contains(asset.localIdentifier) } {
                print("📊 Skipping \(asset.localIdentifier) - permanently failed")
                processedCount += 1
                latestProcessedDate = asset.creationDate ?? latestProcessedDate
                
                await MainActor.run {
                    progressCallback(processedCount, totalCount)
                }
                continue
            }
            
            // Time the embedding computation
            let computeStartTime = CFAbsoluteTimeGetCurrent()
            let success = await computeAndStoreEmbedding(for: asset, in: context)
            let computeTime = CFAbsoluteTimeGetCurrent() - computeStartTime
            
            processedCount += 1
            
            if success {
                totalComputeTime += computeTime
                actualComputeCount += 1
                latestProcessedDate = asset.creationDate ?? latestProcessedDate
                print("📊 Processed \(processedCount)/\(totalCount): \(asset.localIdentifier) (\(String(format: "%.3f", computeTime))s)")
            } else {
                print("📊 Failed \(processedCount)/\(totalCount): \(asset.localIdentifier) (\(String(format: "%.3f", computeTime))s)")
            }
            
            await MainActor.run {
                progressCallback(processedCount, totalCount)
            }
        }
        
        // Update waterline to latest processed photo date
        // Since we're processing newest first, we want the oldest date we processed
        if let latestDate = latestProcessedDate {
            setEmbeddingWaterline(latestDate)
            print("📊 Updated embedding waterline to: \(latestDate)")
        }
        
        // Print timing statistics
        let totalBatchTime = CFAbsoluteTimeGetCurrent() - batchStartTime
        print("📊 ================= BATCH EMBEDDING STATS =================")
        print("📊 Total batch time: \(String(format: "%.3f", totalBatchTime)) seconds")
        print("📊 Photos processed: \(processedCount)/\(totalCount)")
        print("📊 Embeddings computed: \(actualComputeCount)")
        let (failedCount, failedIds) = dataLock.withLock {
            (failedAssets.count, Array(failedAssets).prefix(5))
        }
        print("📊 Permanently failed assets: \(failedCount)")
        if failedCount > 0 {
            print("📊 Failed asset IDs: \(failedIds.joined(separator: ", "))...")
        }
        
        if actualComputeCount > 0 {
            let avgComputeTime = totalComputeTime / Double(actualComputeCount)
            print("📊 Average embedding computation time: \(String(format: "%.3f", avgComputeTime)) seconds")
            print("📊 Total compute time: \(String(format: "%.3f", totalComputeTime)) seconds")
            print("📊 Overhead time: \(String(format: "%.3f", totalBatchTime - totalComputeTime)) seconds")
        }
        print("📊 ========================================================")
    }
    
    /// Get statistics about embedding coverage
    func getEmbeddingStats(in context: NSManagedObjectContext) -> PhotoEmbeddingStats {
        // Count total photos (Photos framework access is thread-safe)
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalPhotos = allPhotos.count
        
        // Count embeddings using context.perform synchronously
        var embeddingCount = 0
        context.performAndWait {
            let embeddingFetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
            embeddingFetchRequest.predicate = NSPredicate(format: "embedding != nil")
            
            do {
                embeddingCount = try context.count(for: embeddingFetchRequest)
            } catch {
                print("Failed to get embedding stats: \(error)")
                embeddingCount = 0
            }
        }
        
        let coverage = totalPhotos > 0 ? Float(embeddingCount) / Float(totalPhotos) : 0.0
        
        return PhotoEmbeddingStats(
            totalPhotos: totalPhotos,
            photosWithEmbeddings: embeddingCount,
            coverage: coverage
        )
    }
    
    /// Clean up embeddings for photos that no longer exist
    func cleanupOrphanedEmbeddings(in context: NSManagedObjectContext) async -> Int {
        return await withCheckedContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
                
                do {
                    let allEmbeddings = try context.fetch(fetchRequest)
                    var removedCount = 0
                    
                    for embedding in allEmbeddings {
                        if !self.isPhotoAvailable(for: embedding) {
                            context.delete(embedding)
                            removedCount += 1
                        }
                    }
                    
                    if removedCount > 0 {
                        try context.save()
                        print("Removed \(removedCount) orphaned embeddings")
                    }
                    
                    continuation.resume(returning: removedCount)
                    
                } catch {
                    print("Failed to cleanup orphaned embeddings: \(error)")
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    /// Find potential duplicate photos
    func findDuplicates(in context: NSManagedObjectContext, threshold: Float = 0.95) async -> [DuplicatePhotoGroup] {
        let embeddings = await withCheckedContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<PhotoEmbedding> = PhotoEmbedding.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "embedding != nil")
                
                do {
                    let results = try context.fetch(fetchRequest)
                    continuation.resume(returning: results)
                } catch {
                    print("Failed to find duplicates: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
        
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
            
            var hasResumed = false
            
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // Only resume continuation once, and only for the final result
                guard !hasResumed else { return }
                
                // Check if this is the final result (not a degraded/progressive image)
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if !isDegraded {
                    hasResumed = true
                    continuation.resume(returning: image)
                } else if image == nil {
                    // If we get nil and it's not degraded, we're done
                    hasResumed = true
                    continuation.resume(returning: nil)
                }
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
    
    /// Clear all failure tracking to allow retry of previously failed assets
    func clearFailureTracking() {
        dataLock.withLock {
            failedAssets.removeAll()
            retryAttempts.removeAll()
        }
        print("📊 Cleared all failure tracking - previously failed assets can be retried")
    }
    
    /// Get count of permanently failed assets
    func getFailedAssetsCount() -> Int {
        return dataLock.withLock { failedAssets.count }
    }
    
    // MARK: - Photo Stacking Methods
    
    /// Create photo stacks from assets using similarity-based grouping
    func createPhotoStacks(from assets: [PHAsset], in context: NSManagedObjectContext, 
                          preferenceManager: PhotoPreferenceManager,
                          lastEmbeddingCount: inout Int,
                          hasStacksBeenCleared: inout Bool,
                          hasTriggeredEmbeddingComputation: inout Bool) async -> [RPhotoStack] {
        
        return await createSimilarityBasedStacks(
            from: assets, 
            in: context, 
            preferenceManager: preferenceManager,
            lastEmbeddingCount: &lastEmbeddingCount,
            hasStacksBeenCleared: &hasStacksBeenCleared,
            hasTriggeredEmbeddingComputation: &hasTriggeredEmbeddingComputation
        )
    }
    
    /// Create similarity-based photo stacks
    private func createSimilarityBasedStacks(from assets: [PHAsset], 
                                           in context: NSManagedObjectContext,
                                           preferenceManager: PhotoPreferenceManager,
                                           lastEmbeddingCount: inout Int,
                                           hasStacksBeenCleared: inout Bool,
                                           hasTriggeredEmbeddingComputation: inout Bool) async -> [RPhotoStack] {
        // Check if similarity indices are available
        let embeddingStats = getEmbeddingStats(in: context)
        let hasEmbeddings = embeddingStats.photosWithEmbeddings > 0

        // Only print embedding stats if they're meaningful or different from last time
        if embeddingStats.photosWithEmbeddings != lastEmbeddingCount {
            print(
                "📊 Embedding coverage: \(embeddingStats.photosWithEmbeddings)/\(embeddingStats.totalPhotos) (\(embeddingStats.coveragePercentage)%)"
            )
            lastEmbeddingCount = embeddingStats.photosWithEmbeddings
        }

        // Clear existing stack IDs only once per session to avoid repeated work
        if !hasStacksBeenCleared {
            preferenceManager.clearAllStackIds()
            hasStacksBeenCleared = true
        }

        if !hasEmbeddings {
            // Only log and trigger computation once per session
            if !hasTriggeredEmbeddingComputation {
                print("📊 No similarity indices available, using individual photos")
                hasTriggeredEmbeddingComputation = true

                // Trigger embedding computation in background without blocking UI
                Task.detached {
                    await PhotoEmbeddingService.shared.computeAllEmbeddings(in: context) {
                        processed, total in
                        // Only log every 10 photos to reduce spam
                        if processed % 10 == 0 || processed == total {
                            print("📊 Computing embeddings: \(processed)/\(total)")
                        }
                    }
                }
            }
            return assets.map { RPhotoStack(assets: [$0]) }
        }

        // Limit processing to prevent hangs - process in batches
        let maxAssetsToProcess = 100
        let assetsToProcess = Array(assets.prefix(maxAssetsToProcess))

        var stacks: [RPhotoStack] = []
        var processedAssets: Set<String> = []
        let maxExistingStackId = preferenceManager.getMaxStackId()
        var currentStackId: Int32 = maxExistingStackId + 1  // Start after max existing stack ID
        print("📊 Starting stack creation with ID \(currentStackId) (max existing: \(maxExistingStackId))")

        // Process assets sequentially by time with yield points
        for i in 0..<assetsToProcess.count {
            let currentAsset = assetsToProcess[i]

            // Skip if already processed
            if processedAssets.contains(currentAsset.localIdentifier) {
                continue
            }

            var currentStack = [currentAsset]
            processedAssets.insert(currentAsset.localIdentifier)

            // Only compare with next sequential photos (by time) - limit comparison window
            let maxComparisons = 5  // Only compare with next 5 photos to prevent hangs
            let endIndex = min(i + maxComparisons + 1, assetsToProcess.count)

            for j in (i + 1)..<endIndex {
                let nextAsset = assetsToProcess[j]

                // Skip if already processed
                if processedAssets.contains(nextAsset.localIdentifier) {
                    break  // Stop checking if we hit a processed asset
                }

                // Check similarity between current stack's first photo and next photo
                let similarity = await getSimilarity(between: currentAsset, and: nextAsset, in: context)

                if let similarity = similarity, similarity > 0.95 {
                    print(
                        "📊 Found similar photos: \(currentAsset.localIdentifier) <-> \(nextAsset.localIdentifier) (similarity: \(Int(similarity * 100))%)"
                    )
                    currentStack.append(nextAsset)
                    processedAssets.insert(nextAsset.localIdentifier)
                } else {
                    // If similarity is not high enough or not available, stop stacking
                    break
                }
            }

            // Store stack ID for all photos in this stack if it has more than one photo
            if currentStack.count > 1 {
                for asset in currentStack {
                    preferenceManager.setStackId(for: asset, stackId: currentStackId)
                }
                print(
                    "📊 Created stack with ID \(currentStackId) containing \(currentStack.count) similar photos"
                )
                currentStackId += 1  // Increment for next stack
            }

            stacks.append(RPhotoStack(assets: currentStack))

            // Yield to prevent blocking main thread every 10 assets
            if i % 10 == 0 {
                await Task.yield()
            }
        }

        // Add remaining assets as individual stacks if we hit the limit
        if assets.count > maxAssetsToProcess {
            let remainingAssets = Array(assets.dropFirst(maxAssetsToProcess))
            let remainingStacks = remainingAssets.map { RPhotoStack(assets: [$0]) }
            stacks.append(contentsOf: remainingStacks)
            print(
                "📊 Added \(remainingAssets.count) remaining assets as individual photos (processing limit reached)"
            )
        }

        print("📊 Stored stack IDs for \(currentStackId - 1) similarity-based stacks")
        return stacks
    }

    /// Get similarity between two assets using their embeddings
    private func getSimilarity(between asset1: PHAsset, and asset2: PHAsset, in context: NSManagedObjectContext) async -> Float? {
        // Get embeddings for both assets
        guard
            let embedding1 = await getEmbedding(for: asset1, in: context),
            let embedding2 = await getEmbedding(for: asset2, in: context),
            let vector1 = getEmbeddingVector(from: embedding1),
            let vector2 = getEmbeddingVector(from: embedding2)
        else {
            return nil
        }

        return ImageEmbeddingService.shared.cosineSimilarity(vector1, vector2)
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
