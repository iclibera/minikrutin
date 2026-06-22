import Foundation
import StoreKit

/// StoreKit 2 entitlement manager for the MinikRutin Premium subscription.
@MainActor
final class SubscriptionStore: ObservableObject {
    static let monthlyID = "com.iclibera.minikrutin.premium.monthly"
    static let yearlyID = "com.iclibera.minikrutin.premium.yearly"
    static let productIDs = [monthlyID, yearlyID]
    static let groupID = "minikrutin_premium"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedIDs: Set<String> = []
    @Published private(set) var isLoading = false

    /// Debug override so premium screens can be captured for screenshots.
    private let forcePremium = ProcessInfo.processInfo.arguments.contains("-PremiumPreview")

    private var updatesTask: Task<Void, Never>?

    var isSubscribed: Bool { forcePremium || !purchasedIDs.isEmpty }

    init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let items = try await Product.products(for: Self.productIDs)
            products = items.sorted { ($0.price) < ($1.price) }
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshEntitlements()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    active.insert(transaction.productID)
                }
            }
        }
        purchasedIDs = active
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            }
        }
    }

    func product(for id: String) -> Product? { products.first { $0.id == id } }
}
