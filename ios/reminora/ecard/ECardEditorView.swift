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
    let initialAssets: [PHAsset]
    let onDismiss: () -> Void
    
    @Environment(\.eCardTemplateService) private var templateService
    @Environment(\.eCardEditor) private var eCardEditor
    @State private var currentECard: ECard?
    @State private var isLoading = false
    @State private var showingImagePicker = false
    @State private var selectedImageSlot: ImageSlot?
    @State private var showingTextEditor = false
    @State private var showingOverrideConfirmation = false
    @State private var pendingECardImage: UIImage?
    
    var body: some View {
        ZStack {
            // Black background for full-screen experience
            Color.black.ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Preview and editing section
                if let template = eCardEditor.currentTemplate {
                    previewSection(template: template)
                } else {
                    emptyStateSection
                }
                
                Spacer()
                
                // Template selection section at bottom
                templateSelectionSection
            }
            .padding(.top, 60) // Space for back button
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
            // Find first image slot and open image picker
            if let template = eCardEditor.currentTemplate,
               let firstImageSlot = template.imageSlots.first {
                selectedImageSlot = firstImageSlot
                showingImagePicker = true
            }
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
            if let slot = selectedImageSlot {
                ImagePickerView(
                    availableAssets: initialAssets,
                    onImageSelected: { asset in
                        assignImage(asset: asset, to: slot)
                        showingImagePicker = false
                    },
                    onDismiss: {
                        showingImagePicker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingTextEditor) {
            TextEditorView(
                textAssignments: Binding(
                    get: { eCardEditor.textAssignments },
                    set: { eCardEditor.textAssignments = $0 }
                ),
                textSlots: eCardEditor.currentTemplate?.textSlots ?? [],
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
                                eCardEditor.setCurrentTemplate(template)
                                setupECard(with: template)
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
        VStack(spacing: 16) {
            // SVG Preview with interactive elements
            ZStack {
                SVGPreviewView(
                    template: template,
                    imageAssignments: eCardEditor.imageAssignments,
                    textAssignments: eCardEditor.textAssignments,
                    onImageSlotTapped: { slot in
                        selectedImageSlot = slot
                        showingImagePicker = true
                    },
                    onTextSlotTapped: { slot in
                        // Handle text editing
                        editText(for: slot)
                    }
                )
                .frame(width: 300, height: 375) // Maintain aspect ratio
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 8)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
    }
    
    // MARK: - Image Assignment Section
    
    private func imageAssignmentSection(template: ECardTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Images")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(template.imageSlots) { slot in
                        ImageSlotCard(
                            slot: slot,
                            assignedAsset: eCardEditor.imageAssignments[slot.id],
                            onTap: {
                                selectedImageSlot = slot
                                showingImagePicker = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Text Editing Section
    
    private func textEditingSection(template: ECardTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(template.textSlots) { slot in
                VStack(alignment: .leading, spacing: 4) {
                    Text(slot.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField(slot.placeholder, text: Binding(
                        get: { eCardEditor.textAssignments[slot.id] ?? slot.placeholder },
                        set: { eCardEditor.textAssignments[slot.id] = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
        .padding(.horizontal, 16)
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
        // Only set up template if not already set (to handle persistence)
        if eCardEditor.currentTemplate == nil {
            // Auto-select template based on image orientation
            if let orientedTemplate = templateService.getTemplateForAssets(initialAssets) {
                eCardEditor.setCurrentTemplate(orientedTemplate)
                setupECard(with: orientedTemplate)
            } else if let firstTemplate = templateService.getAllTemplates().first {
                eCardEditor.setCurrentTemplate(firstTemplate)
                setupECard(with: firstTemplate)
            }
        }
    }
    
    private func setupECard(with template: ECardTemplate) {
        let initialImageAssignments: [String: String] = [:]
        var initialTextAssignments: [String: String] = [:]
        
        // Initialize text assignments with placeholders
        for textSlot in template.textSlots {
            initialTextAssignments[textSlot.id] = textSlot.placeholder
        }
        
        currentECard = ECard(
            templateId: template.id,
            imageAssignments: initialImageAssignments,
            textAssignments: initialTextAssignments
        )
    }
    
    private func assignImage(asset: PHAsset, to slot: ImageSlot) {
        eCardEditor.setImageAssignment(assetId: asset.localIdentifier, for: slot.id)
        updateECard()
    }
    
    private func editText(for slot: TextSlot) {
        // Text editing is handled by the TextField in textEditingSection
        // This method could be extended for more advanced text editing
        print("Edit text for slot: \(slot.id)")
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
        guard let template = eCardEditor.currentTemplate else { return }
        
        isLoading = true
        
        // Use ECardEditor to generate the image
        ECardEditor.shared.generateECardImage(
            template: template,
            imageAssignments: eCardEditor.imageAssignments,
            textAssignments: eCardEditor.textAssignments
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let image):
                    // Check if similar ECard already exists
                    self.checkForExistingECard(newImage: image) { shouldOverride in
                        if shouldOverride {
                            self.saveImageToPhotoLibrary(image)
                        } else {
                            self.pendingECardImage = image
                            self.showingOverrideConfirmation = true
                        }
                    }
                case .failure(let error):
                    print("❌ Failed to generate ECard: \(error)")
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
    let textSlots: [TextSlot]
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ForEach(textSlots) { slot in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(slot.id)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField(slot.placeholder, text: Binding(
                            get: { textAssignments[slot.id] ?? slot.placeholder },
                            set: { textAssignments[slot.id] = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: CGFloat(slot.fontSize)))
                    }
                }
                
                Spacer()
            }
            .padding()
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
    }
}

// MARK: - Supporting Views

private struct TemplateCard: View {
    let template: ECardTemplate
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.eCardTemplateService) private var templateService
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // SVG Template preview
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
        DispatchQueue.global(qos: .userInitiated).async {
            let thumbnail = templateService.generateThumbnail(for: template, size: CGSize(width: 80, height: 100))
            DispatchQueue.main.async {
                self.thumbnailImage = thumbnail
            }
        }
    }
}

private struct ImageSlotCard: View {
    let slot: ImageSlot
    let assignedAsset: PHAsset?
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                    
                    if let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
                }
                
                Text(slot.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: assignedAsset) { _, _ in
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard let asset = assignedAsset else {
            thumbnailImage = nil
            return
        }
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 120, height: 120),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.thumbnailImage = image
            }
        }
    }
}

// MARK: - SVG Preview View

private struct SVGPreviewView: View {
    let template: ECardTemplate
    let imageAssignments: [String: PHAsset]
    let textAssignments: [String: String]
    let onImageSlotTapped: (ImageSlot) -> Void
    let onTextSlotTapped: (TextSlot) -> Void
    
    @State private var renderedImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let renderedImage = renderedImage {
                // Show the actual rendered SVG
                Image(uiImage: renderedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture { coordinate in
                        handleTap(at: coordinate)
                    }
            } else {
                // Loading state
                Rectangle()
                    .fill(Color.white)
                    .overlay(
                        VStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Rendering...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                            } else {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        }
                    )
            }
        }
        .onAppear {
            renderPreview()
        }
        .onChange(of: template.id) { _, _ in
            renderPreview()
        }
        .onChange(of: imageAssignments) { _, _ in
            renderPreview()
        }
        .onChange(of: textAssignments) { _, _ in
            renderPreview()
        }
    }
    
    private func renderPreview() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Generate preview using ECardEditor's image generation logic
            ECardEditor.shared.generateECardImage(
                template: template,
                imageAssignments: imageAssignments,
                textAssignments: textAssignments
            ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch result {
                    case .success(let image):
                        self.renderedImage = image
                    case .failure(let error):
                        print("❌ Failed to render SVG preview: \(error)")
                        // Keep existing image or show error
                    }
                }
            }
        }
    }
    
    private func handleTap(at location: CGPoint) {
        // Convert tap coordinates to SVG coordinates and find the appropriate slot
        // This is a simplified implementation - in a real app you'd need proper coordinate transformation
        
        // For now, just trigger the first image slot when tapped in the upper area
        // and text slot when tapped in the lower area
        let normalizedY = location.y / 375.0 // Assuming 375 height
        
        if normalizedY < 0.7 { // Upper area - image slots
            if let firstImageSlot = template.imageSlots.first {
                onImageSlotTapped(firstImageSlot)
            }
        } else { // Lower area - text slots
            if let firstTextSlot = template.textSlots.first {
                onTextSlotTapped(firstTextSlot)
            }
        }
    }
}

private struct ImageSlotPreview: View {
    let slot: ImageSlot
    let assignedAsset: PHAsset?
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 200, height: 150)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 150)
                        .clipped()
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("Tap to add photo")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .cornerRadius(CGFloat(slot.cornerRadius))
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadImage()
        }
        .onChange(of: assignedAsset) { _, _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let asset = assignedAsset else {
            image = nil
            return
        }
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 400, height: 300),
            contentMode: .aspectFill,
            options: options
        ) { loadedImage, _ in
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
}

// MARK: - Image Picker View

private struct ImagePickerView: View {
    let availableAssets: [PHAsset]
    let onImageSelected: (PHAsset) -> Void
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
                        ImagePickerCell(asset: asset) {
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