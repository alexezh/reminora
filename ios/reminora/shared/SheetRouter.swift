//
//  SheetRouter.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import SwiftUI
import Photos
import CoreData
import MapKit

// MARK: - Sheet Router
struct SheetRouter: View {
    @ObservedObject private var sheetStack: SheetStack
    @Environment(\.managedObjectContext) private var viewContext
    
    init(sheetStack: SheetStack = SheetStack.shared) {
        self.sheetStack = sheetStack
    }
    
    var body: some View {
        EmptyView()
            .sheet(item: Binding<SheetType?>(
                get: { sheetStack.currentSheet },
                set: { newValue in
                    if newValue == nil {
                        sheetStack.pop()
                    }
                }
            )) { sheetType in
                sheetContent(for: sheetType)
                    .presentationDetents(Set(sheetType.configuration.presentationDetents))
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(!sheetType.allowsBackgroundDismissal)
            }
    }
    
    @ViewBuilder
    private func sheetContent(for sheetType: SheetType) -> some View {
        switch sheetType {
        case .addPinFromPhoto(let asset):
            NavigationView {
                AddPinFromPhotoView(
                    asset: asset,
                    onDismiss: {
                        sheetStack.pop()
                    }
                )
            }
            
        case .addPinFromLocation(let location):
            NavigationView {
                AddPinFromLocationView(
                    location: location,
                    onDismiss: {
                        sheetStack.pop()
                    }
                )
            }
            
        case .pinDetail(let place, let allPlaces):
            PinDetailView(
                place: place,
                allPlaces: allPlaces,
                onBack: {
                    sheetStack.pop()
                }
            )
            
        case .userProfile(let userId, let userName, let userHandle):
            UserProfileView(
                userId: userId,
                userName: userName,
                userHandle: userHandle
            )
            
        case .similarPhotos(let targetAsset):
            SimilarPhotosGridView(targetAsset: targetAsset)
            
        case .duplicatePhotos:
            // Use a dummy asset for duplicate detection - PhotoSimilarityView will find all duplicates
            DuplicatePhotosView()
            
        case .photoSimilarity(let targetAsset):
            PhotoSimilarityView(targetAsset: targetAsset)
            
        case .quickList:
            QuickListWrapperView()
            
        case .allLists:
            AllListsWrapperView()
            
        case .shareSheet(let text, let url):
            ShareSheet(text: text, url: url)
            
        case .photoActionSheet(let asset):
            PhotoActionSheetWrapper(asset: asset)
            
        case .searchDialog:
            SearchDialogWrapper()
            
        case .nearbyPhotos(let centerLocation):
            NavigationView {
                NearbyPhotosGridView(
                    centerLocation: centerLocation,
                    onDismiss: {
                        sheetStack.pop()
                    }
                )
                .navigationBarTitleDisplayMode(.inline)
            }
            
        case .nearbyLocations(let searchLocation, let locationName):
            NearbyLocationsView(
                searchLocation: searchLocation,
                locationName: locationName
            )
            
        case .selectLocations(let initialAddresses, let onSave):
            SelectLocationsView(
                initialAddresses: initialAddresses,
                onSave: { addresses in
                    onSave(addresses)
                    sheetStack.pop()
                }
            )
            
        case .comments(let targetPhotoId):
            SimpleCommentsView(targetPhotoId: targetPhotoId)
            
        case .editAddresses(let initialAddresses, let onSave):
            SelectLocationsView(
                initialAddresses: initialAddresses,
                onSave: { addresses in
                    onSave(addresses)
                    sheetStack.pop()
                }
            )
        }
    }
}

// MARK: - Wrapper Views for Complex Cases

