import SwiftUI
import CoreData
import Photos

struct PhotoSimilarityView: View {
    let targetAsset: PHAsset
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var similarPhotos: [PhotoSimilarity] = []
    @State private var isLoading = true
    @State private var selectedThreshold: Float = 0.7
    @State private var embeddingStats: PhotoEmbeddingStats?
    @State private var showingEmbeddingProgress = false
    @State private var showingDuplicateDetection = false
    @State private var duplicateGroups: [DuplicatePhotoGroup] = []
    
    private let thresholds: [Float] = [0.5, 0.6, 0.7, 0.8, 0.9, 0.95]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with stats and actions
                if let stats = embeddingStats {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Photo Analysis")
                                .font(.headline)
                            Spacer()
                            
                            Button("Find Duplicates") {
                                findDuplicates()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            Button("Compute All") {
                                computeAllEmbeddings()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            Button("Reset Scan") {
                                resetScan()
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(stats.photosWithEmbeddings)/\(stats.totalPhotos) analyzed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ProgressView(value: stats.coverage)
                                    .frame(height: 4)
                            }
                            
                            Spacer()
                            
                            Text("\(stats.coveragePercentage)%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                }
                
                // Threshold selector
                VStack(spacing: 8) {
                    Text("Similarity Threshold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(thresholds, id: \.self) { threshold in
                            Button(action: {
                                selectedThreshold = threshold
                                findSimilarPhotos()
                            }) {
                                Text("\(Int(threshold * 100))%")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedThreshold == threshold ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedThreshold == threshold ? .white : .primary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Results section
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Finding similar photos...")
                        Spacer()
                    }
                } else if similarPhotos.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "photo.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No similar photos found")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        Text("Try lowering the similarity threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(Array(similarPhotos.enumerated()), id: \.offset) { index, similarity in
                                if let asset = PhotoEmbeddingService.shared.getPhotoAsset(for: similarity.embedding) {
                                    SimilarPhotoCard(
                                        asset: asset,
                                        similarity: similarity.similarity,
                                        rank: index + 1
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cleanup") {
                        cleanupOrphanedEmbeddings()
                    }
                    .font(.caption)
                }
            }
        }
        .sheet(isPresented: $showingEmbeddingProgress) {
            EmbeddingProgressView()
        }
        .sheet(isPresented: $showingDuplicateDetection) {
            DuplicatePhotosView(duplicateGroups: duplicateGroups)
        }
        .onAppear {
            loadEmbeddingStats()
            findSimilarPhotos()
        }
    }
    
    private func loadEmbeddingStats() {
        embeddingStats = PhotoEmbeddingService.shared.getEmbeddingStats(in: viewContext)
    }
    
    private func findSimilarPhotos() {
        isLoading = true
        
        Task {
            let results = await PhotoEmbeddingService.shared.findSimilarPhotos(
                to: targetAsset,
                in: viewContext,
                threshold: selectedThreshold,
                limit: 20
            )
            
            await MainActor.run {
                similarPhotos = results
                isLoading = false
            }
        }
    }
    
    private func computeAllEmbeddings() {
        showingEmbeddingProgress = true
        
        Task {
            await PhotoEmbeddingService.shared.computeAllEmbeddings(in: viewContext) { processed, total in
                // Progress updates could be shown here
            }
            
            await MainActor.run {
                showingEmbeddingProgress = false
                loadEmbeddingStats()
                findSimilarPhotos()
            }
        }
    }
    
    private func resetScan() {
        PhotoEmbeddingService.shared.resetEmbeddingWaterline()
        loadEmbeddingStats()
    }
    
    private func findDuplicates() {
        Task {
            let groups = await PhotoEmbeddingService.shared.findDuplicates(in: viewContext, threshold: 0.95)
            
            await MainActor.run {
                duplicateGroups = groups
                showingDuplicateDetection = true
            }
        }
    }
    
    private func cleanupOrphanedEmbeddings() {
        Task {
            let removedCount = await PhotoEmbeddingService.shared.cleanupOrphanedEmbeddings(in: viewContext)
            
            await MainActor.run {
                print("Cleaned up \(removedCount) orphaned embeddings")
                loadEmbeddingStats()
            }
        }
    }
}

struct SimilarPhotoCard: View {
    let asset: PHAsset
    let similarity: Float
    let rank: Int
    
    @State private var image: UIImage?
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 120)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                        )
                }
                
                // Rank badge
                VStack {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 24, height: 24)
                            Text("\(rank)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(4)
                
                // Similarity percentage
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.7))
                                .frame(height: 20)
                            Text("\(Int(similarity * 100))%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                        }
                    }
                }
                .padding(4)
            }
            
            // Photo info
            if let creationDate = asset.creationDate {
                Text(creationDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Photo metadata
            Text("\(asset.pixelWidth) × \(asset.pixelHeight)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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

struct DuplicatePhotosView: View {
    let duplicateGroups: [DuplicatePhotoGroup]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(duplicateGroups.enumerated()), id: \.offset) { index, group in
                        DuplicateGroupCard(group: group, groupIndex: index + 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("Duplicate Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct DuplicateGroupCard: View {
    let group: DuplicatePhotoGroup
    let groupIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Group \(groupIndex) - \(group.count) photos")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Original photo
                    if let originalAsset = PhotoEmbeddingService.shared.getPhotoAsset(for: group.original) {
                        VStack(spacing: 4) {
                            PhotoThumbnailView(asset: originalAsset)
                                .frame(width: 80, height: 80)
                            Text("Original")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Duplicate photos
                    ForEach(Array(group.duplicates.enumerated()), id: \.offset) { index, duplicate in
                        if let asset = PhotoEmbeddingService.shared.getPhotoAsset(for: duplicate.embedding) {
                            VStack(spacing: 4) {
                                PhotoThumbnailView(asset: asset)
                                    .frame(width: 80, height: 80)
                                Text("\(duplicate.percentage)%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 12)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EmbeddingProgressView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Computing Photo Embeddings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Analyzing your photo library for visual similarity...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Text("This may take a while for large libraries")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PhotoSimilarityView(targetAsset: PHAsset())
}