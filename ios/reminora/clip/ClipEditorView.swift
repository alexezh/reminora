//
//  ClipEditorView.swift
//  reminora
//
//  Created by Claude on 8/10/25.
//

import SwiftUI
import Photos
import AVKit

struct ClipEditorView: View {
    let initialAssets: [PHAsset]
    let onDismiss: () -> Void
    
    @Environment(\.clipEditor) private var clipEditor
    @Environment(\.clipManager) private var clipManager
    @State private var viewMode: ClipEditorMode = .list
    @State private var showingSettings = false
    @State private var previewVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var isExporting = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Mode switcher and controls
                headerSection
                
                // Main content based on mode
                switch viewMode {
                case .list:
                    listModeView
                case .player:
                    playerModeView
                }
                
                Spacer()
                
                // Bottom controls
                bottomControlsSection
            }
            .padding(.top, 20)
            .padding(.bottom, 100) // Space for FAB
            
            // Back button - top left
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            setupInitialState()
            
            // Set ActionSheet context to clip
            UniversalActionSheetModel.shared.setContext(.clip)
        }
        .onDisappear {
            // Reset context when view disappears
            UniversalActionSheetModel.shared.setContext(.lists)
        }
        .sheet(isPresented: $showingSettings) {
            clipSettingsView
        }
        .onChange(of: viewMode) { _, newMode in
            if newMode == .player {
                generatePreview()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Clip name
            if let clip = clipEditor.currentClip {
                Text(clip.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            // Mode switcher
            HStack(spacing: 0) {
                Button(action: { viewMode = .list }) {
                    Text("List")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewMode == .list ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewMode == .list ? Color.white : Color.clear)
                }
                
                Button(action: { viewMode = .player }) {
                    Text("Player")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewMode == .player ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewMode == .player ? Color.white : Color.clear)
                }
            }
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - List Mode View
    
    private var listModeView: some View {
        VStack(spacing: 16) {
            // Image list
            if !clipEditor.currentAssets.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(Array(clipEditor.currentAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                            ClipImageCell(
                                asset: asset,
                                index: index,
                                onRemove: {
                                    clipEditor.removeAsset(at: index)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                emptyStateView
            }
            
            // Add images button
            Button(action: {
                // TODO: Open photo picker to add more images
                print("📹 Add images button tapped")
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Images")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Player Mode View
    
    private var playerModeView: some View {
        VStack(spacing: 20) {
            // Video player
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(1.0, contentMode: .fit)
                    .frame(maxWidth: 350, maxHeight: 350)
                    .cornerRadius(12)
                    .background(Color.gray.opacity(0.2))
            } else if clipEditor.isGenerating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Generating Preview...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ProgressView(value: clipEditor.generationProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(width: 200)
                }
                .frame(width: 350, height: 350)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Tap to generate preview")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Button("Generate Preview") {
                        generatePreview()
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                }
                .frame(width: 350, height: 350)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
            }
            
            // Player controls
            if player != nil {
                HStack(spacing: 30) {
                    Button(action: restartVideo) {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        exportVideo()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControlsSection: some View {
        HStack {
            // Settings button
            Button(action: { showingSettings = true }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Clip info
            if let clip = clipEditor.currentClip {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(clipEditor.currentAssets.count) images")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(Int(clip.totalDuration))s total")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No Images")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Add images to create your clip")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Settings View
    
    private var clipSettingsView: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Clip name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clip Name")
                        .font(.headline)
                    
                    TextField("Enter clip name", text: Binding(
                        get: { clipEditor.currentClip?.name ?? "" },
                        set: { clipEditor.updateClip(name: $0) }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Duration per image
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration per Image")
                        .font(.headline)
                    
                    HStack {
                        Text("\(Int(clipEditor.currentClip?.duration ?? 2))s")
                            .frame(width: 40)
                        
                        Slider(
                            value: Binding(
                                get: { clipEditor.currentClip?.duration ?? 2.0 },
                                set: { clipEditor.updateClip(duration: $0) }
                            ),
                            in: 0.5...10.0,
                            step: 0.5
                        )
                    }
                }
                
                // Transition type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transition")
                        .font(.headline)
                    
                    Picker("Transition", selection: Binding(
                        get: { clipEditor.currentClip?.transition ?? .fade },
                        set: { clipEditor.updateClip(transition: $0) }
                    )) {
                        ForEach(ClipTransition.allCases, id: \.self) { transition in
                            Text(transition.displayName).tag(transition)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Clip Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        if !clipEditor.hasActiveSession {
            clipEditor.startEditing(with: initialAssets)
        }
    }
    
    private func generatePreview() {
        guard !clipEditor.isGenerating else { return }
        
        clipEditor.generateVideo { result in
            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    self.previewVideoURL = url
                    self.player = AVPlayer(url: url)
                    self.player?.play()
                }
            case .failure(let error):
                print("❌ Failed to generate preview: \(error)")
            }
        }
    }
    
    private var isPlaying: Bool {
        player?.rate != 0
    }
    
    private func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
    }
    
    private func restartVideo() {
        player?.seek(to: .zero)
        player?.play()
    }
    
    private func exportVideo() {
        // TODO: Implement video export to photo library
        print("📹 Export video button tapped")
    }
}

// MARK: - Supporting Views

enum ClipEditorMode {
    case list
    case player
}

struct ClipImageCell: View {
    let asset: PHAsset
    let index: Int
    let onRemove: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Image
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(1, contentMode: .fit)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .cornerRadius(8)
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .offset(x: 5, y: -5)
            
            // Index indicator
            VStack {
                Spacer()
                HStack {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(4)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { loadedImage, _ in
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
}