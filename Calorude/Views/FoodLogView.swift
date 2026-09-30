import SwiftData
import SwiftUI

struct FoodLogView: View {
  let profile: UserProfile
  let date: Date
  let previousReactionKey: String?
  var onCommitted: (MealReaction?) -> Void
  @Environment(AppLocalization.self) private var l
  @Environment(StoreService.self) private var store
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query private var custom: [CustomFood]
  @Query private var favorites: [FavoriteFood]
  @Query private var meals: [SavedMeal]
  @State private var vm: MealEditorViewModel
  @State private var foods: [Food] = []
  @State private var query = ""
  @State private var selected: PortionSelection?
  @State private var showCustom = false
  @State private var error = false
  @State private var confirmDiscard = false
  @State private var foodTab = "popular"
  @Query(sort: \FoodEntry.date, order: .reverse) private var recentEntries: [FoodEntry]
  @State private var mealName = ""
  @State private var showPaywall = false
  @State private var templateSaved = false
  @FocusState private var searchFocused: Bool

  init(
    profile: UserProfile, date: Date, initialMeal: MealType = .lunch,
    previousReactionKey: String? = nil,
    onCommitted: @escaping (MealReaction?) -> Void = { _ in }
  ) {
    self.profile = profile
    self.date = date
    self.previousReactionKey = previousReactionKey
    self.onCommitted = onCommitted
    _vm = State(initialValue: MealEditorViewModel(meal: initialMeal))
  }
  private var filtered: [Food] {
    let all = foods + custom.map(\.food)
    let recentIDs = Array(NSOrderedSet(array: recentEntries.map(\.foodID))) as? [String] ?? []
    let popular = ["egg", "chicken", "rice", "banana", "tomato", "yogurt"]
    let result = all.filter { food in
      if !query.isEmpty { return food.name(l.language).localizedStandardContains(query) }
      switch foodTab {
      case "recent": return recentIDs.contains(food.id)
      case "breakfast":
        return [
          "egg", "eggwhite", "bread", "oats", "cheese", "feta", "olives", "honey", "tomato",
          "cucumber", "yogurt",
        ].contains(food.id)
      case "mains": return ["protein", "grain", "meal", "fastFood"].contains(food.category)
      case "snacks":
        return ["fruit", "sweet", "drink"].contains(food.category)
          || ["almonds", "walnuts", "hazelnuts", "peanuts", "ricecake"].contains(food.id)
      case "favorites": return favorites.contains { $0.foodID == food.id }
      default: return true
      }
    }
    let order = foodTab == "recent" ? recentIDs : popular
    return result.sorted {
      (order.firstIndex(of: $0.id) ?? 1000) < (order.firstIndex(of: $1.id) ?? 1000)
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text(l.text("foodScreen.subtitle")).font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.bottom, 6)
          VStack(alignment: .leading, spacing: 12) {
            stepTitle("foodScreen.stepMeal")
            mealCards
          }
          if !vm.currentItems.isEmpty { draftSection }
          VStack(alignment: .leading, spacing: 12) {
            stepTitle("foodScreen.stepFood")
            HStack(spacing: 12) {
              Image(systemName: "magnifyingglass").foregroundStyle(Theme.interactive)
              TextField(l.text("search.food"), text: $query).focused($searchFocused)
                .autocorrectionDisabled().submitLabel(.search).onSubmit { searchFocused = false }
                .accessibilityIdentifier("food.search")
              if !query.isEmpty {
                Button {
                  query = ""
                } label: {
                  Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel(l.text("search.clear"))
              }
            }.padding(16).background(
              Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(
                  ["popular", "recent", "breakfast", "mains", "snacks", "favorites"], id: \.self
                ) { tab in
                  Button {
                    foodTab = tab
                  } label: {
                    Text(l.text("foodScreen.tab." + tab)).font(.caption.weight(.semibold))
                      .padding(.horizontal, 16).padding(.vertical, 12)
                      .foregroundStyle(foodTab == tab ? Theme.ink : Color.secondary)
                      .background(
                        foodTab == tab ? Theme.accent : Color(.secondarySystemGroupedBackground),
                        in: Capsule())
                  }.buttonStyle(.plain).accessibilityIdentifier("food.filter." + tab)
                    .accessibilityAddTraits(foodTab == tab ? .isSelected : [])
                }
              }
            }
            LazyVStack(spacing: 10) {
              ForEach(filtered) { food in foodCard(food) }
            }
            if filtered.isEmpty {
              Text(l.text("search.empty")).foregroundStyle(.secondary).padding()
            }
            Button(l.text("custom.create"), systemImage: "plus.circle.fill") {
              if store.isPro || custom.count < 10 { showCustom = true } else { showPaywall = true }
            }.font(.subheadline.bold()).padding(.vertical, 10)
          }
          savedMealsSection
          Text(l.text("food.estimates")).font(.caption).foregroundStyle(.secondary)
        }.padding(20)
      }.background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(l.text("foodScreen.title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
          if !searchFocused {
            PrimaryButton(title: l.text("foodScreen.addSelected"), icon: "arrow.right") { commit() }
              .disabled(!vm.canSave).opacity(vm.canSave ? 1 : 0.45)
              .accessibilityIdentifier("mealEditor.save")
              .padding(.horizontal, 20).padding(.vertical, 12)
              .background(.ultraThinMaterial)
          }
        }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              if vm.hasChanges { confirmDiscard = true } else { dismiss() }
            } label: {
              Image(systemName: "chevron.left")
            }
            .accessibilityLabel(l.text("cancel")).accessibilityIdentifier("mealEditor.cancel")
          }
        }
        .task { load() }
        .navigationDestination(item: $selected) { selection in
          PortionEditorView(selection: selection) { food, grams in
            if let id = selection.entryID {
              vm.update(id: id, grams: grams, food: food)
            } else {
              vm.add(food: food, grams: grams)
            }
            query = ""
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
          }
        }
        .sheet(isPresented: $showCustom) { CustomFoodView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert(l.text("error.save"), isPresented: $error) { Button(l.text("ok"), role: .cancel) {} }
        .confirmationDialog(
          l.text("mealEditor.discardQuestion"), isPresented: $confirmDiscard,
          titleVisibility: .visible
        ) {
          Button(l.text("mealEditor.discard"), role: .destructive) { dismiss() }
          Button(l.text("mealEditor.keepEditing"), role: .cancel) {}
        }
    }.interactiveDismissDisabled(vm.hasChanges)
  }
  private func mealSymbol(_ meal: MealType) -> String {
    switch meal {
    case .breakfast: "sun.max"
    case .lunch: "sun.max.fill"
    case .dinner: "sunset"
    case .snack: "moon"
    case .treat: "takeoutbag.and.cup.and.straw"
    }
  }
  private var mealCards: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 7) {
      ForEach(MealType.allCases, id: \.self) { meal in
        Button {
          searchFocused = false
          vm.meal = meal
          templateSaved = false
          UISelectionFeedbackGenerator().selectionChanged()
        } label: {
          Color.clear.frame(height: 94)
            .overlay {
              VStack(spacing: 8) {
                Image(systemName: mealSymbol(meal)).font(.system(size: 25, weight: .light))
                  .accessibilityHidden(true)
                Text(l.text("meal." + meal.rawValue)).font(.caption.weight(.bold))
                  .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
              }.padding(6)
            }
            .foregroundStyle(vm.meal == meal ? Theme.ink : Color.primary)
            .background(
              vm.meal == meal ? Theme.accent : Color(.secondarySystemGroupedBackground),
              in: RoundedRectangle(cornerRadius: 14)
            )
        }.buttonStyle(.plain).accessibilityIdentifier("mealEditor.meal." + meal.rawValue)
          .accessibilityAddTraits(vm.meal == meal ? .isSelected : [])
      }
    }.accessibilityIdentifier("mealEditor.meal")
  }
  private var draftSection: some View {
    Panel {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text(l.text("mealEditor.contents")).font(.headline)
          Spacer()
          Text(l.number(Double(vm.currentItems.count))).font(.caption.bold())
            .padding(8).background(Theme.interactive.opacity(0.12), in: Circle())
        }
        if vm.currentItems.isEmpty {
          HStack(spacing: 12) {
            Image(systemName: "fork.knife.circle").font(.largeTitle).foregroundStyle(
              Theme.interactive)
            Text(l.text("mealEditor.empty")).font(.subheadline).foregroundStyle(.secondary)
          }.padding(.vertical, 8)
        }
        ForEach(vm.currentItems) { item in
          HStack(spacing: 12) {
            Button {
              searchFocused = false
              selected = PortionSelection(food: item.food, grams: item.grams, entryID: item.id)
            } label: {
              HStack {
                FoodThumbnail(food: item.food, size: 36)
                VStack(alignment: .leading, spacing: 5) {
                  Text(item.food.name(l.language)).font(.subheadline.bold())
                  if let key = item.food.preparationTitleKey {
                    Text(l.text(key)).font(.caption).foregroundStyle(.secondary)
                  }
                  Text(
                    l.number(item.grams) + " " + l.text(item.food.unitKey) + " · "
                      + l.number(item.nutrition.calories) + " " + l.text("unit.kcal")
                  )
                  .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "pencil").font(.caption).foregroundStyle(Theme.interactive)
              }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("mealEditor.item." + item.food.id)
            Button(role: .destructive) {
              vm.remove(id: item.id)
            } label: {
              Image(systemName: "minus.circle.fill").frame(width: 44, height: 44)
            }.buttonStyle(.plain)
              .accessibilityLabel(l.text("delete") + " " + item.food.name(l.language))
              .accessibilityIdentifier("mealEditor.remove." + item.food.id)
          }
        }
        if !vm.currentItems.isEmpty {
          Divider()
          VStack(alignment: .leading, spacing: 8) {
            Text(
              l.text("mealEditor.total") + " · " + l.number(vm.total.calories) + " "
                + l.text("unit.kcal")
            )
            .font(.title3.bold()).foregroundStyle(Theme.interactive)
            Text(
              l.text("protein") + " " + l.number(vm.total.protein) + " · " + l.text("carbs") + " "
                + l.number(vm.total.carbs) + " · " + l.text("fat") + " " + l.number(vm.total.fat)
                + " " + l.text("unit.g")
            )
            .font(.caption).foregroundStyle(.secondary)
          }.accessibilityIdentifier("mealEditor.total")
        }
      }
    }
  }
  private func stepTitle(_ key: String) -> some View {
    Text(l.text(key)).font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
  }
  private func foodCard(_ food: Food) -> some View {
    Button {
      searchFocused = false
      selected = PortionSelection(food: food, grams: food.servingAmount)
    } label: {
      HStack(spacing: 10) {
        FoodThumbnail(food: food, size: 48)
        VStack(alignment: .leading, spacing: 5) {
          Text(food.name(l.language)).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
          Text(l.number(food.servingAmount) + " " + l.text(food.unitKey))
            .font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
        Text(
          l.number(food.nutrition(grams: food.servingAmount).calories) + " " + l.text("unit.kcal")
        )
        .font(.caption).foregroundStyle(.secondary).fixedSize()
        Image(systemName: "plus").font(.title3.weight(.medium))
          .foregroundStyle(Color.primary).frame(width: 36, height: 36)
          .background(Color.primary.opacity(0.05), in: Circle())
      }.padding(12).frame(minHeight: 70)
        .background(
          Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }.buttonStyle(.plain).accessibilityIdentifier("food.result." + food.id)
      .contextMenu {
        Button {
          toggleFavorite(food)
        } label: {
          Label(
            l.text("favorite.toggle"),
            systemImage: favorites.contains { $0.foodID == food.id } ? "star.fill" : "star")
        }
      }
  }
  @ViewBuilder private var savedMealsSection: some View {
    if !meals.isEmpty {
      Panel {
        VStack(alignment: .leading, spacing: 14) {
          Text(l.text("savedMeals")).font(.headline)
          ForEach(meals) { saved in
            HStack {
              Button {
                do { try vm.add(savedMeal: saved) } catch { self.error = true }
              } label: {
                Label(saved.name, systemImage: "plus.rectangle.on.rectangle")
              }
              Spacer()
              Button(l.text("delete"), role: .destructive) {
                context.delete(saved)
                save()
              }
              .font(.caption).frame(minHeight: 44)
            }
          }
        }
      }
    }
    if !vm.currentItems.isEmpty {
      Panel {
        VStack(alignment: .leading, spacing: 14) {
          Text(l.text("mealEditor.reuse")).font(.headline)
          TextField(l.text("savedMeal.name"), text: $mealName).padding(12)
            .background(
              Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
          Button(l.text("savedMeal.save")) { saveTemplate() }
            .disabled(mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          if templateSaved {
            Text(l.text("mealEditor.templateSaved")).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }
  }
  private func load() {
    guard !vm.isLoaded else { return }
    do {
      let start = Calendar.current.startOfDay(for: date)
      let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
      let entries = try context.fetch(
        FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.date >= start && $0.date < end }))
      try vm.load(entries: entries)
      foods = try (FoodRepository.bundled ?? FoodRepository()).foods
    } catch { self.error = true }
  }
  private func commit() {
    guard vm.canSave else { return }
    do {
      try MealRepository.commit(
        items: vm.items, originals: vm.originals, date: date, profile: profile, context: context)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      onCommitted(
        MealReactionEngine.reaction(
          items: vm.items, originals: vm.originals, date: date,
          intensity: profile.coachIntensity.available(isPro: store.isPro),
          excluding: previousReactionKey))
      dismiss()
    } catch { self.error = true }
  }
  private func save() {
    do { try context.save() } catch {
      context.rollback()
      self.error = true
    }
  }
  private func toggleFavorite(_ food: Food) {
    if let favorite = favorites.first(where: { $0.foodID == food.id }) {
      context.delete(favorite)
    } else {
      context.insert(FavoriteFood(food.id))
    }
    save()
  }
  private func saveTemplate() {
    guard store.isPro || meals.count < 3 else {
      showPaywall = true
      return
    }
    do {
      let items = try vm.currentItems.map { try SavedMealItem(food: $0.food, grams: $0.grams) }
      context.insert(
        SavedMeal(name: mealName.trimmingCharacters(in: .whitespacesAndNewlines), items: items))
      try context.save()
      mealName = ""
      templateSaved = true
    } catch {
      context.rollback()
      self.error = true
    }
  }
}
