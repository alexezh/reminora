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
    @State private var selectedTemplate: ECardTemplate?
    @State private var currentECard: ECard?
    @State private var selectedCategory: ECardCategory = .polaroid
    @State private var imageAssignments: [String: PHAsset] = [:]
    @State private var textAssignments: [String: String] = [:]
    @State private var isLoading = false
    @State private var showingImagePicker = false
    @State private var selectedImageSlot: ImageSlot?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Template selection section
                templateSelectionSection
                
                Divider()
                
                // Preview and editing section
                if let template = selectedTemplate {
                    previewSection(template: template)
                } else {
                    emptyStateSection
                }
                
                Spacer()
            }
            .navigationTitle("Create ECard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveECard()
                    }
                    .disabled(selectedTemplate == nil)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
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
    }
    
    // MARK: - Template Selection Section
    
    private var templateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ECardCategory.allCases, id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: {
                                selectedCategory = category
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Template thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templateService.getTemplates(for: selectedCategory)) { template in
                        TemplateCard(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id,
                            action: {
                                selectedTemplate = template
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
        .background(Color(.systemGray6))
    }
    
    // MARK: - Preview Section
    
    private func previewSection(template: ECardTemplate) -> some View {
        VStack(spacing: 16) {
            // SVG Preview with interactive elements
            ZStack {
                SVGPreviewView(
                    template: template,
                    imageAssignments: imageAssignments,
                    textAssignments: textAssignments,
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
            
            // Image assignment section
            if !template.imageSlots.isEmpty {
                imageAssignmentSection(template: template)
            }
            
            // Text editing section
            if !template.textSlots.isEmpty {
                textEditingSection(template: template)
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
                            assignedAsset: imageAssignments[slot.id],
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
                        get: { textAssignments[slot.id] ?? slot.placeholder },
                        set: { textAssignments[slot.id] = $0 }
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
                .foregroundColor(.gray)
            
            Text("Select a Template")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Choose from our collection of beautiful ECard templates above")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        // Auto-select first template
        let templates = templateService.getTemplates(for: selectedCategory)
        if let firstTemplate = templates.first {
            selectedTemplate = firstTemplate
            setupECard(with: firstTemplate)
        }
        
        // Auto-assign first image if available
        if let firstAsset = initialAssets.first,
           let template = selectedTemplate,
           let firstImageSlot = template.imageSlots.first {
            imageAssignments[firstImageSlot.id] = firstAsset
        }
    }
    
    private func setupECard(with template: ECardTemplate) {
        var initialImageAssignments: [String: String] = [:]
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
        imageAssignments[slot.id] = asset
        updateECard()
    }
    
    private func editText(for slot: TextSlot) {
        // Text editing is handled by the TextField in textEditingSection
        // This method could be extended for more advanced text editing
        print("Edit text for slot: \(slot.id)")
    }
    
    private func updateECard() {
        guard let template = selectedTemplate else { return }
        
        let imageIdentifiers = imageAssignments.mapValues { $0.localIdentifier }
        
        if let ecard = currentECard {
            currentECard = ecard.updated(
                imageAssignments: imageIdentifiers,
                textAssignments: textAssignments
            )
        }
    }
    
    private func saveECard() {
        guard let ecard = currentECard else { return }
        
        isLoading = true
        
        // TODO: Implement ECard persistence
        // This could save to Core Data, Files, or cloud storage
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            onDismiss()
        }
    }
}

// MARK: - Supporting Views

private struct CategoryButton: View {
    let category: ECardCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.blue : Color(.systemGray5)
            )
            .foregroundColor(
                isSelected ? .white : .primary
            )
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct TemplateCard: View {
    let template: ECardTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Template preview (simplified)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray4))
                    .frame(width: 80, height: 100)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("Preview")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    )
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
    
    var body: some View {
        ZStack {
            // For now, show a simplified preview
            // In a real implementation, you'd render the SVG with actual images
            Rectangle()
                .fill(Color.white)
                .overlay(
                    VStack {
                        Text("SVG Preview")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(template.name)
                            .font(.headline)
                            .padding()
                        
                        // Show image slots
                        ForEach(template.imageSlots) { slot in
                            ImageSlotPreview(
                                slot: slot,
                                assignedAsset: imageAssignments[slot.id],
                                onTap: { onImageSlotTapped(slot) }
                            )
                        }
                        
                        Spacer()
                        
                        // Show text content
                        ForEach(template.textSlots) { slot in
                            Text(textAssignments[slot.id] ?? slot.placeholder)
                                .font(.system(size: CGFloat(slot.fontSize)))
                                .multilineTextAlignment(.center)
                                .onTapGesture {
                                    onTextSlotTapped(slot)
                                }
                        }
                    }
                )
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