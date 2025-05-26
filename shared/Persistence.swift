//
//  Persistence.swift
//  wahi
//
//  Created by alexezh on 5/26/25.
//

import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    // Queue for actions to execute after persistent stores are loaded
    private var postLoadQueue: [() -> Void] = []
    private var isStoreLoaded = false

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        // #if APP
        //     let viewContext = result.container.viewContext
        //     for _ in 0..<10 {
        //         let newItem = Item(context: viewContext)
        //         newItem.timestamp = Date()
        //     }
        //     do {
        //         try viewContext.save()
        //     } catch {
        //         // Replace this implementation with code to handle the error appropriately.
        //         // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        //         let nsError = error as NSError
        //         fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        //     }
        // #endif
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "places")

        // Get URL for shared container
        let appGroupId = "group.com.alexezh.wahi"
        guard
            let sharedURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupId)
        else {
            fatalError("Shared container not found")
        }

        let storeURL = sharedURL.appendingPathComponent("places.sqlite")

        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        container.persistentStoreDescriptions = [storeDescription]

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            self.container.viewContext.automaticallyMergesChangesFromParent = true
            self.isStoreLoaded = true
            // Execute queued actions
            self.executePostLoadQueue()
        })
    }

    // Add an action to be executed after persistent stores are loaded
    func withStore(_ action: @escaping (_ context: NSManagedObjectContext) -> Void) {
        if isStoreLoaded {
            action(container.viewContext)
        } else {
            postLoadQueue.append { [weak self] in
                guard let self = self else { return }
                action(self.container.viewContext)
            }
        }
    }

    // Execute all queued actions
    private func executePostLoadQueue() {
        for action in postLoadQueue {
            action()
        }
        postLoadQueue.removeAll()
    }

    // MARK: - Core Data stack for App Group
    // lazy var persistentContainer: NSPersistentContainer? = {
    //     let appGroupID = "group.com.alexezh.wahi"  // Replace with your App Group ID
    //     guard
    //         let containerURL = FileManager.default.containerURL(
    //             forSecurityApplicationGroupIdentifier: appGroupID)
    //     else { return nil }
    //     let storeURL = containerURL.appendingPathComponent("places.sqlite")
    //     let modelURL = Bundle.main.url(forResource: "places", withExtension: "momd")  // Your Core Data model name
    //     guard let model = modelURL.flatMap({ NSManagedObjectModel(contentsOf: $0) }) else {
    //         return nil
    //     }
    //     let container = NSPersistentContainer(name: "places", managedObjectModel: model)
    //     let description = NSPersistentStoreDescription(url: storeURL)
    //     container.persistentStoreDescriptions = [description]
    //     var loadError: Error?
    //     container.loadPersistentStores { _, error in
    //         if let error = error {
    //             loadError = error
    //         }
    //     }
    //     if let error = loadError {
    //         print("Failed to load Core Data store: \(error)")
    //         return nil
    //     }
    //     return container
    // }()

}
