import Foundation
import StoreKit

enum SubscriptionType: String, CaseIterable {
    case monthly = "reminora_unlimited_monthly"
    case yearly = "reminora_unlimited_yearly"
    
    var displayName: String {
        switch self {
        case .monthly:
            return "Monthly Unlimited"
        case .yearly:
            return "Yearly Unlimited"
        }
    }
    
    var description: String {
        switch self {
        case .monthly:
            return "Unlimited pin sharing for one month"
        case .yearly:
            return "Unlimited pin sharing for one year (Best Value!)"
        }
    }
}

struct SubscriptionProduct {
    let type: SubscriptionType
    let product: Product
    let price: String
    let isActive: Bool
}

enum SubscriptionError: Error, LocalizedError {
    case productsNotAvailable
    case purchaseFailed
    case restoreFailed
    case verificationFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .productsNotAvailable:
            return "Subscription products are not available"
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .restoreFailed:
            return "Failed to restore purchases"
        case .verificationFailed:
            return "Purchase verification failed"
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published var products: [SubscriptionProduct] = []
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var hasActiveSubscription = false
    @Published var activeSubscriptionType: SubscriptionType?
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        
        do {
            let productIds = SubscriptionType.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIds)
            
            let subscriptionProducts = storeProducts.map { product in
                let type = SubscriptionType(rawValue: product.id) ?? .monthly
                let isActive = activeSubscriptionType == type
                
                return SubscriptionProduct(
                    type: type,
                    product: product,
                    price: product.displayPrice,
                    isActive: isActive
                )
            }.sorted { first, second in
                // Sort monthly first, then yearly
                if first.type == .monthly && second.type == .yearly {
                    return true
                } else if first.type == .yearly && second.type == .monthly {
                    return false
                }
                return false
            }
            
            products = subscriptionProducts
        } catch {
            print("Failed to load products: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    
    func purchase(_ subscriptionType: SubscriptionType) async throws {
        guard let subscriptionProduct = products.first(where: { $0.type == subscriptionType }) else {
            throw SubscriptionError.productsNotAvailable
        }
        
        isPurchasing = true
        
        defer {
            isPurchasing = false
        }
        
        do {
            let result = try await subscriptionProduct.product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateSubscriptionStatus(from: transaction)
                await transaction.finish()
                
            case .userCancelled:
                // User cancelled, don't throw error
                break
                
            case .pending:
                // Purchase is pending (e.g., awaiting approval)
                break
                
            @unknown default:
                throw SubscriptionError.purchaseFailed
            }
        } catch {
            throw SubscriptionError.purchaseFailed
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            throw SubscriptionError.restoreFailed
        }
    }
    
    // MARK: - Subscription Status
    
    func checkSubscriptionStatus() async {
        var activeSubscription: SubscriptionType?
        var hasActive = false
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if let subscriptionType = SubscriptionType(rawValue: transaction.productID) {
                    activeSubscription = subscriptionType
                    hasActive = true
                    
                    // Update the backend about subscription status
                    await updateBackendSubscriptionStatus(transaction: transaction)
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        hasActiveSubscription = hasActive
        activeSubscriptionType = activeSubscription
        
        // Update product active states
        await loadProducts()
    }
    
    // MARK: - Transaction Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await updateSubscriptionStatus(from: transaction)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func updateSubscriptionStatus(from transaction: StoreKit.Transaction) async {
        await checkSubscriptionStatus()
    }
    
    // MARK: - Backend Integration
    
    private func updateBackendSubscriptionStatus(transaction: StoreKit.Transaction) async {
        guard let session = AuthenticationService.shared.currentSession else {
            return
        }
        
        do {
            let url = URL(string: "https://reminora-backend.reminora.workers.dev/api/user/subscription/verify")!
            
            let requestBody: [String: Any] = [
                "transaction_id": transaction.id,
                "product_id": transaction.productID,
                "purchase_date": ISO8601DateFormatter().string(from: transaction.purchaseDate),
                "expires_date": transaction.expirationDate.map { ISO8601DateFormatter().string(from: $0) }
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Subscription verification status: \(httpResponse.statusCode)")
            }
        } catch {
            print("Failed to update backend subscription status: \(error)")
        }
    }
}

// MARK: - Subscription View

import SwiftUI

struct SubscriptionView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Unlimited Pin Sharing")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Share unlimited pins with friends and build your collection without limits")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Features
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "infinity", text: "Unlimited pin sharing")
                    FeatureRow(icon: "cloud.fill", text: "Cloud sync across devices")
                    FeatureRow(icon: "person.2.fill", text: "Share with friends")
                    FeatureRow(icon: "map.fill", text: "Discover new places")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Subscription options
                if subscriptionService.isLoading {
                    ProgressView("Loading subscription options...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    VStack(spacing: 12) {
                        ForEach(subscriptionService.products, id: \.type.rawValue) { product in
                            SubscriptionOptionView(
                                product: product,
                                isSelected: false,
                                onSelect: {
                                    Task {
                                        do {
                                            try await subscriptionService.purchase(product.type)
                                            dismiss()
                                        } catch {
                                            errorMessage = error.localizedDescription
                                            showingError = true
                                        }
                                    }
                                }
                            )
                            .disabled(subscriptionService.isPurchasing)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Restore purchases
                Button("Restore Purchases") {
                    Task {
                        do {
                            try await subscriptionService.restorePurchases()
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if subscriptionService.isPurchasing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Processing purchase...")
                                .padding(.top)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

struct SubscriptionOptionView: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.type.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(product.type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(product.price)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}