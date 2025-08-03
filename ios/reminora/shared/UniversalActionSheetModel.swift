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
    case swipePhoto
    case pinDetail
}

// MARK: - Universal Action Sheet Model
class UniversalActionSheetModel: ObservableObject {
    @Published var context: ActionSheetContext = .lists
    
    static let shared = UniversalActionSheetModel()
    
    private init() {}
    
    func setContext(_ newContext: ActionSheetContext) {
        DispatchQueue.main.async {
            self.context = newContext
        }
    }
}
