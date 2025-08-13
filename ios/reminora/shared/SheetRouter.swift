//
//  SheetRouter.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import CoreData
import MapKit
import Photos
import SwiftUI

// MARK: - Sheet Router
struct SheetRouter: View {
    @ObservedObject private var sheetStack: SheetStack
    @Environment(\.managedObjectContext) private var viewContext

    init(sheetStack: SheetStack = SheetStack.shared) {
        self.sheetStack = sheetStack
    }

    var body: some View {
        EmptyView()
            .sheet(
                item: Binding<SheetType?>(
                    get: { sheetStack.currentSheet },
                    set: { newValue in
                        if newValue == nil {
                            sheetStack.pop()
                        }
                    }
                )
            ) { sheetType in
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

        case .duplicatePhotos(let targetAsset):
            SimilarPhotoView(targetAsset: targetAsset)

        // case .photoSimilarity(let targetAsset):
        //     PhotoSimilarityView(targetAsset: targetAsset)

        case .quickList:
            QuickListWrapperView()

        case .allLists:
            AllListsWrapperView()

        case .shareSheet(let text, let url):
            ShareSheet(text: text, url: url)

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

        case .eCardEditor(let assets):
            NavigationView {
                ECardEditorView(
                    initialAssets: assets,
                    onDismiss: {
                        sheetStack.pop()
                    }
                )
            }
            
        case .clipEditor(let assets):
            NavigationView {
                ClipEditorView(
                    initialAssets: assets,
                    onDismiss: {
                        sheetStack.pop()
                    }
                )
            }
        }
    }
}

// MARK: - Wrapper Views for Complex Cases

private struct QuickListWrapperView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        RListService.createQuickListView(
            context: viewContext,
            userId: AuthenticationService.shared.currentAccount?.id ?? "",
            onPhotoStackTap: { photoStack in
                SheetStack.shared.pop()  // Close current sheet
                // Handle photo stack tap (both single photos and multi-photo stacks)
                print("📷 Quick List photo stack tapped: \(photoStack.count) photos")
            },
            onPinTap: { place in
                SheetStack.shared.replace(with: .pinDetail(place: place, allPlaces: []))
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

                    DatePicker(
                        "Start Date",
                        selection: Binding(
                            get: { startDate ?? Date.distantPast },
                            set: { startDate = $0 }
                        ), displayedComponents: .date)

                    DatePicker(
                        "End Date",
                        selection: Binding(
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
                        ForEach(
                            [PhotoFilterType.notDisliked, .favorites, .dislikes, .all], id: \.self
                        ) { filter in
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
                                "filter": currentFilter,
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
