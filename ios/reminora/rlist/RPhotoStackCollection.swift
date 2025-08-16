//
//  RPhotoStackCollection.swift
//  reminora
//
//  Created by Claude on 8/7/25.
//

import Foundation
import Photos
import SwiftUI
import CoreData

/// A collection that manages RPhotoStack objects and provides stack expansion/collection functionality
/// Implements RandomAccessCollection for efficient array-like access
class RPhotoStackCollection: ObservableObject, RandomAccessCollection {
    
    // MARK: - RandomAccessCollection Requirements
    
    typealias Element = RPhotoStack
    typealias Index = Int
    
    var startIndex: Int { return stacks.startIndex }
    var endIndex: Int { return stacks.endIndex }
    
    func index(after i: Int) -> Int {
        return stacks.index(after: i)
    }
    
    func index(before i: Int) -> Int {
        return stacks.index(before: i)
    }
    
    subscript(position: Int) -> RPhotoStack {
        return stacks[position]
    }
    
    // MARK: - Properties
    
    @Published private var stacks: [RPhotoStack] = []
    @Published private var rawStacks: [RPhotoStack] = [] // Store unfiltered initial items
    @Published private var expandedStackIds: Set<String> = []
    private var allPhotoAssets: [PHAsset] = [] // Store all photos from library
    private var currentFilter: PhotoFilterType = .notDisliked
    private var preferenceManager: PhotoPreferenceManager?
    private var viewContext: NSManagedObjectContext?
    private var hasLoadedFromLibrary = false
    private var hasCompletedEmbeddingComputation = false
    
    /// All stacks in the collection
    var allStacks: [RPhotoStack] {
        return stacks
    }
    
    /// Count of all stacks
    var count: Int {
        return stacks.count
    }
    
    /// Whether the collection is empty
    var isEmpty: Bool {
        return stacks.isEmpty
    }
    
    /// Set of currently expanded stack IDs
    var expandedStacks: Set<String> {
        return expandedStackIds
    }
    
    /// Total number of individual photos across all stacks
    var totalPhotoCount: Int {
        return stacks.reduce(0) { $0 + $1.assets.count }
    }
    
    /// Number of expanded stacks
    var expandedStackCount: Int {
        return expandedStackIds.count
    }
    
    // MARK: - Initializers
    
    init() {
        self.stacks = []
    }
    
    init(stacks: [RPhotoStack]) {
        self.stacks = stacks
    }
    
    init(assets: [PHAsset]) {
        self.stacks = assets.map { RPhotoStack(assets: [$0]) }
    }
    
    // MARK: - Collection Management
    
    /// Replace all stacks in the collection
    func setStacks(_ newStacks: [RPhotoStack]) {
        stacks = newStacks
        // Clear expanded state for stacks that no longer exist
        let currentStackIds = Set(newStacks.map { $0.id })
        expandedStackIds = expandedStackIds.intersection(currentStackIds)
    }
    
    /// Replace raw stacks (unfiltered) and update filtered stacks
    func setRawStacks(_ newStacks: [RPhotoStack]) {
        rawStacks = newStacks
        applyCurrentFilter()
    }
    
    /// Add a stack to the collection
    func addStack(_ stack: RPhotoStack) {
        stacks.append(stack)
    }
    
    /// Insert a stack at a specific index
    func insertStack(_ stack: RPhotoStack, at index: Int) {
        stacks.insert(stack, at: index)
    }
    
    /// Remove a stack at a specific index
    @discardableResult
    func removeStack(at index: Int) -> RPhotoStack {
        let removedStack = stacks.remove(at: index)
        expandedStackIds.remove(removedStack.id)
        return removedStack
    }
    
    /// Remove all stacks
    func removeAll() {
        stacks.removeAll()
        expandedStackIds.removeAll()
    }
    
    // MARK: - Stack Expansion/Collection
    
    /// Check if a stack is currently expanded
    func isStackExpanded(_ stackId: String) -> Bool {
        return expandedStackIds.contains(stackId)
    }
    
    /// Check if a stack is expandable (has more than one photo)
    func isStackExpandable(_ stackId: String) -> Bool {
        return stacks.first { $0.id == stackId }?.assets.count ?? 0 > 1
    }
    
