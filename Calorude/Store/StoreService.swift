import Foundation
import Observation
import StoreKit

enum StoreProducts {
  static let monthly = "com.yemeboluum.pro.monthly"
  static let yearly = "com.yemeboluum.pro.yearly"
  static let all = [monthly, yearly]
}
struct EntitlementRecord {
  var productID: String
  var verified: Bool
  var revoked: Bool
  var expiration: Date?
  var graceExpiration: Date? = nil
  func grantsAccess(at now: Date) -> Bool {
    guard verified, !revoked, StoreProducts.all.contains(productID) else { return false }
    return (expiration.map { $0 > now } ?? false) || (graceExpiration.map { $0 > now } ?? false)
  }
}
@MainActor @Observable final class StoreService {
  private(set) var products: [Product] = []
  private(set) var isPro = false
  private(set) var busy = false
  var statusKey: String?
  @ObservationIgnored nonisolated(unsafe) private var listener: Task<Void, Never>?
  @ObservationIgnored nonisolated(unsafe) private var expirationTask: Task<Void, Never>?
  func start() async {
    if listener == nil {
      listener = Task { [weak self] in
        for await result in Transaction.updates {
          guard let self else { return }
          if case .verified(let transaction) = result {
            await self.refreshEntitlements()
            await transaction.finish()
          }
        }
      }
    }
    await refreshEntitlements()
    await loadProducts()
  }
  func loadProducts() async {
    do {
      products = try await Product.products(for: StoreProducts.all).sorted {
        (StoreProducts.all.firstIndex(of: $0.id) ?? 0)
          < (StoreProducts.all.firstIndex(of: $1.id) ?? 0)
      }
      if products.isEmpty {
        statusKey = "store.unavailable"
      } else if statusKey == "store.unavailable" {
        statusKey = nil
      }
    } catch { statusKey = "store.unavailable" }
  }
  func refreshEntitlements() async {
    var granted = false
    var nextExpiration: Date?
    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result else { continue }
      var record = EntitlementRecord(
        productID: transaction.productID, verified: true,
        revoked: transaction.revocationDate != nil || transaction.isUpgraded,
        expiration: transaction.expirationDate)
      if !record.revoked, let expiry = record.expiration, expiry <= .now {
        var product = products.first { $0.id == transaction.productID }
        if product == nil {
          product = (try? await Product.products(for: [transaction.productID]))?.first
        }
        if let subscription = product?.subscription, let statuses = try? await subscription.status {
          for status in statuses where status.state == .inGracePeriod {
            if case .verified(let statusTransaction) = status.transaction,
              statusTransaction.productID == transaction.productID,
              case .verified(let renewal) = status.renewalInfo
            {
              record.graceExpiration = renewal.gracePeriodExpirationDate
            }
          }
        }
      }
      if record.grantsAccess(at: .now) {
        granted = true
        if let expiration = record.graceExpiration ?? transaction.expirationDate {
          nextExpiration = min(nextExpiration ?? expiration, expiration)
        }
      }
    }
    isPro = granted
    expirationTask?.cancel()
    if let expiry = nextExpiration {
      expirationTask = Task { [weak self] in
        do { try await Task.sleep(for: .seconds(max(1, expiry.timeIntervalSinceNow))) } catch {
          return
        }
        await self?.refreshEntitlements()
      }
    }
  }
  func purchase(_ product: Product) async {
    guard !busy else { return }
    busy = true
    statusKey = nil
    defer { busy = false }
    do {
      switch try await product.purchase() {
      case .success(let result):
        guard case .verified(let transaction) = result else {
          statusKey = "store.unverified"
          return
        }
        await refreshEntitlements()
        await transaction.finish()
        statusKey = isPro ? "store.success" : "store.inactive"
      case .pending: statusKey = "store.pending"
      case .userCancelled: break
      @unknown default: statusKey = "store.failed"
      }
    } catch { statusKey = "store.failed" }
  }
  func restore() async {
    guard !busy else { return }
    busy = true
    defer { busy = false }
    do {
      try await AppStore.sync()
      await refreshEntitlements()
      statusKey = isPro ? "store.restored" : "store.noPurchases"
    } catch { statusKey = "store.failed" }
  }
  func savings(yearly: Product) -> Int? {
    guard let monthly = products.first(where: { $0.id == StoreProducts.monthly }), monthly.price > 0
    else { return nil }
    let ratio = NSDecimalNumber(decimal: 1 - yearly.price / (monthly.price * 12)).doubleValue
    return ratio > 0 ? Int((ratio * 100).rounded(.down)) : nil
  }
  deinit {
    listener?.cancel()
    expirationTask?.cancel()
  }
}
