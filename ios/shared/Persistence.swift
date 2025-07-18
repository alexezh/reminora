//
//  Persistence.swift
//  wahi
//
//  Created by alexezh on 5/26/25.
//

import CoreData
import CoreLocation
import ImageIO
import MobileCoreServices
import Social
import UIKit

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
        let appGroupId = "group.com.alexezh.reminora"
        guard
            let sharedURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupId)
        else {
            fatalError("Shared container not found")
        }

        let storeURL = sharedURL.appendingPathComponent("places.sqlite")

        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
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

    // Save the image data with optional URL string to Core Data
    public func saveImageDataToCoreData(imageData: Data, url: URL?, contentText: String?, isPrivate: Bool = false) {
        let scaledData: Data

        if let url = url, let downsampled = downsampleImage(at: url, to: 1024),
            let jpeg = downsampled.jpegData(compressionQuality: 0.9)
        {
            scaledData = jpeg
        } else if let image = UIImage(data: imageData),
            let jpeg = image.jpegData(compressionQuality: 0.9)
        {
            scaledData = jpeg
        } else {
            scaledData = imageData
        }

        withStore { context in
            let entity = NSEntityDescription.entity(forEntityName: "Place", in: context)!
            let sharedImage = NSManagedObject(entity: entity, insertInto: context)
            sharedImage.setValue(scaledData, forKey: "imageData")
            sharedImage.setValue(url?.absoluteString, forKey: "url")
            sharedImage.setValue(Date(), forKey: "dateAdded")
            if let contentTsxt = contentText {
                sharedImage.setValue(contentText, forKey: "post")
            }
            if let url = url, let coordinate = self.extractLocation(from: url) {
                let locationData = try? NSKeyedArchiver.archivedData(
                    withRootObject: coordinate, requiringSecureCoding: false)
                sharedImage.setValue(locationData, forKey: "location")
            }
            sharedImage.setValue(isPrivate, forKey: "isPrivate")
            // Store reference to last inserted Place for use in didSelectPost
            do {
                try context.save()
                print("Saved image data to Core Data")
            } catch {
                print("Failed to save image data: \(error)")
            }
        }
    }

    // Save the image data with optional location to Core Data
    public func saveImageDataToCoreData(imageData: Data, location: CLLocation?, contentText: String?, isPrivate: Bool = false) {
        let scaledData: Data
        
        if let image = UIImage(data: imageData),
           let jpeg = image.jpegData(compressionQuality: 0.9)
        {
            scaledData = jpeg
        } else {
            scaledData = imageData
        }

        withStore { context in
            let entity = NSEntityDescription.entity(forEntityName: "Place", in: context)!
            let sharedImage = NSManagedObject(entity: entity, insertInto: context)
            sharedImage.setValue(scaledData, forKey: "imageData")
            sharedImage.setValue(nil, forKey: "url") // No URL for photo library images
            sharedImage.setValue(Date(), forKey: "dateAdded")
            if let contentText = contentText {
                sharedImage.setValue(contentText, forKey: "post")
            }
            if let location = location {
                let locationData = try? NSKeyedArchiver.archivedData(
                    withRootObject: location, requiringSecureCoding: false)
                sharedImage.setValue(locationData, forKey: "location")
            }
            sharedImage.setValue(isPrivate, forKey: "isPrivate")
            
            do {
                try context.save()
                print("Saved image data with location to Core Data")
            } catch {
                print("Failed to save image data: \(error)")
            }
        }
    }

    // Extract GPS coordinates from image at URL
    private func extractLocation(from url: URL) -> CLLocation? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                as? [CFString: Any],
            let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
            let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
            let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
            let longitude = gps[kCGImagePropertyGPSLongitude] as? Double,
            let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
        else {
            return nil
        }

        let lat = (latitudeRef == "S") ? -latitude : latitude
        let lon = (longitudeRef == "W") ? -longitude : longitude
        return CLLocation(latitude: lat, longitude: lon)
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
    //     let appGroupID = "group.com.alexezh.reminora"  // Replace with your App Group ID
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

private func downsampleImage(at url: URL, to targetWidth: CGFloat) -> UIImage? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: Int(targetWidth),
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}
