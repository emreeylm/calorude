import SwiftData
import SwiftUI

struct SettingsView: View {
  @Bindable var profile: UserProfile
  @Environment(AppLocalization.self) private var l
  @Environment(StoreService.self) private var store
  @Environment(\.modelContext) private var context
  @Query private var preferences: [AppPreferences]
  @State private var showPaywall = false
  @State private var legal: LegalDocument?
  @State private var error = false
  @State private var confirmDelete = false
  @State private var confirmNuclear = false
  @State private var manage = false
  @State private var editPlan = false
  var body: some View {
    @Bindable var localization = l
    NavigationStack {
      Form {
        Section {
          HStack {
            Image(systemName: "bolt.shield.fill").font(.largeTitle).foregroundStyle(Theme.accent)
            VStack(alignment: .leading) {
              Text(AppBrand.name(l)).font(.title2.bold())
              Text(l.text("localOnly")).font(.caption).foregroundStyle(.secondary)
            }
          }
          Button(store.isPro ? AppBrand.pro(l) + " ✓" : l.text("getPro")) { showPaywall = true }
        }
        Section(l.text("profile")) {
          Button(l.text("editPlan")) { editPlan = true }
          TextField(l.text("name"), text: $profile.name)
          LabeledContent(
            l.text("dailyTarget"),
            value: l.number(profile.dailyCalorieTarget) + " " + l.text("unit.kcal"))
          Text(l.text("plan.disclaimer")).font(.caption)
        }
        Section(l.text("preferences")) {
          Picker(l.text("language"), selection: $localization.language) {
            Text(l.text("language.tr")).tag("tr")
            Text(l.text("language.en")).tag("en")
          }.accessibilityIdentifier("settings.language").onChange(of: l.language) { _, language in
            profile.preferredLanguage = language
            preferences.first?.language = language
            save()
          }
          if let pref = preferences.first {
            @Bindable var pref = pref
            Picker(l.text("appearance"), selection: $pref.appearance) {
              Text(l.text("dark")).tag("dark")
              Text(l.text("light")).tag("light")
            }.accessibilityIdentifier("settings.appearance").onChange(of: pref.appearance) {
              save()
            }
            Picker(
              l.text("intensity"),
              selection: Binding(
                get: { profile.coachIntensity.available(isPro: store.isPro) },
                set: { value in
                  if value == .normal {
                    profile.coachIntensity = value
                  } else if !store.isPro {
                    showPaywall = true
                  } else if value == .nuclear {
                    confirmNuclear = true
                  } else {
                    profile.coachIntensity = value
                  }
                })
            ) {
              ForEach(CoachIntensity.allCases, id: \.self) { intensity in
                if store.isPro || intensity == .normal {
                  Text(l.text("intensity." + intensity.rawValue)).tag(intensity)
                } else {
                  Label(l.text("intensity." + intensity.rawValue), systemImage: "lock.fill")
                    .tag(intensity)
                }
              }
            }.accessibilityIdentifier("settings.intensity")
              .onChange(of: profile.coachIntensity) { save() }
            Picker(
              l.text("personality"),
              selection: Binding(
                get: { pref.personality },
                set: { value in
                  if store.isPro || value == .standard {
                    pref.personality = value
                    save()
                  } else {
                    showPaywall = true
                  }
                })
            ) {
              ForEach(Personality.allCases, id: \.self) {
                Text(l.text("personality." + $0.rawValue)).tag($0)
              }
            }
            Toggle(
              l.text("notifications"),
              isOn: Binding(
                get: { pref.notificationsEnabled },
                set: { enabled in
                  Task {
                    pref.notificationsEnabled = enabled ? await NotificationService.enable() : false
                    if !pref.notificationsEnabled { await NotificationService.disable() }
                    save()
                  }
                }))
            Text(l.text("notification.policy")).font(.caption).foregroundStyle(.secondary)
          }
        }
        Section {
          Button(l.text("restore")) { Task { await store.restore() } }
          Button(l.text("manageSubscription")) { manage = true }
          if let key = store.statusKey { Text(l.text(key)).font(.caption) }
          Button(l.text("privacy")) { legal = .privacy }
          Button(l.text("terms")) { legal = .terms }
          Button(l.text("calculation.about")) { legal = .calculation }
        }
        Section { Button(l.text("deleteAll"), role: .destructive) { confirmDelete = true } }
      }.hardBottomEdge().navigationTitle(l.text("tab.settings"))
        .onChange(of: profile.name) {
          // Skip blank names and a profile that erase() just removed.
          guard profile.modelContext != nil,
            !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          else { return }
          save()
        }
        .sheet(isPresented: $editPlan) { EditPlanView(profile: profile) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(item: $legal) { LegalView(kind: $0.rawValue) }
        .manageSubscriptionsSheet(isPresented: $manage)
        .alert(l.text("error.save"), isPresented: $error) { Button(l.text("ok"), role: .cancel) {} }
        .alert(l.text("nuclear.warning.title"), isPresented: $confirmNuclear) {
          Button(l.text("nuclear.warning.confirm"), role: .destructive) {
            profile.coachIntensity = .nuclear
          }
          Button(l.text("cancel"), role: .cancel) {}
        } message: {
          Text(l.text("nuclear.warning.body"))
        }
        .confirmationDialog(
          l.text("delete.confirm"), isPresented: $confirmDelete, titleVisibility: .visible
        ) {
          Button(l.text("deleteAll"), role: .destructive) { erase() }
          Button(l.text("cancel"), role: .cancel) {}
        }
    }
  }
  private func save() {
    do { try context.save() } catch {
      context.rollback()
      self.error = true
    }
  }
  private func erase() {
    do {
      try context.delete(model: FoodEntry.self)
      try context.delete(model: CustomFood.self)
      try context.delete(model: FavoriteFood.self)
      try context.delete(model: SavedMeal.self)
      try context.delete(model: SavedMealItem.self)
      try context.delete(model: WeightEntry.self)
      try context.delete(model: DailySummary.self)
      try context.delete(model: StreakState.self)
      try context.delete(model: AchievementState.self)
      try context.delete(model: AppPreferences.self)
      try context.delete(model: UserProfile.self)
      try context.save()
      UserDefaults.standard.removeObject(forKey: "coach.lastMealMessage")
      Task { await NotificationService.disable() }
    } catch {
      context.rollback()
      self.error = true
    }
  }
}
