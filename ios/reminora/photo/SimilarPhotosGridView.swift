import SwiftUI
import CoreData
import Photos

struct SimilarPhotosGridView: View {
    let targetAsset: PHAsset
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var similarPhotos: [PhotoSimilarity] = []
    @State private var isLoading = true
    @State private var selectedPhoto: PHAsset?
    @State private var showingSwipeView = false
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
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
                        Text("No visually similar photos found")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(Array(similarPhotos.enumerated()), id: \.offset) { index, similarity in
                                SimilarPhotoGridCell(
                                    similarity: similarity,
                                    rank: index + 1
                                ) { asset in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedPhoto = asset
                                        showingSwipeView = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
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
        .overlay(
            Group {
                if showingSwipeView, let photo = selectedPhoto {
                    // Create a temporary PhotoStack for single photo display  
                    let singlePhotoStack = PhotoStack(assets: [photo])
                    SwipePhotoView(
                        stack: singlePhotoStack,
                        initialIndex: 0,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingSwipeView = false
                                selectedPhoto = nil
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.1, anchor: .center)
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.1, anchor: .center)
                            .combined(with: .opacity)
                    ))
                    .zIndex(999)
                }
            }
        )
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
                threshold: 0.6, // Fixed threshold for better results
                limit: 50 // Show more results in grid view
            )
            
            await MainActor.run {
                // Sort by similarity score (highest first) and filter out invalid embeddings
                similarPhotos = results
                    .filter { $0.embedding.localIdentifier != nil } // Only keep valid embeddings
                    .sorted { $0.similarity > $1.similarity }
                isLoading = false
                print("✅ Found \(similarPhotos.count) similar photos")
            }
        }
    }
}

struct SimilarPhotoGridCell: View {
    let similarity: PhotoSimilarity
    let rank: Int
    let onTap: (PHAsset) -> Void
    
    @State private var image: UIImage?
    @State private var asset: PHAsset?
    
    var body: some View {
        Button(action: {
            if let asset = asset {
                onTap(asset)
            }
        }) {
            ZStack {
                // Photo
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 100)
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
                            Text("\(Int(similarity.similarity * 100))%")
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
            loadAssetAndImage()
        }
    }
    
    private func loadAssetAndImage() {
        // First get the PHAsset safely
        guard let localIdentifier = similarity.embedding.localIdentifier else {
            print("❌ No local identifier for embedding")
            return
        }
        
        // Fetch PHAsset on main queue to avoid threading issues
        DispatchQueue.main.async {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let fetchedAsset = fetchResult.firstObject else {
                print("❌ Could not fetch PHAsset for identifier: \(localIdentifier)")
                return
            }
            
            self.asset = fetchedAsset
            
            // Now load image
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isSynchronous = false
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = false // Avoid network requests
            let size = CGSize(width: 300, height: 300)
            
            manager.requestImage(
                for: fetchedAsset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { img, _ in
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