//
//  UniversalActionSheetModel.swift
//  reminora
//
//  Created by alexezh on 8/3/25.
//


import CoreData
import MapKit
import PhotosUI
import SwiftUI

// MARK: - Action Sheet Context
enum ActionSheetContext {
    case photos
    case map
    case pins
    case lists
    case quickList
    case profile
    case swipePhoto(stack: RPhotoStack)
    case pinDetail(pin: PinData)
    case ecard
    case clip
}

// MARK: - Editor Type
enum EditorType: String, CaseIterable {
    case eCard = "ECard"
    case clip = "Clip"
    case collage = "Collage"
    
    var displayName: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .eCard:
            return "rectangle.stack"
        case .clip:
            return "video.circle"
        case .collage:
            return "square.grid.2x2"
        }
    }
}

// MARK: - Universal Action Sheet Model
class UniversalActionSheetModel: ObservableObject {
    @Published var context: ActionSheetContext = .lists
    @Published var currentEditor: EditorType? = nil
    
    static let shared = UniversalActionSheetModel()
    
    private init() {}
    
    func setContext(_ newContext: ActionSheetContext) {
        DispatchQueue.main.async {
            self.context = newContext
        }
    }
    
    func setCurrentEditor(_ editor: EditorType?) {
        DispatchQueue.main.async {
            self.currentEditor = editor
        }
    }
}
