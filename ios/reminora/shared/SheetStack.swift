//
//  SheetStack.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Sheet Stack Service
class SheetStack: ObservableObject {
    static let shared = SheetStack()

    @Published private var sheets: [SheetType] = []

    private init() {}

    // MARK: - Public Interface

    /// Current sheet being displayed (top of stack)
    var currentSheet: SheetType? {
        sheets.last
    }

    /// Whether any sheets are being displayed
    var hasSheets: Bool {
        !sheets.isEmpty
    }

    /// Number of sheets in stack
    var sheetCount: Int {
        sheets.count
    }

    /// All sheets in the stack (for debugging)
    var allSheets: [SheetType] {
        sheets
    }

    // MARK: - Stack Operations

    /// Push a new sheet onto the stack
    func push(_ sheet: SheetType) {
        print("📱 SheetStack: Pushing sheet \(sheet.id)")

        // Check if sheet is already on stack to prevent duplicates
        if sheets.contains(where: { $0.id == sheet.id }) {
            print("📱 SheetStack: Sheet \(sheet.id) already exists, bringing to front")
            // Remove existing and add to top
            sheets.removeAll { $0.id == sheet.id }
        }

        sheets.append(sheet)
        print("📱 SheetStack: Stack now has \(sheets.count) sheets")
    }

    /// Pop the current sheet (top of stack)
    @discardableResult
    func pop() -> SheetType? {
        guard let sheet = sheets.popLast() else {
            print("📱 SheetStack: No sheets to pop")
            return nil
        }

        print("📱 SheetStack: Popped sheet \(sheet.id)")
        print("📱 SheetStack: Stack now has \(sheets.count) sheets")
        return sheet
    }

    /// Pop a specific sheet by ID
    @discardableResult
    func pop(_ sheetId: String) -> SheetType? {
        guard let index = sheets.firstIndex(where: { $0.id == sheetId }) else {
            print("📱 SheetStack: Sheet \(sheetId) not found in stack")
            return nil
        }

        let sheet = sheets.remove(at: index)
        print("📱 SheetStack: Popped specific sheet \(sheet.id)")
        print("📱 SheetStack: Stack now has \(sheets.count) sheets")
        return sheet
    }

    /// Pop a specific sheet type
    @discardableResult
    func pop(_ sheet: SheetType) -> SheetType? {
        return pop(sheet.id)
    }

    /// Clear all sheets from stack
    func clearAll() {
        let count = sheets.count
        sheets.removeAll()
        print("📱 SheetStack: Cleared all \(count) sheets from stack")
    }

    /// Replace current sheet with a new one
    func replace(with sheet: SheetType) {
        print("📱 SheetStack: Replacing current sheet with \(sheet.id)")
        pop()
        push(sheet)
    }

    /// Check if a specific sheet is in the stack
    func contains(_ sheet: SheetType) -> Bool {
        sheets.contains { $0.id == sheet.id }
    }

    /// Check if a sheet with specific ID is in the stack
    func contains(sheetId: String) -> Bool {
        sheets.contains { $0.id == sheetId }
    }

    // MARK: - Convenience Methods

    /// Push sheet and get a dismiss closure
    func pushWithDismiss(_ sheet: SheetType) -> () -> Void {
        push(sheet)
        return { [weak self] in
            self?.pop(sheet)
        }
    }

    /// Pop all sheets matching a predicate (useful for clearing similar sheets)
    func popAll(where predicate: (SheetType) -> Bool) {
        let initialCount = sheets.count
        sheets.removeAll(where: predicate)
        let removedCount = initialCount - sheets.count
        if removedCount > 0 {
            print("📱 SheetStack: Removed \(removedCount) sheets matching predicate")
        }
    }

    /// Pop all photo-related sheets (convenience method)
    func popAllPhotoSheets() {
        popAll { sheet in
            switch sheet {
            case .addPinFromPhoto, .similarPhotos, .duplicatePhotos:  // .photoSimilarity:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Debugging

    /// Print current stack state
    func printStack() {
        print("📱 SheetStack: Current stack (\(sheets.count) sheets):")
        for (index, sheet) in sheets.enumerated() {
            print("  \(index): \(sheet.id)")
        }
    }
}

// MARK: - Environment Integration
private struct SheetStackKey: EnvironmentKey {
    static let defaultValue = SheetStack.shared
}

extension EnvironmentValues {
    var sheetStack: SheetStack {
        get { self[SheetStackKey.self] }
        set { self[SheetStackKey.self] = newValue }
    }
}
