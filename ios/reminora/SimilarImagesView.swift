import SwiftUI
import CoreData

struct SimilarImagesView: View {
    let place: Place
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var similarPlaces: [PlaceSimilarity] = []
    @State private var isLoading = true
    @State private var selectedThreshold: Float = 0.7
    @State private var embeddingStats: EmbeddingStats?
    @State private var showingEmbeddingProgress = false
    
    private let thresholds: [Float] = [0.5, 0.6, 0.7, 0.8, 0.9, 0.95]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with stats
                if let stats = embeddingStats {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Image Analysis")
                                .font(.headline)
                            Spacer()
                            Button("Compute Missing") {
                                computeMissingEmbeddings()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(stats.imagesWithEmbeddings)/\(stats.totalImages) analyzed")
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
                                findSimilarImages()
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
                
                // Results
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Finding similar images...")
                        Spacer()
                    }
                } else if similarPlaces.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "photo.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No similar images found")
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
                            ForEach(Array(similarPlaces.enumerated()), id: \.offset) { index, similarity in
                                SimilarImageCard(
                                    place: similarity.place,
                                    similarity: similarity.similarity,
                                    rank: index + 1
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Similar Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEmbeddingProgress) {
            EmbeddingProgressView()
        }
        .onAppear {
            loadEmbeddingStats()
            findSimilarImages()
        }
    }
    
    private func loadEmbeddingStats() {
        embeddingStats = PlaceEmbeddingManager.shared.getEmbeddingStats(in: viewContext)
    }
    
    private func findSimilarImages() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let results = place.findSimilarPlaces(in: viewContext, threshold: selectedThreshold, limit: 20)
            
            DispatchQueue.main.async {
                similarPlaces = results
                isLoading = false
            }
        }
    }
    
    private func computeMissingEmbeddings() {
        showingEmbeddingProgress = true
        
        Task {
            await PlaceEmbeddingManager.shared.computeMissingEmbeddings(in: viewContext)
            
            await MainActor.run {
                showingEmbeddingProgress = false
                loadEmbeddingStats()
                findSimilarImages()
            }
        }
    }
}

struct SimilarImageCard: View {
    let place: Place
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
            
            // Place info
            if let post = place.post, !post.isEmpty {
                Text(post)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            if let dateAdded = place.dateAdded {
                Text(dateAdded, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let imageData = place.imageData else { return }
        image = UIImage(data: imageData)
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
                
                Text("Computing Image Embeddings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("This may take a while for large photo libraries...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
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
    SimilarImagesView(place: Place())
}