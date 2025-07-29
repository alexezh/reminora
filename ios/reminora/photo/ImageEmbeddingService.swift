import Foundation
import CoreML
import Vision
import UIKit

// computes embedding for any picture
class ImageEmbeddingService {
    static let shared = ImageEmbeddingService()
    
    // Using Vision's VNCoreMLFeatureValueObservation with a pre-trained model
    // We'll use MobileNetV2 which is available by default in iOS
    private var model: VNCoreMLModel?
    
    private init() {
        setupModel()
    }
    
    private func setupModel() {
        // Note: We'll primarily use Vision's built-in VNGenerateImageFeaturePrintRequest
        // which doesn't require a specific model setup
        print("ImageEmbeddingService initialized - using Vision framework")
    }
    
    /// Compute embedding vector for an image using Vision's feature print
    /// Returns a feature vector suitable for similarity comparison
    func computeEmbedding(for image: UIImage) async -> [Float]? {
        // Use the basic embedding method which uses Vision's built-in feature extraction
        return await computeBasicEmbedding(for: image)
    }
    
    /// Alternative: Use a more basic approach with Vision's built-in feature extractor
    func computeBasicEmbedding(for image: UIImage) async -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            let resumeOnce: (([Float]?) -> Void) = { result in
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: result)
                }
            }
            
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if let error = error {
                    print("Feature print generation failed: \(error)")
                    resumeOnce(nil)
                    return
                }
                
                guard let results = request.results as? [VNFeaturePrintObservation],
                      let featurePrint = results.first else {
                    print("No feature print results")
                    resumeOnce(nil)
                    return
                }
                
                // Convert feature print to float array
                let embedding = self.featurePrintToFloatArray(featurePrint)
                resumeOnce(embedding)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform feature print request: \(error)")
                resumeOnce(nil)
            }
        }
    }
    
    /// Compute cosine similarity between two embedding vectors
    func cosineSimilarity(_ embedding1: [Float], _ embedding2: [Float]) -> Float {
        guard embedding1.count == embedding2.count else {
            print("Embedding vectors must have the same length")
            return 0.0
        }
        
        let dotProduct = zip(embedding1, embedding2).map(*).reduce(0, +)
        let magnitude1 = sqrt(embedding1.map { $0 * $0 }.reduce(0, +))
        let magnitude2 = sqrt(embedding2.map { $0 * $0 }.reduce(0, +))
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0.0 }
        
        return dotProduct / (magnitude1 * magnitude2)
    }
    
    func cosineSimilarity2(_ embedding1: [Float], _ embedding2: UnsafeBufferPointer<Float>) -> Float {
        guard embedding1.count == embedding2.count else {
            print("Embedding vectors must have the same length")
            return 0.0
        }

        var dotProduct: Float = 0
        var magnitude1: Float = 0
        var magnitude2: Float = 0

        for i in 0..<embedding1.count {
            let v1 = embedding1[i]
            let v2 = embedding2[i]

            dotProduct += v1 * v2
            magnitude1 += v1 * v1
            magnitude2 += v2 * v2
        }

        let mag1 = sqrt(magnitude1)
        let mag2 = sqrt(magnitude2)

        guard mag1 > 0 && mag2 > 0 else { return 0.0 }

        return dotProduct / (mag1 * mag2)
    }

    /// Find similar images by comparing embeddings
    func findSimilarImages(to targetEmbedding: [Float], in embeddings: [(String, [Float])], threshold: Float = 0.8) -> [(String, Float)] {
        var similarities: [(String, Float)] = []
        
        for (id, embedding) in embeddings {
            let similarity = cosineSimilarity(targetEmbedding, embedding)
            if similarity >= threshold {
                similarities.append((id, similarity))
            }
        }
        
        // Sort by similarity (highest first)
        similarities.sort { $0.1 > $1.1 }
        return similarities
    }
    
    // MARK: - Helper Methods
    
    private func multiArrayToFloatArray(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        var floatArray: [Float] = []
        floatArray.reserveCapacity(count)
        
        for i in 0..<count {
            floatArray.append(Float(multiArray[i].doubleValue))
        }
        
        return floatArray
    }
    
    private func featurePrintToFloatArray(_ featurePrint: VNFeaturePrintObservation) -> [Float] {
        let data = featurePrint.data
        let count = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes {
            Array(UnsafeBufferPointer(start: $0.bindMemory(to: Float.self).baseAddress, count: count))
        }
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
}

// MARK: - Image Preprocessing Utilities
extension ImageEmbeddingService {
    
    /// Get a downsized, preprocessed image suitable for analysis
    private func preprocessImage(_ image: UIImage, targetSize: CGSize = CGSize(width: 224, height: 224)) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
