//
//  ShareViewController.swift
//  WahiShareExt
//
//  Created by alexezh on 5/26/25.
//

import UIKit
import Social
import MobileCoreServices
import CoreData

class ShareViewController: SLComposeServiceViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleIncomingImage()
    }

    private func handleIncomingImage() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else { return }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (item, error) in
                    if let url = item as? URL {
                        print("Received image URL: \(url)")
                        self.saveImageURLToCoreData(url: url)
                    } else if let image = item as? UIImage {
                        print("Received UIImage: \(image)")
                        // Optionally save UIImage to disk and persist its file URL
                        if let fileURL = self.saveUIImageToDisk(image: image) {
                            self.saveImageURLToCoreData(url: fileURL)
                        }
                    }
                }
                break
            }
        }
    }

    // Save the image URL string to Core Data
    private func saveImageURLToCoreData(url: URL) {
        guard let context = persistentContainer?.viewContext else { return }
        let entity = NSEntityDescription.entity(forEntityName: "SharedImage", in: context)!
        let sharedImage = NSManagedObject(entity: entity, insertInto: context)
        sharedImage.setValue(url.absoluteString, forKey: "url")
        sharedImage.setValue(Date(), forKey: "dateAdded")
        do {
            try context.save()
            print("Saved image URL to Core Data: \(url)")
        } catch {
            print("Failed to save image URL: \(error)")
        }
    }

    // Optionally save UIImage to disk and return file URL
    private func saveUIImageToDisk(image: UIImage) -> URL? {
        let appGroupID = "group.com.yourcompany.wahi" // Replace with your App Group ID
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = containerURL.appendingPathComponent(fileName)
        if let jpegData = image.jpegData(compressionQuality: 0.9) {
            do {
                try jpegData.write(to: fileURL)
                print("Saved UIImage to disk: \(fileURL)")
                return fileURL
            } catch {
                print("Failed to save UIImage to disk: \(error)")
            }
        }
        return nil
    }

    // MARK: - Core Data stack for App Group
    lazy var persistentContainer: NSPersistentContainer? = {
        let appGroupID = "group.com.yourcompany.wahi" // Replace with your App Group ID
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
        let storeURL = containerURL.appendingPathComponent("SharedImages.sqlite")
        let modelURL = Bundle.main.url(forResource: "SharedImages", withExtension: "momd") // Your Core Data model name
        guard let model = modelURL.flatMap({ NSManagedObjectModel(contentsOf: $0) }) else { return nil }
        let container = NSPersistentContainer(name: "SharedImages", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in
            if let error = error {
                loadError = error
            }
        }
        if let error = loadError {
            print("Failed to load Core Data store: \(error)")
            return nil
        }
        return container
    }()

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

}
