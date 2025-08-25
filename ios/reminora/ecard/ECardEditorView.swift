//
//  ECardEditorView.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import SwiftUI
import Photos
import WebKit

struct ECardEditorView: View {
    let initialAssets: [RPhotoStack]
    let onDismiss: () -> Void
    
    @Environment(\.eCardTemplateService) private var templateService
    @Environment(\.eCardEditor) private var eCardEditor
    @State private var currentECard: ECard?
    @State private var testScene: OnionScene?
    @State private var previewImage: UIImage?
    @State private var renderingFailed = false
    @State private var showingImagePicker = false
    @State private var showingTextEditor = false
    @State private var showingOverrideConfirmation = false
    @State private var pendingECardImage: UIImage?
    
    var body: some View {
        ZStack {
            // Black background for full-screen experience
            Color.black.ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Preview section
                if let template = eCardEditor.currentTemplate {
                    previewSection(template: template)
                } else {
                    Text("Loading...")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: 400)
                }
                
                Spacer()
                
                // Template selection section
                templateSelectionSection
            }
            .padding(.top, 20) // Reduced space for back button
            .padding(.bottom, LayoutConstants.toolbarHeight) // Space for FAB
        }
        .onAppear {
            setupInitialState()
            
            // Set ActionSheet context to ecard
            UniversalActionSheetModel.shared.setContext(.ecard)
        }
        .onDisappear {
            // Reset context when view disappears
            UniversalActionSheetModel.shared.setContext(.lists)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ECardEditCaption"))) { _ in
            showingTextEditor = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ECardSelectImage"))) { _ in
            // Open image picker for asset selection
            showingImagePicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ECardSavePhoto"))) { _ in
            saveECard()
        }
        .alert("ECard Already Exists", isPresented: $showingOverrideConfirmation) {
            Button("Override", role: .destructive) {
                if let image = pendingECardImage {
                    saveImageToPhotoLibrary(image)
                    pendingECardImage = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingECardImage = nil
            }
        } message: {
            Text("A similar ECard already exists in your photo library. Do you want to override it?")
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(
                availableAssets: eCardEditor.currentAssets,
                onImageSelected: { asset in
                    assignImage(asset: asset.primaryAsset)
                    showingImagePicker = false
                },
                onDismiss: {
                    showingImagePicker = false
                }
            )
        }
        .sheet(isPresented: $showingTextEditor) {
            TextEditorView(
                textAssignments: Binding(
                    get: { eCardEditor.textAssignments },
                    set: { eCardEditor.textAssignments = $0 }
                ),
                onDismiss: {
                    showingTextEditor = false
                }
            )
        }
    }
    
    // MARK: - Template Selection Section
    
    private var templateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Template list (all templates)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templateService.getAllTemplates()) { template in
                        TemplateCard(
                            template: template,
                            isSelected: eCardEditor.currentTemplate?.id == template.id,
                            action: {
                                print("🎨 ECardEditorView: User selected template \(template.name)")
                                eCardEditor.setCurrentTemplate(template)
                                // setCurrentTemplate now handles fresh assignment, no need for setupECard
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 120)
        }
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Preview Section
    
    private func previewSection(template: ECardTemplate) -> some View {
        // Onion-based preview with real-time rendering
        OnionECardPreview(
            template: template,
            imageAssignments: eCardEditor.imageAssignments,
            textAssignments: eCardEditor.textAssignments,
            onImageTapped: {
                showingImagePicker = true
            },
            onTextTapped: {
                showingTextEditor = true
            }
        )
        .aspectRatio(template.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 400)
        .clipped()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 8)
    }
    
    
    // MARK: - Empty State
    
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Select a Template")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Choose from our collection of beautiful ECard templates below")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        // Set default template and assign first asset from current editor state
        if let defaultTemplate = templateService.getTemplate(id: "polaroid_classic"),
           let firstAsset = eCardEditor.currentAssets.first?.primaryAsset {
            print("🎨 Setting up template: \(defaultTemplate.name) with current asset: \(firstAsset.localIdentifier)")
            eCardEditor.setCurrentTemplate(defaultTemplate)
            eCardEditor.setImageAssignment(assetId: firstAsset.localIdentifier, for: "Image1")
            eCardEditor.setTextAssignment(text: "Caption", for: "Text1")
            setupECard(with: defaultTemplate)
            print("🎨 Setup complete - imageAssignments: \(eCardEditor.imageAssignments.count)")
        } else {
            print("❌ Failed to get template or current assets from editor")
            print("   Template available: \(templateService.getTemplate(id: "polaroid_classic") != nil)")
            print("   Current assets count: \(eCardEditor.currentAssets.count)")
        }
    }
    
    private func createTestSceneWithImage(with photoStack: RPhotoStack) {
        print("🎨 Creating polaroid scene with image for asset: \(photoStack.primaryAsset.localIdentifier)")
        
        Task {
            do {
                // Get default template from template service
                guard let template = templateService.getTemplate(id: "polaroid_classic") else {
                    throw NSError(domain: "ECardEditor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Template not found"])
                }
                
                let scene = try await templateService.createScene(
                    from: template,
                    asset: photoStack.primaryAsset,
                    caption: "Test Caption"
                )
                
                await MainActor.run {
                    testScene = scene
                    print("✅ Created polaroid scene with image and \(scene.layers.count) layers")
                    
                    // Trigger preview rendering
                    renderPreview()
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to create polaroid scene with image: \(error)")
                    // Create fallback scene with just rectangle
                    let fallbackScene = OnionScene(name: "Fallback", size: CGSize(width: 800, height: 1000))
                    fallbackScene.backgroundColor = "#FFFFFF"
                    testScene = fallbackScene
                    renderPreview()
                }
            }
        }
    }
    
    private func renderPreview() {
        guard let scene = testScene else { return }
        
        Task {
            do {
                let renderedImage = try await OnionRenderer.shared.renderPreview(scene: scene)
                await MainActor.run {
                    previewImage = renderedImage
                    print("✅ Preview rendering completed successfully")
                }
            } catch {
                await MainActor.run {
                    renderingFailed = true
                    print("❌ Preview rendering failed: \(error)")
                }
            }
        }
    }
    
    private func createTestScene(with photoStack: RPhotoStack) {
        print("🎨 Creating polaroid scene for asset: \(photoStack.primaryAsset.localIdentifier)")
        
        Task {
            do {
                // Get default template from template service
                guard let template = templateService.getTemplate(id: "polaroid_classic") else {
                    throw NSError(domain: "ECardEditor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Template not found"])
                }
                
                let scene = try await templateService.createScene(
                    from: template,
                    asset: photoStack.primaryAsset,
                    caption: "Test Caption"
                )
                
                await MainActor.run {
                    testScene = scene
                    print("✅ Created polaroid scene with \(scene.layers.count) layers, setting testScene state")
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to create polaroid scene: \(error)")
                    // Set empty scene to get out of loading state
                    let emptyScene = OnionScene(name: "Empty", size: CGSize(width: 800, height: 1000))
                    testScene = emptyScene
                }
            }
        }
    }
    

    private func renderScenePreview(scene: OnionScene) async {
        do {
            let previewImage = try await OnionRenderer.shared.renderPreview(scene: scene)
            print("✅ Rendered test scene preview")
        } catch {
            print("❌ Failed to render scene preview: \(error)")
        }
    }
    
    private func saveTestScene() {
        guard let scene = testScene else { return }
        
        Task {
            do {
                let result = try await OnionRenderer.shared.renderHighQuality(scene: scene, format: .jpeg)
                let image = result.image
                
                await MainActor.run {
                    saveImageToPhotoLibrary(image)
                }
            } catch {
                print("❌ Failed to render test scene: \(error)")
            }
        }
    }
    
    private func setupECard(with template: ECardTemplate) {
        // Assign initial assets if no existing assignments
        if eCardEditor.imageAssignments.isEmpty, !eCardEditor.currentAssets.isEmpty {
            // Assign first asset for the main image
            if let firstAsset = eCardEditor.currentAssets.first?.primaryAsset {
                eCardEditor.setImageAssignment(assetId: firstAsset.localIdentifier, for: "Image1")
            }
        }
        
        // Use existing image assignments from ECardEditor
        let imageIdentifiers = eCardEditor.imageAssignments.mapValues { $0.localIdentifier }
        
        // Initialize text assignments with default caption
        var textAssignments = eCardEditor.textAssignments
        if textAssignments["Text1"] == nil {
            textAssignments["Text1"] = "Caption"
        }
        
        currentECard = ECard(
            templateId: template.id,
            imageAssignments: imageIdentifiers,
            textAssignments: textAssignments
        )
        
        print("🎨 ECardEditorView: Setup ECard with \(imageIdentifiers.count) image assignments and \(textAssignments.count) text assignments")
    }
    
    private func assignImage(asset: PHAsset) {
        eCardEditor.setImageAssignment(assetId: asset.localIdentifier, for: "Image1")
        updateECard()
    }
    
    private func editText() {
        // Text editing is handled by the TextField in textEditingSection
        // This method could be extended for more advanced text editing
        print("Edit text for caption")
    }
    
    private func updateECard() {
        guard eCardEditor.currentTemplate != nil else { return }
        
        let imageIdentifiers = eCardEditor.imageAssignments.mapValues { $0.localIdentifier }
        
        if let ecard = currentECard {
            currentECard = ecard.updated(
                imageAssignments: imageIdentifiers,
                textAssignments: eCardEditor.textAssignments
            )
        }
    }
    
    private func saveECard() {
        guard let template = eCardEditor.currentTemplate,
              let primaryAsset = eCardEditor.currentAssets.first?.primaryAsset else { return }
        
        // Use template service to generate the scene
        Task {
            do {
                let scene = try await templateService.createScene(
                    from: template,
                    asset: primaryAsset,
                    caption: eCardEditor.textAssignments["Text1"] ?? "Caption"
                )
                
                let result = try await OnionRenderer.shared.renderHighQuality(scene: scene, format: .jpeg)
                let image = result.image
                
                await MainActor.run {
                    // Check if similar ECard already exists
                    self.checkForExistingECard(newImage: image) { shouldOverride in
                        if shouldOverride {
                            self.saveImageToPhotoLibrary(image)
                        } else {
                            self.pendingECardImage = image
                            self.showingOverrideConfirmation = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to generate ECard with template service: \(error)")
                }
            }
        }
    }
    
    private func checkForExistingECard(newImage: UIImage, completion: @escaping (Bool) -> Void) {
        // This is a simplified check - in a real implementation, you would:
        // 1. Generate a hash or signature of the new image
        // 2. Check against previously saved ECards
        // 3. Compare image similarity
        
        // For now, we'll assume no existing ECard and allow saving
        completion(true)
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        ECardEditor.shared.saveECardToPhotoLibrary(image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Switch to Photo tab after successful save
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: "Photo")
                    self.onDismiss()
                case .failure(let error):
                    print("❌ Failed to save ECard: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods - Continued
}

// MARK: - Text Editor View

private struct TextEditorView: View {
    @Binding var textAssignments: [String: String]
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Caption")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        TextField("Caption", text: Binding(
                            get: { textAssignments["Text1"] ?? "Caption" },
                            set: { textAssignments["Text1"] = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 24))
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
            }
            .navigationTitle("Edit Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Supporting Views

private struct TemplateCard: View {
    let template: ECardTemplate
    let isSelected: Bool
    let action: () -> Void
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Onion-rendered template preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .frame(width: 80, height: 100)
                    
                    if let thumbnail = thumbnailImage {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 78, height: 98)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("Loading...")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
                
                Text(template.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        Task {
            do {
                // Use template service to create scene for thumbnail
                // Create a dummy asset for thumbnail generation
                let dummyScene = OnionScene(name: "Thumbnail", size: CGSize(width: 80, height: 100))
                dummyScene.backgroundColor = "#FFFFFF"
                
                // Add placeholder layers for thumbnail
                let borderTransform = LayerTransform(
                    position: CGPoint(x: 5, y: 5),
                    size: CGSize(width: 70, height: 90)
                )
                
                var borderLayer = GeometryLayer(name: "Border", transform: borderTransform)
                borderLayer.shape = .rectangle
                borderLayer.fillColor = "#FFFFFF"
                borderLayer.strokeColor = "#E0E0E0"
                borderLayer.strokeWidth = 1
                borderLayer.cornerRadius = 4
                dummyScene.addLayer(borderLayer)
                
                let thumbnail = try await OnionRenderer.shared.renderPreview(scene: dummyScene)
                
                await MainActor.run {
                    self.thumbnailImage = thumbnail
                }
            } catch {
                print("❌ TemplateCard: Failed to generate thumbnail: \(error)")
            }
        }
    }
}

// MARK: - Image Picker View

private struct ImagePickerView: View {
    let availableAssets: [RPhotoStack]
    let onImageSelected: (RPhotoStack) -> Void
    let onDismiss: () -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(availableAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                        ImagePickerCell(asset: asset.primaryAsset) {
                            onImageSelected(asset)
                        }
                    }
                }
                .padding(2)
            }
            .navigationTitle("Select Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

private struct ImagePickerCell: View {
    let asset: PHAsset
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
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

// MARK: - Onion Preview View

private struct OnionECardPreview: View {
    let template: ECardTemplate
    let imageAssignments: [String: PHAsset]
    let textAssignments: [String: String]
    let onImageTapped: () -> Void
    let onTextTapped: () -> Void
    
    @State private var previewImage: UIImage?
    @State private var isRendering = false
    @State private var renderError: Error?
    
    var body: some View {
        ZStack {
            // Background
            Color.white
            
            if let previewImage = previewImage {
                // Show rendered preview with vertical flip for correct orientation
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(x: 1, y: -1) // Flip vertically for correct orientation
                    .onTapGesture { location in
                        handleTap(at: location)
                    }
            } else if isRendering {
                // Show loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Text("Rendering preview...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if renderError != nil {
                // Show error state
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Preview unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Show placeholder
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Loading preview...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Invisible tap areas for slots
            if previewImage != nil {
                overlayTapAreas()
            }
        }
        .onChange(of: template.id) { _ in
            print("🎨 OnionECardPreview: Template changed to \(template.name)")
            renderPreview()
        }
        .onChange(of: imageAssignments) { _ in
            print("🎨 OnionECardPreview: Image assignments changed")
            renderPreview()
        }
        .onChange(of: textAssignments) { _ in
            print("🎨 OnionECardPreview: Text assignments changed")
            renderPreview()
        }
        .onAppear {
            print("🎨 OnionECardPreview: View appeared for template \(template.name)")
            renderPreview()
        }
    }
    
    // MARK: - Preview Rendering
    
    private func renderPreview() {
        guard !isRendering else { return }
        
        isRendering = true
        renderError = nil
        
        print("🎨 OnionECardPreview: Starting render with \(imageAssignments.count) image assignments")
        
        Task {
            do {
                // Get first available asset from image assignments
                guard let firstAsset = imageAssignments.values.first else {
                    print("🎨 OnionECardPreview: No image assignments - creating placeholder scene")
                    // Create template-only scene for preview
                    let dummyScene = OnionScene(name: "Preview", size: CGSize(width: 400, height: 500))
                    dummyScene.backgroundColor = "#FFFFFF"
                    
                    let previewImg = try await OnionRenderer.shared.renderPreview(scene: dummyScene)
                    await MainActor.run {
                        self.previewImage = previewImg
                        self.isRendering = false
                    }
                    return
                }
                
                print("🎨 OnionECardPreview: Creating scene with asset: \(firstAsset.localIdentifier)")
                let scene = try await ECardTemplateService.shared.createScene(
                    from: template,
                    asset: firstAsset,
                    caption: textAssignments["Text1"] ?? "Caption"
                )
                
                print("🎨 OnionECardPreview: Scene created with \(scene.layers.count) layers, rendering...")
                let previewImg = try await OnionRenderer.shared.renderPreview(scene: scene)
                
                await MainActor.run {
                    self.previewImage = previewImg
                    self.isRendering = false
                    print("✅ OnionECardPreview: Render completed successfully")
                }
                
            } catch {
                await MainActor.run {
                    self.renderError = error
                    self.isRendering = false
                    print("❌ OnionECardPreview: Failed to render preview: \(error)")
                }
            }
        }
    }
    
    // MARK: - Tap Handling
    
    private func handleTap(at location: CGPoint) {
        // Convert tap location to template coordinates
        // This is a simplified implementation - you would need to map the tap location
        // to the corresponding slot based on the rendered image size and slot positions
    }
    
    @ViewBuilder
    private func overlayTapAreas() -> some View {
        GeometryReader { geometry in
            ZStack {
                // Image area tap (upper 70% of the preview)
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.7)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.35)
                    .onTapGesture {
                        onImageTapped()
                    }
                
                // Text area tap (lower 30% of the preview)
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.3)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.85)
                    .onTapGesture {
                        onTextTapped()
                    }
            }
        }
    }
}
