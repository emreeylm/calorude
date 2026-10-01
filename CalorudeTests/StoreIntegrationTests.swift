import StoreKit
import StoreKitTest
import XCTest

@testable import Calorude

@MainActor final class StoreIntegrationTests: XCTestCase {
  func testPricesFollowStorefrontCurrency() async throws {
    let session = try SKTestSession(configurationFileNamed: "Development")
    session.resetToDefaultState()
    defer { session.resetToDefaultState() }
    XCTAssertEqual(session.storefront, "TUR")
    let service = StoreService()
    await service.loadProducts()
    XCTAssertEqual(
      service.products.first { $0.id == StoreProducts.monthly }?.price, Decimal(string: "79"))
    XCTAssertEqual(
      service.products.first { $0.id == StoreProducts.yearly }?.price, Decimal(string: "599"))
    for (country, locale, currency) in [
      ("TUR", "tr_TR", "TRY"), ("USA", "en_US", "USD"), ("TUR", "en_US", "TRY"),
    ] {
      session.storefront = country
      session.locale = Locale(identifier: locale)
      await service.loadProducts()
      XCTAssertEqual(service.products.count, 2)
      for product in service.products {
        XCTAssertEqual(product.priceFormatStyle.currencyCode, currency)
        XCTAssertFalse(product.displayPrice.isEmpty)
        if currency == "TRY" { XCTAssertFalse(product.displayPrice.contains("$")) }
        let attachment = XCTAttachment(
          string:
            "\(country) / \(locale): \(product.id) = \(product.displayPrice); monthly equivalent = \((product.price / 12).formatted(product.priceFormatStyle))"
        )
        attachment.lifetime = .keepAlways
        add(attachment)
      }
    }
  }
  func testVerifiedPurchasesAndExpiration() async throws {
    let session = try SKTestSession(configurationFileNamed: "Development")
    session.disableDialogs = true
    session.clearTransactions()
    defer { session.clearTransactions() }
    let service = StoreService()
    await service.loadProducts()
    XCTAssertEqual(service.products.count, 2)
    await service.refreshEntitlements()
    XCTAssertFalse(service.isPro)
    _ = try await session.buyProduct(identifier: StoreProducts.monthly)
    for _ in 0..<20 {
      await service.refreshEntitlements()
      if service.isPro { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTAssertTrue(service.isPro)
    try session.expireSubscription(productIdentifier: StoreProducts.monthly)
    for _ in 0..<30 {
      await service.refreshEntitlements()
      if !service.isPro { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTAssertFalse(service.isPro)
    _ = try await session.buyProduct(identifier: StoreProducts.yearly)
    for _ in 0..<20 {
      await service.refreshEntitlements()
      if service.isPro { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTAssertTrue(service.isPro)
    let yearly = try XCTUnwrap(service.products.first { $0.id == StoreProducts.yearly })
    // 1 - 599 / (79 × 12) = 36.8 %, rounded down.
    XCTAssertEqual(service.savings(yearly: yearly), 36)
    XCTAssertFalse(yearly.displayPrice.isEmpty)
  }
}
