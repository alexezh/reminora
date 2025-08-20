//
//  OnionTestRunner.swift
//  reminora
//
//  Created by Claude on 8/18/25.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Onion Test Runner

class OnionTestRunner: ObservableObject {
    @Published var isRunning = false
    @Published var testResults: [OnionTestResult] = []
    @Published var currentTest: String = ""
    
    struct OnionTestResult {
        let testName: String
        let scene: OnionScene
        let renderedImage: UIImage?
        let renderTime: TimeInterval
        let success: Bool
        let error: String?
    }
    
    /// Run all test scenarios
    func runAllTests() async {
        await MainActor.run {
            isRunning = true
            testResults.removeAll()
            currentTest = "Starting tests..."
        }
        
        let tests: [(String, () async throws -> (OnionScene, UIImage))] = [
            ("Polaroid Classic", { 
                let scene = OnionTestScene.createPolaroidClassicTestScene()
                let image = try await OnionTestScene.renderTestScene(scene, quality: .standard)
                return (scene, image)
            }),
            ("Advanced Polaroid", {
                let scene = OnionTestScene.createAdvancedPolaroidScene()
                let image = try await OnionTestScene.renderTestScene(scene, quality: .standard)
                return (scene, image)
            }),
            ("Quick Test", {
                let scene = OnionTestScene.createPolaroidClassicTestScene()
                let image = try await OnionTestScene.createAndRenderQuickTest()
                return (scene, image)
            })
        ]
        
        for (testName, testFunction) in tests {
            await runSingleTest(name: testName, test: testFunction)
        }
        
        await MainActor.run {
            isRunning = false
            currentTest = "Tests completed"
        }
        
        print("🧅 OnionTestRunner: Completed all tests. Results: \(testResults.count)")
    }
    
    private func runSingleTest(name: String, test: @escaping () async throws -> (OnionScene, UIImage)) async {
        await MainActor.run {
            currentTest = "Running: \(name)"
        }
        
        let startTime = Date()
        
        do {
            let (scene, image) = try await test()
            let renderTime = Date().timeIntervalSince(startTime)
            
            let result = OnionTestResult(
                testName: name,
                scene: scene,
                renderedImage: image,
                renderTime: renderTime,
                success: true,
                error: nil
            )
            
            await MainActor.run {
                testResults.append(result)
            }
            
            print("✅ Test '\(name)' passed in \(String(format: "%.2f", renderTime))s")
            
        } catch {
            let renderTime = Date().timeIntervalSince(startTime)
            
            let result = OnionTestResult(
                testName: name,
                scene: OnionScene(name: "Failed Scene"),
                renderedImage: nil,
                renderTime: renderTime,
                success: false,
                error: error.localizedDescription
            )
            
            await MainActor.run {
                testResults.append(result)
            }
            
            print("❌ Test '\(name)' failed: \(error.localizedDescription)")
        }
    }
    
    /// Run a specific test with photo assets
    func runTestWithAssets(_ assets: [RPhotoStack]) async {
        await MainActor.run {
            isRunning = true
            currentTest = "Testing with photo assets..."
        }
        
        await runSingleTest(name: "Polaroid with Photos") {
            let scene = OnionTestScene.createPolaroidSceneWithAssets(assets)
            let image = try await OnionTestScene.renderTestScene(scene, quality: .high)
            return (scene, image)
        }
        
        await MainActor.run {
            isRunning = false
        }
    }
    
    /// Create a demo scene for showcasing
    func createDemoScene() -> OnionScene {
        return OnionTestScene.createPolaroidClassicTestScene()
    }
    
    /// Get test statistics
    var testStatistics: (passed: Int, failed: Int, totalRenderTime: TimeInterval) {
        let passed = testResults.filter { $0.success }.count
        let failed = testResults.filter { !$0.success }.count
        let totalTime = testResults.reduce(0) { $0 + $1.renderTime }
        return (passed, failed, totalTime)
    }
}

// MARK: - SwiftUI Test View

struct OnionTestView: View {
    @StateObject private var testRunner = OnionTestRunner()
    @State private var selectedResult: OnionTestRunner.OnionTestResult?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Text("🧅 Onion Composition Engine")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Test Suite & Demo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Test Status
                if testRunner.isRunning {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text(testRunner.currentTest)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding()
                }
                
                // Test Results
                if !testRunner.testResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(testRunner.testResults.indices, id: \.self) { index in
                                let result = testRunner.testResults[index]
                                TestResultCard(result: result) {
                                    selectedResult = result
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Statistics
                    let stats = testRunner.testStatistics
                    HStack(spacing: 20) {
                        StatView(title: "Passed", value: "\(stats.passed)", color: .green)
                        StatView(title: "Failed", value: "\(stats.failed)", color: .red)
                        StatView(title: "Total Time", value: String(format: "%.2fs", stats.totalRenderTime), color: .blue)
                    }
                    .padding()
                } else if !testRunner.isRunning {
                    // Run Tests Button
                    VStack(spacing: 16) {
                        Button("Run All Tests") {
                            Task {
                                await testRunner.runAllTests()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.headline)
                        
                        Text("This will test the Onion composition engine with various scenarios including polaroid-style layouts with filters and effects.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Onion Tests")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedResult) { result in
                TestResultDetailView(result: result)
            }
        }
    }
}

struct TestResultCard: View {
    let result: OnionTestRunner.OnionTestResult
    let action: () -> Void
    
    var body: some View {
        HStack {
            // Status Icon
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.testName)
                    .font(.headline)
                
                Text("Render time: \(String(format: "%.2f", result.renderTime))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let error = result.error {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Preview Image
            if let image = result.renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { action() }
    }
}

struct TestResultDetailView: View {
    let result: OnionTestRunner.OnionTestResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Rendered Image
                    if let image = result.renderedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 5)
                    }
                    
                    // Scene Details
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(title: "Scene Name", value: result.scene.name)
                        DetailRow(title: "Size", value: "\(Int(result.scene.size.width)) × \(Int(result.scene.size.height))")
                        DetailRow(title: "Layer Count", value: "\(result.scene.layerCount)")
                        DetailRow(title: "Render Time", value: String(format: "%.3f seconds", result.renderTime))
                        DetailRow(title: "Background", value: result.scene.backgroundColor)
                        
                        if let error = result.error {
                            DetailRow(title: "Error", value: error, valueColor: .red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(result.testName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Identifiable Extension

extension OnionTestRunner.OnionTestResult: Identifiable {
    var id: String { testName }
}

#Preview {
    OnionTestView()
}