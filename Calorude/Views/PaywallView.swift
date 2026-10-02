import StoreKit
import SwiftUI

struct PaywallView: View {
  @Environment(AppLocalization.self) private var l
  @Environment(StoreService.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var legal: LegalDocument?
  @State private var manage = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text(AppBrand.pro(l)).font(.headline).foregroundStyle(Theme.interactive)
          Text(l.text("paywall.title")).font(.system(.largeTitle, design: .rounded, weight: .black))
          ForEach(["roasts", "reports", "unlimited", "themes"], id: \.self) { key in
            Label(l.text("pro." + key), systemImage: "checkmark.circle.fill").foregroundStyle(
              .primary)
          }
          Panel {
            VStack(alignment: .leading, spacing: 14) {
              Text(l.text("paywall.modes")).font(.caption.weight(.bold)).tracking(2)
              ForEach(["optimistic", "savage", "unhinged", "toxic"], id: \.self) { mode in
                VStack(alignment: .leading, spacing: 2) {
                  Text(l.text("intensity." + mode)).font(.subheadline.bold())
                  Text("“" + l.text("paywall.sample." + mode) + "”").font(.subheadline.italic())
                    .foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
              }
            }
          }
          if store.isPro {
            Label(l.text("store.active"), systemImage: "checkmark.seal.fill").foregroundStyle(
              Theme.interactive)
          }
          ForEach(store.products) { product in
            Button {
              Task { await store.purchase(product) }
            } label: {
              VStack(alignment: .leading, spacing: 12) {
                HStack {
                  Text(
                    l.text(
                      product.id == StoreProducts.yearly ? "plan.yearly" : "plan.monthly")
                  ).font(.headline)
                  Spacer()
                  if product.id == StoreProducts.yearly {
                    Text(l.text("bestValue")).font(.caption.bold()).padding(8).background(
                      Theme.accent, in: Capsule()
                    ).foregroundStyle(Theme.ink)
                  }
                }
                Text(product.displayPrice).font(.largeTitle.bold())
                Text(
                  l.text(product.id == StoreProducts.yearly ? "billing.yearly" : "billing.monthly")
                ).font(.caption)
                if product.id == StoreProducts.yearly {
                  Text(
                    (product.price / 12).formatted(product.priceFormatStyle) + " "
                      + l.text("per.month")
                  ).font(.subheadline)
                  if let saving = store.savings(yearly: product) {
                    Text(l.text("savings") + " %\(saving)").font(.caption.bold())
                  }
                }
              }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(
                Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22)
              ).overlay(
                RoundedRectangle(cornerRadius: 22).stroke(
                  product.id == StoreProducts.yearly ? Theme.accent : .clear, lineWidth: 2))
            }.buttonStyle(.plain).disabled(store.busy || store.isPro)
          }
          if store.busy { ProgressView() }
          if let key = store.statusKey, !hidesStoreStatus {
            Text(l.text(key)).font(.footnote).foregroundStyle(.secondary)
          }
          if store.products.isEmpty && !hidesStoreStatus {
            Button(l.text("retry")) { Task { await store.loadProducts() } }
          }
          Text(l.text("subscription.disclosure")).font(.caption).foregroundStyle(.secondary)
          Button(l.text("restore")) { Task { await store.restore() } }.disabled(store.busy)
          Button(l.text("manageSubscription")) { manage = true }
          HStack {
            Button(l.text("terms")) { legal = .terms }
            Spacer()
            Button(l.text("privacy")) { legal = .privacy }
          }
        }.padding(24)
      }.background(Color(.systemGroupedBackground)).toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(l.text("close"), systemImage: "xmark") { dismiss() }
        }
      }
      .sheet(item: $legal) { key in LegalView(kind: key.rawValue) }
      .manageSubscriptionsSheet(isPresented: $manage)
      .task { await store.loadProducts() }
    }
  }
  // Store screenshots (debug builds, `--shots`) show the benefits without prices or load errors.
  private var hidesStoreStatus: Bool {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains("--shots")
    #else
      false
    #endif
  }
}
enum LegalDocument: String, Identifiable {
  case terms, privacy, calculation
  var id: String { rawValue }
}
struct LegalView: View {
  let kind: String
  @Environment(AppLocalization.self) private var l
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        Text(l.text("legal." + kind)).frame(maxWidth: .infinity, alignment: .leading).padding(24)
        if kind == "terms" {
          Link(
            l.text("apple.terms"),
            destination: URL(
              string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        }
      }.navigationTitle(l.text(kind)).toolbar { Button(l.text("done")) { dismiss() } }
    }
  }
}
