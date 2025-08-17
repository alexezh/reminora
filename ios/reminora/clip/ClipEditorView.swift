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
    let initialAssets: [RPhotoStack]
    let onDismiss: () -> Void
    
    @Environment(\.clipEditor) private var clipEditor
    @Environment(\.clipManager) private var clipManager
    @Environment(\.toolbarManager) private var toolbarManager
    @State private var viewMode: ClipEditorMode = .list
    @State private var showingSettings = false
    @State private var showingMusicPicker = false
    @State private var previewVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var isExporting = false
    
    var body: some View {
        ZStack {
            // Black background for full-screen experience
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
            }
            .padding(.top, 20) // Reduced space
            .padding(.bottom, LayoutConstants.toolbarHeight) // Space for FAB
        }
        .onAppear {
            setupInitialState()
            setupToolbar()
            
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
        .sheet(isPresented: $showingMusicPicker) {
            musicPickerView
        }
        .onChange(of: viewMode) { _, newMode in
            if newMode == .player {
                generatePreview()
            }
            setupToolbar() // Update toolbar when mode changes
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Header with clip name and mode switcher
            HStack {
                // Clip name (left side)
                if let clip = clipEditor.currentClip {
                    Text(clip.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Mode switcher (right side)
                HStack(spacing: 0) {
                    Button(action: { viewMode = .list }) {
                        Text("List")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(viewMode == .list ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(viewMode == .list ? Color.white : Color.clear)
                    }
                    
                    Button(action: { viewMode = .player }) {
                        Text("Player")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(viewMode == .player ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(viewMode == .player ? Color.white : Color.clear)
                    }
                }
                .background(Color.gray.opacity(0.3))
                .cornerRadius(6)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - List Mode View
    
    private var listModeView: some View {
        VStack(spacing: 16) {
            // Vertical list of slides
            if !clipEditor.currentAssets.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(clipEditor.currentAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                            ClipSlideRow(
                                asset: asset,
                                index: index,
                                clip: clipEditor.currentClip,
                                onRemove: {
                                    clipEditor.removeAsset(at: index)
                                },
                                onEdit: { 
                                    // For now, edit global clip settings when editing any slide
                                    showingSettings = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                emptyStateView
            }
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
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar Setup
    
    private func setupToolbar() {
        var toolbarButtons: [ToolbarButtonConfig] = []
        
        // Common buttons for both modes
        toolbarButtons.append(contentsOf: [
            ToolbarButtonConfig(
                id: "settings",
                title: "Settings",
                systemImage: "gearshape.fill",
                action: { showingSettings = true },
                color: .gray
            ),
            ToolbarButtonConfig(
                id: "effects",
                title: "Effects",
                systemImage: clipEditor.currentClip?.effect.systemImage ?? "camera.filters",
                action: { showingSettings = true }, // Opens settings to effect section
                color: .purple
            ),
            ToolbarButtonConfig(
                id: "music",
                title: "Music",
                systemImage: clipEditor.currentClip?.audioTrack != nil ? "music.note.list" : "music.note",
                action: { showingMusicPicker = true },
                color: clipEditor.currentClip?.audioTrack != nil ? .orange : .gray
            ),
            ToolbarButtonConfig(
                id: "add",
                title: "Add Photos",
                systemImage: "plus.circle.fill",
                action: { /* TODO: Add photos */ },
                color: .blue
            )
        ])
        
        // Mode-specific buttons
        if viewMode == .player && player != nil {
            // Player mode buttons
            toolbarButtons.append(contentsOf: [
                ToolbarButtonConfig(
                    id: "restart",
                    title: "Restart",
                    systemImage: "backward.end.fill",
                    action: { restartVideo() },
                    color: .orange
                ),
                ToolbarButtonConfig(
                    id: "playpause",
                    title: isPlaying ? "Pause" : "Play",
                    systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill",
                    action: { togglePlayPause() },
                    color: isPlaying ? .red : .green
                ),
                ToolbarButtonConfig(
                    id: "export",
                    title: "Export",
                    systemImage: "square.and.arrow.up",
                    action: { exportVideo() },
                    color: .purple
                )
            ])
        } else {
            // List mode or no player - show generate preview
            toolbarButtons.append(
                ToolbarButtonConfig(
                    id: "preview",
                    title: "Generate Preview",
                    systemImage: "play.circle.fill",
                    action: { generatePreview() },
                    color: .green
                )
            )
        }
        
        toolbarManager.updateCustomToolbar(buttons: toolbarButtons)
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
                
                // Orientation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Orientation")
                        .font(.headline)
                    
                    Picker("Orientation", selection: Binding(
                        get: { clipEditor.currentClip?.orientation ?? .square },
                        set: { clipEditor.updateClip(orientation: $0) }
                    )) {
                        ForEach(ClipOrientation.allCases, id: \.self) { orientation in
                            Text(orientation.displayName).tag(orientation)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Effects
                VStack(alignment: .leading, spacing: 8) {
                    Text("Effect")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ClipEffect.allCases, id: \.self) { effect in
                                Button(action: {
                                    clipEditor.updateClip(effect: effect)
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: effect.systemImage)
                                            .font(.title2)
                                            .foregroundColor(
                                                clipEditor.currentClip?.effect == effect ? .white : .primary
                                            )
                                        
                                        Text(effect.displayName)
                                            .font(.caption)
                                            .foregroundColor(
                                                clipEditor.currentClip?.effect == effect ? .white : .primary
                                            )
                                            .lineLimit(1)
                                    }
                                    .frame(width: 80, height: 60)
                                    .background(
                                        clipEditor.currentClip?.effect == effect 
                                            ? Color.blue 
                                            : Color.gray.opacity(0.2)
                                    )
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                // Audio Track
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio Track")
                        .font(.headline)
                    
                    if let audioTrack = clipEditor.currentClip?.audioTrack {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(audioTrack.title)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text(audioTrack.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Remove") {
                                clipEditor.updateClip(audioTrack: nil)
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Volume control
                        HStack {
                            Text("Volume")
                                .font(.subheadline)
                            
                            Slider(
                                value: Binding(
                                    get: { Double(audioTrack.volume) },
                                    set: { newVolume in
                                        var updatedTrack = audioTrack
                                        updatedTrack = AudioTrack(
                                            title: audioTrack.title,
                                            artist: audioTrack.artist,
                                            assetURL: audioTrack.assetURL,
                                            duration: audioTrack.duration,
                                            volume: Float(newVolume),
                                            fadeInDuration: audioTrack.fadeInDuration,
                                            fadeOutDuration: audioTrack.fadeOutDuration
                                        )
                                        clipEditor.updateClip(audioTrack: updatedTrack)
                                    }
                                ),
                                in: 0.0...1.0
                            )
                            
                            Text("\(Int(audioTrack.volume * 100))%")
                                .font(.caption)
                                .frame(width: 35)
                        }
                    } else {
                        Button("Add Music") {
                            showingMusicPicker = true
                        }
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
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
    
    // MARK: - Music Picker View
    
    private var musicPickerView: some View {
        MusicPickerView { selectedTrack in
            clipEditor.updateClip(audioTrack: selectedTrack)
            showingMusicPicker = false
        }
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
                    // Update toolbar when player is created
                    self.setupToolbar()
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
        // Update toolbar to reflect new play/pause state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            setupToolbar()
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

struct ClipSlideRow: View {
    let asset: PHAsset
    let index: Int
    let clip: Clip?
    let onRemove: () -> Void
    let onEdit: () -> Void
    
    @State private var image: UIImage?
    @State private var showingEditDialog = false
    @State private var slideOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Delete background (red)
            HStack {
                Spacer()
                Button(action: onRemove) {
                    VStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.title)
                            .foregroundColor(.white)
                        Text("Delete")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(width: 80)
                }
                .padding(.trailing, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.red)
            .cornerRadius(12)
            
            // Main row content
            HStack(spacing: 12) {
            // Photo thumbnail on left
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                }
                
                // Index number overlay
                VStack {
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(4)
            }
            
            // Slide info on right
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Slide \(index + 1)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                // Duration info
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(String(format: "%.1f", clip?.duration ?? 2.0))s duration")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                
                // Transition info
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("\(clip?.transition.displayName ?? "Fade") transition")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                
                // Effect info
                HStack {
                    Image(systemName: clip?.effect.systemImage ?? "photo")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("\(clip?.effect.displayName ?? "None") effect")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
            }
            
            Spacer()
            
                // Edit button only
                Button(action: {
                    showingEditDialog = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .offset(x: slideOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        if translation < 0 { // Only allow left swipe
                            slideOffset = max(translation, -100)
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let velocity = value.velocity.width
                        
                        if translation < -50 || velocity < -300 {
                            // Show delete button
                            withAnimation(.spring()) {
                                slideOffset = -100
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring()) {
                                slideOffset = 0
                            }
                        }
                    }
            )
        }
        .onAppear {
            loadThumbnail()
        }
        .sheet(isPresented: $showingEditDialog) {
            SlideEditDialog(
                asset: asset,
                index: index,
                clip: clip,
                onSave: { duration, transition, effect in
                    // Handle save - this will be implemented
                    showingEditDialog = false
                }
            )
        }
    }
    
    private func loadThumbnail() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 160, height: 160),
            contentMode: .aspectFill,
            options: options
        ) { loadedImage, _ in
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
}

// MARK: - Slide Edit Dialog

struct SlideEditDialog: View {
    let asset: PHAsset
    let index: Int
    let clip: Clip?
    let onSave: (TimeInterval, ClipTransition, ClipEffect) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var duration: TimeInterval
    @State private var transition: ClipTransition
    @State private var effect: ClipEffect
    
    init(asset: PHAsset, index: Int, clip: Clip?, onSave: @escaping (TimeInterval, ClipTransition, ClipEffect) -> Void) {
        self.asset = asset
        self.index = index
        self.clip = clip
        self.onSave = onSave
        self._duration = State(initialValue: clip?.duration ?? 2.0)
        self._transition = State(initialValue: clip?.transition ?? .fade)
        self._effect = State(initialValue: clip?.effect ?? .none)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Slide preview
                VStack(spacing: 12) {
                    Text("Slide \(index + 1)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration")
                            .font(.headline)
                        
                        HStack {
                            Text("\(String(format: "%.1f", duration))s")
                                .frame(width: 60)
                            
                            Slider(value: $duration, in: 0.5...10.0, step: 0.5)
                        }
                    }
                    
                    // Transition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transition")
                            .font(.headline)
                        
                        Picker("Transition", selection: $transition) {
                            ForEach(ClipTransition.allCases, id: \.self) { transition in
                                Text(transition.displayName).tag(transition)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Effect
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Effect")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ClipEffect.allCases, id: \.self) { effectOption in
                                    Button(action: {
                                        effect = effectOption
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: effectOption.systemImage)
                                                .font(.title2)
                                                .foregroundColor(effect == effectOption ? .white : .primary)
                                            
                                            Text(effectOption.displayName)
                                                .font(.caption)
                                                .foregroundColor(effect == effectOption ? .white : .primary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 80, height: 60)
                                        .background(effect == effectOption ? Color.blue : Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Slide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(duration, transition, effect)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Music Picker View

import MediaPlayer

struct MusicPickerView: View {
    let onSelection: (AudioTrack) -> Void
    
    @State private var musicItems: [MPMediaItem] = []
    @State private var isLoading = true
    @State private var hasPermission = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if !hasPermission {
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Music Access Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Allow access to your music library to add audio tracks to your clips")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Grant Access") {
                            requestMusicPermission()
                        }
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                    }
                    .padding()
                } else if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading Music...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else if musicItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Music Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("No music tracks were found in your library")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    List(musicItems, id: \.persistentID) { item in
                        Button(action: {
                            selectMusicItem(item)
                        }) {
                            HStack {
                                // Album artwork placeholder
                                ZStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(8)
                                    
                                    if let artwork = item.artwork {
                                        Image(uiImage: artwork.image(at: CGSize(width: 50, height: 50)) ?? UIImage())
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .cornerRadius(8)
                                            .clipped()
                                    } else {
                                        Image(systemName: "music.note")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title ?? "Unknown Title")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Text(item.artist ?? "Unknown Artist")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    
                                    if let album = item.albumTitle {
                                        Text(album)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(formatDuration(item.playbackDuration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Select Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            checkMusicPermission()
        }
    }
    
    private func checkMusicPermission() {
        let status = MPMediaLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            hasPermission = true
            loadMusicLibrary()
        case .notDetermined:
            requestMusicPermission()
        case .denied, .restricted:
            hasPermission = false
            isLoading = false
        @unknown default:
            hasPermission = false
            isLoading = false
        }
    }
    
    private func requestMusicPermission() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.hasPermission = true
                    self.loadMusicLibrary()
                case .denied, .restricted, .notDetermined:
                    self.hasPermission = false
                    self.isLoading = false
                @unknown default:
                    self.hasPermission = false
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadMusicLibrary() {
        DispatchQueue.global(qos: .userInitiated).async {
            let query = MPMediaQuery.songs()
            query.addFilterPredicate(MPMediaPropertyPredicate(value: false, forProperty: MPMediaItemPropertyIsCloudItem))
            
            let items = query.items ?? []
            
            DispatchQueue.main.async {
                self.musicItems = items
                self.isLoading = false
            }
        }
    }
    
    private func selectMusicItem(_ item: MPMediaItem) {
        let audioTrack = AudioTrack(
            title: item.title ?? "Unknown Title",
            artist: item.artist ?? "Unknown Artist",
            assetURL: item.assetURL?.absoluteString,
            duration: item.playbackDuration
        )
        
        onSelection(audioTrack)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