    /// Expand a stack into individual photo stacks
    /// - Parameter stackId: The ID of the stack to expand
    /// - Returns: True if the stack was expanded, false if it was already expanded or doesn't exist
    @discardableResult
    func expandStack(_ stackId: String) -> Bool {
        guard !expandedStackIds.contains(stackId),
              let stackIndex = stacks.firstIndex(where: { $0.id == stackId }),
              stacks[stackIndex].assets.count > 1 else {
            return false
        }
        
        let stack = stacks[stackIndex]
        let individualStacks = stack.individualPhotoStacks()
        
        // Replace the original stack with individual stacks
        stacks.remove(at: stackIndex)
        stacks.insert(contentsOf: individualStacks, at: stackIndex)
        
        // Mark as expanded
        expandedStackIds.insert(stackId)
        
        return true
    }
    
    /// Collapse individual photos back into a stack
    /// - Parameter stackId: The original stack ID to collapse back to
    /// - Returns: True if the stack was collapsed, false if it wasn't expanded or doesn't exist
    @discardableResult
    func collapseStack(_ stackId: String) -> Bool {
        guard expandedStackIds.contains(stackId) else {
            return false
        }
        
        // Find all individual stacks that belong to the original stack
        let individualStacks = stacks.filter { stack in
            // Check if this individual stack's asset was part of the original stack
            return stack.assets.count == 1 && 
                   stacks.contains { originalStack in
                       originalStack.id == stackId && 
                       originalStack.assets.contains { $0.localIdentifier == stack.assets.first?.localIdentifier }
                   }
        }
        
        guard !individualStacks.isEmpty else {
            return false
        }
        
        // Collect all assets from individual stacks
        let allAssets = individualStacks.flatMap { $0.assets }
        
        // Create a new combined stack
        let combinedStack = RPhotoStack(assets: allAssets)
        
        // Find the index of the first individual stack
        guard let firstIndex = stacks.firstIndex(where: { stack in
            individualStacks.contains { $0.id == stack.id }
        }) else {
            return false
        }
        
        // Remove all individual stacks
        stacks.removeAll { stack in
            individualStacks.contains { $0.id == stack.id }
        }
        
        // Insert the combined stack at the original position
        stacks.insert(combinedStack, at: firstIndex)
        
        // Mark as not expanded
        expandedStackIds.remove(stackId)
        
        return true
    }
    
    /// Toggle the expansion state of a stack
    /// - Parameter stackId: The ID of the stack to toggle
    /// - Returns: True if the stack is now expanded, false if it's now collapsed
    @discardableResult
    func toggleStackExpansion(_ stackId: String) -> Bool {
        if expandedStackIds.contains(stackId) {
            collapseStack(stackId)
            return false
        } else {
            expandStack(stackId)
            return true
        }
    }
    
    /// Expand all expandable stacks in the collection
    func expandAllStacks() {
        let expandableStacks = stacks.filter { $0.assets.count > 1 && !expandedStackIds.contains($0.id) }
        for stack in expandableStacks {
            expandStack(stack.id)
        }
    }
    
    /// Collapse all expanded stacks in the collection
    func collapseAllStacks() {
        let expandedIds = Array(expandedStackIds)
        for stackId in expandedIds {
            collapseStack(stackId)
        }
    }
    
    // MARK: - Search and Filtering
    
    /// Find a stack by its ID
    func stack(withId stackId: String) -> RPhotoStack? {
        return stacks.first { $0.id == stackId }
    }
    
    /// Find the index of a stack by its ID
    func index(of stackId: String) -> Int? {
        return stacks.firstIndex { $0.id == stackId }
    }
    
    /// Find a stack that contains a specific asset
    func stack(containing asset: PHAsset) -> RPhotoStack? {
        return stacks.first { stack in
            stack.assets.contains { $0.localIdentifier == asset.localIdentifier }
        }
    }
    
