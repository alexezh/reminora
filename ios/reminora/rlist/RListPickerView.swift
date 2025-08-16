import SwiftUI
import CoreData
import CoreLocation

struct RListPickerView: View {
    let place: LocationInfo
    @Binding var isPresented: Bool
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    
    @FetchRequest private var userLists: FetchedResults<RListData>
    @FetchRequest private var listItems: FetchedResults<RListItemData>
    @State private var isSaving = false
    
    init(place: LocationInfo, isPresented: Binding<Bool>) {
        self.place = place
        self._isPresented = isPresented
        
        // Fetch user's lists
        self._userLists = FetchRequest<RListData>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \RListData.name, ascending: true)
            ],
            predicate: NSPredicate(format: "userId == %@", AuthenticationService.shared.currentAccount?.id ?? ""),
            animation: .default
        )
        
        self._listItems = FetchRequest<RListItemData>(
            sortDescriptors: [NSSortDescriptor(keyPath: \RListItemData.addedAt, ascending: false)],
            animation: .default
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Place info header
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(place.address ?? "No address")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Lists
                List {
                    if userLists.isEmpty {
                        // Show default "My Pins" option when no lists exist
                        Button(action: {
                            createDefaultListAndSave()
                        }) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("My Pins")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text("Create default list")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .disabled(isSaving)
                    } else {
                        ForEach(userLists, id: \.id) { list in
                            Button(action: {
                                saveToList(list)
                            }) {
                                HStack {
                                    Image(systemName: list.name == "Quick" ? "bolt.fill" : "list.bullet")
                                        .foregroundColor(list.name == "Quick" ? .orange : .blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(list.name ?? "Untitled List")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Text("\(itemCount(for: list)) items")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isSaving {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                            .disabled(isSaving)
                        }
                    }
                }
            }
            .navigationTitle("Pin to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func saveToList(_ list: RListData) {
        isSaving = true
        
        // Create the place
        let newPlace = PinData(context: viewContext)
        newPlace.dateAdded = Date()
        newPlace.post = place.name
        newPlace.url = place.address
        
        // Store location
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false) {
            newPlace.setValue(locationData, forKey: "coordinates")
        }
        
        // Create list item
        let listItem = RListItemData(context: viewContext)
        listItem.id = UUID().uuidString
        listItem.placeId = newPlace.objectID.uriRepresentation().absoluteString
        listItem.addedAt = Date()
        listItem.listId = list.id ?? ""
        
        do {
            try viewContext.save()
            
            // Show success feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Close the picker
            isPresented = false
            
        } catch {
            print("Failed to save place to list: \(error)")
        }
        
        isSaving = false
    }
    
    private func createDefaultListAndSave() {
        guard let currentUser = authService.currentAccount else {
            print("No current user found")
            return
        }
        
        isSaving = true
        
        // Create default "My Pins" list
        let defaultList = RListData(context: viewContext)
        defaultList.id = UUID().uuidString
        defaultList.name = "My Pins"
        defaultList.createdAt = Date()
        
        // Save the place to the new default list
        saveToNewList(defaultList)
    }
    
    private func saveToNewList(_ list: RListData) {
        // Create the place
        let newPlace = PinData(context: viewContext)
        newPlace.dateAdded = Date()
        newPlace.post = place.name
        newPlace.url = place.address
        
        // Store location
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false) {
            newPlace.setValue(locationData, forKey: "coordinates")
        }
        
        // Create list item
        let listItem = RListItemData(context: viewContext)
        listItem.id = UUID().uuidString
        listItem.placeId = newPlace.objectID.uriRepresentation().absoluteString
        listItem.addedAt = Date()
        listItem.listId = list.id ?? ""
        
        do {
            try viewContext.save()
            
            // Show success feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Close the picker
            isPresented = false
            
        } catch {
            print("Failed to save place to new list: \(error)")
        }
        
        isSaving = false
    }
    
    private func itemCount(for list: RListData) -> Int {
        return listItems.filter { $0.listId == list.id }.count
    }
}
