import SwiftUI
import CoreData
import Photos

struct SimilarPhotosGridView: View {
    let targetAsset: PHAsset
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var similarPhotos: [PhotoSimilarity] = []
    @State private var isLoading = true
    @State private var selectedThreshold: Float = 0.7
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private let thresholds: [Float] = [0.5, 0.6, 0.7, 0.8, 0.9]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Threshold selector
                VStack(spacing: 8) {
                    Text("Similarity Level")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        ForEach(thresholds, id: \.self) { threshold in
                            Button(action: {
                                selectedThreshold = threshold
                                findSimilarPhotos()
                            }) {
                                Text("\(Int(threshold * 100))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedThreshold == threshold 
                                            ? Color.blue 
                                            : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        selectedThreshold == threshold 
                                            ? .white 
                                            : .primary
                                    )
                                    .cornerRadius(16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Results
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Finding similar photos...")
                            .scaleEffect(1.2)
                        Spacer()
                    }
                } else if similarPhotos.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "photo.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Similar Photos")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("Try lowering the similarity threshold")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(similarPhotos.enumerated()), id: \.offset) { index, similarity in
                                if let asset = similarity.photoAsset {
                                    SimilarPhotoGridCell(
                                        asset: asset,
                                        similarity: similarity.similarity,
                                        rank: index + 1
                                    ) {
                                        // Handle photo tap - could open full view or select
                                        // For now, we'll just dismiss and show that photo
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100) // Extra space for safe area
                    }
                    
                    // Results summary
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(similarPhotos.count) similar photos found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                )
                            Spacer()
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("Similar Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            findSimilarPhotos()
        }
    }
    
    private func findSimilarPhotos() {
        isLoading = true
        
        Task {
            let results = await PhotoEmbeddingService.shared.findSimilarPhotos(
                to: targetAsset,
                in: viewContext,
                threshold: selectedThreshold,
                limit: 50 // Show more results in grid view
            )
            
            await MainActor.run {
                // Sort by similarity score (highest first)
                similarPhotos = results.sorted { $0.similarity > $1.similarity }
                isLoading = false
            }
        }
    }
}

struct SimilarPhotoGridCell: View {
    let asset: PHAsset
    let similarity: Float
    let rank: Int
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Photo
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 120)
                        .cornerRadius(12)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
                
                // Similarity overlay
                VStack {
                    HStack {
                        // Rank badge
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.8))
                                .frame(width: 28, height: 28)
                            Text("#\(rank)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        // Similarity percentage
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.8))
                                .frame(height: 24)
                            Text("\(Int(similarity * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isSynchronous = false
        options.resizeMode = .exact
        let size = CGSize(width: 300, height: 300)
        
        manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { img, _ in
            if let img = img {
                DispatchQueue.main.async {
                    self.image = img
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SimilarPhotosGridView(targetAsset: PHAsset())
}