private struct DuplicatePhotosView: View {
    var body: some View {
        // Use first available photo as target for duplicate detection
        PhotoLibraryFirstAssetWrapper { firstAsset in
            if let asset = firstAsset {
                PhotoSimilarityView(targetAsset: asset)
            } else {
                VStack {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Photos Available")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

private struct PhotoLibraryFirstAssetWrapper<Content: View>: View {
    let content: (PHAsset?) -> Content
    @State private var firstAsset: PHAsset?
    
    var body: some View {
        content(firstAsset)
            .onAppear {
                loadFirstAsset()
            }
    }
    
    private func loadFirstAsset() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        firstAsset = fetchResult.firstObject
    }
}

private struct QuickListWrapperView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        RListService.createQuickListView(
            context: viewContext,
            userId: AuthenticationService.shared.currentAccount?.id ?? "",
            onPhotoTap: { asset in
                SheetStack.shared.pop() // Close current sheet
                // Handle photo tap - you might want to show SwipePhotoView
                print("📷 Quick List photo tapped: \(asset.localIdentifier)")
            },
            onPinTap: { place in
                SheetStack.shared.replace(with: .pinDetail(place: place, allPlaces: []))
            },
            onPhotoStackTap: { assets in
                SheetStack.shared.pop() // Close current sheet
                // Handle photo stack tap
                print("📷 Quick List photo stack tapped: \(assets.count) photos")
            }
        )
    }
}

private struct AllListsWrapperView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        AllRListsView(
            context: viewContext,
            userId: AuthenticationService.shared.currentAccount?.id ?? ""
        )
    }
}

private struct PhotoActionSheetWrapper: View {
    let asset: PHAsset
    @State private var isFavorite = false
    @State private var isInQuickList = false
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        PhotoActionSheet(
            isFavorite: isFavorite,
            isInQuickList: isInQuickList,
            onShare: {
                PhotoSharingService.shared.sharePhoto(asset)
                SheetStack.shared.pop()
            },
            onToggleFavorite: {
                toggleFavorite()
            },
            onToggleQuickList: {
                toggleQuickList()
            },
            onAddPin: {
                SheetStack.shared.replace(with: .addPinFromPhoto(asset: asset))
            },
            onFindSimilar: {
                SheetStack.shared.replace(with: .similarPhotos(targetAsset: asset))
            }
        )
        .onAppear {
            updateStates()
        }
    }
    
    private func updateStates() {
        isFavorite = asset.isFavorite
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        isInQuickList = RListService.shared.isPhotoInQuickList(asset, context: viewContext, userId: userId)
    }
    
    private func toggleFavorite() {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = !asset.isFavorite
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isFavorite = !self.isFavorite
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
    
    private func toggleQuickList() {
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let success = RListService.shared.togglePhotoInQuickList(asset, context: viewContext, userId: userId)
        
        if success {
            isInQuickList = !isInQuickList
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

private struct SearchDialogWrapper: View {
    @State private var searchText = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var currentFilter: PhotoFilterType = .notDisliked
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Search text field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Photos")
                        .font(.headline)
                    TextField("Enter search terms...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Date range picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date Range")
                        .font(.headline)
                    
                    DatePicker("Start Date", selection: Binding(
                        get: { startDate ?? Date.distantPast },
                        set: { startDate = $0 }
                    ), displayedComponents: .date)
                    
                    DatePicker("End Date", selection: Binding(
                        get: { endDate ?? Date() },
                        set: { endDate = $0 }
                    ), displayedComponents: .date)
                    
                    Button("Clear Dates") {
                        startDate = nil
                        endDate = nil
                    }
                    .foregroundColor(.blue)
                }
                
                // Filter buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filters")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach([PhotoFilterType.notDisliked, .favorites, .dislikes, .all], id: \.self) { filter in
                            Button(action: {
                                currentFilter = filter
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: filter.iconName)
                                    Text(filter.displayName)
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    currentFilter == filter
                                        ? Color.blue
                                        : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    currentFilter == filter
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Search Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        SheetStack.shared.pop()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        // Apply search filter logic here
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ApplySearchFilter"),
                            object: [
                                "searchText": searchText,
                                "startDate": startDate as Any,
                                "endDate": endDate as Any,
                                "filter": currentFilter
                            ]
                        )
                        SheetStack.shared.pop()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}