    /// Get stack information for an asset - returns stack details and metadata
    func getStackInfo(for asset: PHAsset) -> (stack: RPhotoStack?, isStack: Bool, count: Int) {
        for stack in stacks {
            if stack.assets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                return (stack: stack, isStack: stack.assets.count > 1, count: stack.assets.count)
            }
        }
        return (stack: nil, isStack: false, count: 1)
    }
    
    /// Filter stacks based on a predicate
    func filteredStacks(_ predicate: (RPhotoStack) -> Bool) -> [RPhotoStack] {
        return stacks.filter(predicate)
    }
    
    // MARK: - Convenience Methods
    
    /// Create a new collection with only stacks matching the predicate
    func filtered(_ predicate: (RPhotoStack) -> Bool) -> RPhotoStackCollection {
        let filteredStacks = stacks.filter(predicate)
        let newCollection = RPhotoStackCollection(stacks: filteredStacks)
        // Don't copy expansion state for filtered collection
        return newCollection
    }
    
    /// Sort the collection using a comparator
    func sorted(by comparator: (RPhotoStack, RPhotoStack) -> Bool) {
        stacks.sort(by: comparator)
    }
    
    /// Create a new sorted collection
    func sortedCollection(by comparator: (RPhotoStack, RPhotoStack) -> Bool) -> RPhotoStackCollection {
        let sortedStacks = stacks.sorted(by: comparator)
        let newCollection = RPhotoStackCollection(stacks: sortedStacks)
        newCollection.expandedStackIds = self.expandedStackIds
        return newCollection
    }
    
    // MARK: - Photo Library Integration
    
    /// Configure the collection with Core Data context and preference manager
    /// - Parameters:
    ///   - viewContext: Core Data context for photo preferences
    ///   - preferenceManager: Manager for photo preferences and filtering
    ///   - initialFilter: Initial filter to apply (default: .notDisliked)
    func configure(
        with viewContext: NSManagedObjectContext,
        preferenceManager: PhotoPreferenceManager,
        initialFilter: PhotoFilterType = .notDisliked
    ) {
        self.viewContext = viewContext
        self.preferenceManager = preferenceManager
        self.currentFilter = initialFilter
    }
    
    /// Load photo assets from the photo library
    /// - Parameter assets: Array of PHAssets from the photo library
    func loadPhotoAssets(_ assets: [PHAsset]) async {
        print("📷 RPhotoStackCollection: Loading \(assets.count) photo assets")
        
        await MainActor.run {
            allPhotoAssets = assets
            hasLoadedFromLibrary = true
            
            // Apply current filter and create stacks
            applyCurrentFilter()
        }
    }
    
    /// Apply current filter to raw stacks and update the filtered stacks
    private func applyCurrentFilter() {
        guard let preferenceManager = preferenceManager else {
            print("❌ RPhotoStackCollection: No preference manager available for filtering")
            return
        }
        
        print("📷 RPhotoStackCollection: Applying filter \(currentFilter.displayName) to existing stacks")
        
        // If we have computed stacks, filter them based on their assets
        if hasCompletedEmbeddingComputation && !rawStacks.isEmpty {
            // Filter existing stacks based on their assets
            let filteredStacks = rawStacks.filter { stack in
                // Keep stack if any of its assets pass the filter
                return stack.assets.contains { asset in
                    switch currentFilter {
                    case .all:
                        return true
                    case .favorites:
                        return asset.isFavorite
                    case .dislikes:
                        return preferenceManager.getPreference(for: asset) == .archive
                    case .neutral:
                        return !asset.isFavorite && preferenceManager.getPreference(for: asset) != .archive
                    case .notDisliked:
                        return preferenceManager.getPreference(for: asset) != .archive
                    }
                }
            }
            
            stacks = filteredStacks
            print("📷 RPhotoStackCollection: Filtered to \(filteredStacks.count) stacks")
        } else {
            // If no computed stacks yet, create simple stacks and trigger computation
            createAndComputeStacks()
        }
    }
    
    /// Create initial stacks and trigger background embedding computation (only once)
    private func createAndComputeStacks() {
        guard let preferenceManager = preferenceManager else {
            print("❌ RPhotoStackCollection: No preference manager available")
            return
        }
        
        print("📷 RPhotoStackCollection: Creating initial stacks from \(allPhotoAssets.count) assets")
        
        // Apply preference filter to all assets
        let filteredAssets = preferenceManager.getFilteredAssets(
            from: allPhotoAssets, 
            filter: currentFilter
        )
        
        print("📷 RPhotoStackCollection: Filtered to \(filteredAssets.count) assets")
        
        // Create simple stacks first (without embedding computation) for immediate UI display
        let simpleStacks = createSimpleStacksFromAssets(filteredAssets)
        
        // Update UI immediately with simple stacks
        rawStacks = simpleStacks
        stacks = simpleStacks
        print("📷 RPhotoStackCollection: Created \(simpleStacks.count) simple photo stacks for immediate display")
        
        // Start embedding computation in background (non-blocking) - but only once
        if !hasCompletedEmbeddingComputation {
            Task.detached(priority: .background) {
                guard let viewContext = self.viewContext, let preferenceManager = self.preferenceManager else {
                    print("❌ RPhotoStackCollection: Missing dependencies for background embedding computation")
                    return
                }
                
                print("📊 RPhotoStackCollection: Starting background embedding computation...")
                
                // Use PhotoEmbeddingService to create stacks with similarity detection
                var lastEmbeddingCount = -1
                var hasStacksBeenCleared = false
                var hasTriggeredEmbeddingComputation = false
                
                // Use ALL assets for embedding computation, not just filtered ones
                let embeddedStacks = await PhotoEmbeddingService.shared.createPhotoStacks(
                    from: self.allPhotoAssets,
                    in: viewContext,
                    preferenceManager: preferenceManager,
                    lastEmbeddingCount: &lastEmbeddingCount,
                    hasStacksBeenCleared: &hasStacksBeenCleared,
                    hasTriggeredEmbeddingComputation: &hasTriggeredEmbeddingComputation
                )
                
                await MainActor.run {
                    // Store all computed stacks
                    self.rawStacks = embeddedStacks
                    self.hasCompletedEmbeddingComputation = true
                    
                    // Apply current filter to the computed stacks
                    self.applyCurrentFilter()
                    
                    print("📊 RPhotoStackCollection: Background embedding complete - Updated to \(embeddedStacks.count) photo stacks with similarity detection")
                }
            }
        }
    }
    
    /// Create simple stacks from assets without embedding computation (for fast UI display)
    private func createSimpleStacksFromAssets(_ assets: [PHAsset]) -> [RPhotoStack] {
        // Group assets by time proximity (simple time-based stacking)
        let sortedAssets = assets.sorted {
            ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
        }
        
        var stacks: [RPhotoStack] = []
        var currentBatch: [PHAsset] = []
        let stackingInterval: TimeInterval = 10 * 60 // 10 minutes
        let maxStackSize = 3
        
        for asset in sortedAssets {
            if let lastAsset = currentBatch.last,
               let lastDate = lastAsset.creationDate,
               let assetDate = asset.creationDate {
                let timeDiff = abs(assetDate.timeIntervalSince(lastDate))
                
                if timeDiff <= stackingInterval && currentBatch.count < maxStackSize {
                    currentBatch.append(asset)
                } else {
                    // Finalize current batch
                    if !currentBatch.isEmpty {
                        stacks.append(RPhotoStack(assets: currentBatch))
                    }
                    currentBatch = [asset]
                }
            } else {
                currentBatch = [asset]
            }
        }
        
        // Add final batch
        if !currentBatch.isEmpty {
            stacks.append(RPhotoStack(assets: currentBatch))
        }
        
        return stacks
    }
    
    /// Set a new filter and update the stacks accordingly
    /// - Parameter filter: The new filter to apply
    func setFilter(_ filter: PhotoFilterType) {
        guard filter != currentFilter else {
            print("📷 RPhotoStackCollection: Filter \\(filter.displayName) already applied")
            return
        }
        
        currentFilter = filter
        applyCurrentFilter()
    }
    
    /// Get the currently applied filter
    var appliedFilter: PhotoFilterType {
        return currentFilter
    }
    
    /// Check if the collection has been loaded from the photo library
    var hasLoaded: Bool {
        return hasLoadedFromLibrary
    }
    
    /// Get all photo assets (unfiltered)
    func getAllPhotoAssets() -> [PHAsset] {
        return allPhotoAssets
    }
    
    /// Get raw stacks (before current filter is applied)
    var allRawStacks: [RPhotoStack] {
        return rawStacks
    }
    
    /// Refresh the collection by re-applying the current filter
    func refreshWithCurrentFilter() {
        applyCurrentFilter()
    }
}

// MARK: - Extensions for Common Operations

extension RPhotoStackCollection {
    
    /// Convenience method to sort by creation date (newest first)
    func sortByDateDescending() {
        sorted { $0.creationDate > $1.creationDate }
    }
    
    /// Convenience method to sort by creation date (oldest first)
    func sortByDateAscending() {
        sorted { $0.creationDate < $1.creationDate }
    }
    
    /// Convenience method to sort by stack size (largest first)
    func sortByStackSize() {
        sorted { $0.assets.count > $1.assets.count }
    }
}

// MARK: - Sequence Protocol Conformance

extension RPhotoStackCollection: Sequence {
    func makeIterator() -> Array<RPhotoStack>.Iterator {
        return stacks.makeIterator()
    }
}

// MARK: - Debug Description

extension RPhotoStackCollection: CustomStringConvertible {
    var description: String {
        return "RPhotoStackCollection(count: \(count), expanded: \(expandedStackCount), totalPhotos: \(totalPhotoCount))"
    }
}