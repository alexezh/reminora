//
//  ShareViewController.swift
//  WahiShareExt
//
//  Created by alexezh on 5/26/25.
//

import CoreData
import CoreLocation
import ImageIO
import MobileCoreServices
import Social
import UIKit

class ShareViewController: SLComposeServiceViewController {

    private var pendingImageData: (data: Data, url: URL?)?

    override func viewDidLoad() {
        super.viewDidLoad()
        handleIncomingImage()
    }

    private func handleIncomingImage() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments
        else { return }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (item, error) in
                    if let url = item as? URL, let data = try? Data(contentsOf: url) {
                        self.pendingImageData = (data, url)
                    } else if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                        self.pendingImageData = (data, nil)
                    }
                }
                break
            }
        }
    }

    // Save the image data and optional URL string to Core Data
    private func saveImageDataToCoreData(imageData: Data, url: URL?) {
        let scaledData: Data

        if let url = url, let downsampled = downsampleImage(at: url, to: 1024),
           let jpeg = downsampled.jpegData(compressionQuality: 0.9) {
            scaledData = jpeg
        } else if let image = UIImage(data: imageData),
                  let jpeg = image.jpegData(compressionQuality: 0.9) {
            scaledData = jpeg
        } else {
            scaledData = imageData
        }

        PersistenceController.shared.withStore { context in
            let entity = NSEntityDescription.entity(forEntityName: "Place", in: context)!
            let sharedImage = NSManagedObject(entity: entity, insertInto: context)
            sharedImage.setValue(scaledData, forKey: "imageData")
            sharedImage.setValue(url?.absoluteString, forKey: "url")
            sharedImage.setValue(Date(), forKey: "dateAdded")
            sharedImage.setValue(self.contentText, forKey: "post")
            if let url = url, let coordinate = self.extractLocation(from: url) {
                let locationData = try? NSKeyedArchiver.archivedData(
                    withRootObject: coordinate, requiringSecureCoding: false)
                sharedImage.setValue(locationData, forKey: "location")
            }
            // Store reference to last inserted Place for use in didSelectPost
            do {
                try context.save()
                print("Saved image data to Core Data")
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

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // Store the image and text when the user posts
        if let (data, url) = pendingImageData {
            self.saveImageDataToCoreData(imageData: data, url: url)
        }
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

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
