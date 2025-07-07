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
                provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) {
                    (item, error) in
                    if let url = item as? URL, let data = try? Data(contentsOf: url) {
                        self.pendingImageData = (data, url)
                    } else if let image = item as? UIImage,
                        let data = image.jpegData(compressionQuality: 0.9)
                    {
                        self.pendingImageData = (data, nil)
                    }
                }
                break
            }
            else if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) {
                    (item, error) in
                    if let url = item as? URL, let data = try? Data(contentsOf: url) {
                        self.pendingImageData = (data, url)
                    } else if let image = item as? UIImage,
                        let data = image.jpegData(compressionQuality: 0.9)
                    {
                        self.pendingImageData = (data, nil)
                    }
                }
                break
            }
        }
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // Store the image and text when the user posts
        if let (data, url) = pendingImageData {
            PersistenceController.shared.saveImageDataToCoreData(
                imageData: data, url: url, contentText: self.contentText)
        }
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }
}
