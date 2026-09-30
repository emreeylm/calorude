import SwiftData
import SwiftUI

@main struct CalorudeApp: App {
  @State private var localization = AppLocalization()
  @State private var store = StoreService()
  private let container: ModelContainer?
  init() {
    #if DEBUG
      let inMemory = ProcessInfo.processInfo.arguments.contains("--uitesting")
    #else
      let inMemory = false
    #endif
    do {
      container = try ModelContainer(
        for: Schema(versionedSchema: CalorudeSchemaV1.self),
        migrationPlan: CalorudeMigrationPlan.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none))
    } catch { container = nil }
  }
  var body: some Scene {
    WindowGroup {
      Group {
        if let container {
          RootView().modelContainer(container)
        } else {
          VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
            Text(localization.text("error.storage")).multilineTextAlignment(.center)
          }.padding()
        }
      }.environment(localization).environment(store).environment(\.locale, localization.locale)
        .tint(Theme.interactive)
    }
  }
}
struct RootView: View {
  @Query private var profiles: [UserProfile]
  @Query private var preferences: [AppPreferences]
  @Environment(StoreService.self) private var store
  @Environment(AppLocalization.self) private var l
  @Environment(\.modelContext) private var context
  @Environment(\.scenePhase) private var scenePhase
  @Query(sort: \FoodEntry.date) private var entries: [FoodEntry]
  @State private var refreshDay = Calendar.current.startOfDay(for: Date.now)
  @State private var syncError = false
  private var fingerprint: TrackingFingerprint {
    TrackingFingerprint(
      entries: entries.map(FoodEntryFingerprint.init), language: l.language,
      notifications: preferences.first?.notificationsEnabled ?? false, pro: store.isPro,
      day: refreshDay)
  }
  var body: some View {
    Group {
      if let profile = profiles.first, profile.isOnboardingCompleted {
        MainTabs(profile: profile)
      } else {
        OnboardingView()
      }
    }.preferredColorScheme(preferences.first?.appearance == "light" ? .light : .dark)
      .task { await store.start() }
      .task(id: fingerprint) { await synchronize() }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active {
          refreshDay = Calendar.current.startOfDay(for: .now)
          Task {
            await store.refreshEntitlements()
            await synchronize()
          }
        }
      }
      .alert(l.text("error.save"), isPresented: $syncError) {
        Button(l.text("ok"), role: .cancel) {}
      }
  }
  private func synchronize() async {
    guard let profile = profiles.first else { return }
    do {
      try TrackingCoordinator.rebuild(context: context, profile: profile, entries: entries)
      if preferences.first?.notificationsEnabled == true {
        try await NotificationService.schedule(
          profile: profile, entries: entries, l: l, isPro: store.isPro)
      } else {
        await NotificationService.disable()
      }
    } catch { if !Task.isCancelled { syncError = true } }
  }
}
struct MainTabs: View {
  var profile: UserProfile
  @Environment(AppLocalization.self) private var l
  var body: some View {
    TabView {
      DashboardView(profile: profile).tabItem {
        Label(l.text("tab.today"), systemImage: "square.grid.2x2.fill")
      }
      ProgressScreen(profile: profile).tabItem {
        Label(l.text("tab.progress"), systemImage: "chart.xyaxis.line")
      }
      SettingsView(profile: profile).tabItem {
        Label(l.text("tab.settings"), systemImage: "slider.horizontal.3")
      }
    }.toolbarBackground(.visible, for: .tabBar)
  }
}
