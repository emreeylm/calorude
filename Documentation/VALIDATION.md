# Validation — 5 September 2026

Environment: Xcode 26.2 (17C52), Swift 6.2.3 compiler in Swift 5 language mode, iPhone 16e / iOS 26.2 simulator. Deployment target: iOS 17.

- Simulator Debug: build succeeded.
- 11 core XCTest methods: passed, including both-language renders of all four 1080×1920 story templates.
- 1 StoreKit integration test: passed (product loading, verified monthly purchase, expiration, verified lifetime purchase, annual savings).
- 2 UI tests: passed (Turkish and English onboarding → log egg → progress → switch language → light appearance).
- Generic physical iOS Release: build succeeded, signing disabled for local verification. This is not a signed distribution archive.
- Resource audit: 344 fully bilingual String Catalog entries, 112 unique message pairs, 33 food records; all directly referenced catalog keys resolve.
- App icon: 1024×1024 opaque RGB PNG.
- Exported story and UI images inspected for clipping, branding, language, text layout and contrast. The initial story overflow was fixed before the passing run.

Test result bundle during development:
`/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.05_13-56-23-+0300.xcresult`

Release log during development: `/tmp/calorude-release.log`.

Selected actual test outputs are in `Previews/`. Dashboard images are empty-state UI-test screenshots; story images use explicitly synthetic test values, not a user's health records.

Not represented by these checks: App Store Connect approval/live storefront purchases, real-device notification delivery, Instagram's installed share extension, real sandbox billing failure/grace/refund flows, all iPad sizes, and iOS 17 runtime testing (only iOS 26.2 is installed). These remain release-validation tasks, not claims of completed testing.

## Meal editor update — 18:10

The meal editor now stages multiple food additions, portion changes and removals before one Save. Dashboard meal cards reopen the editor for the chosen meal. Cancel discards diary changes, and changing meal selection preserves other staged meals. Nutrition fingerprints trigger derived-summary and notification refreshes even when edited entries retain their IDs.

Five new MealEditorTests passed: batch addition/edit/removal with recalculated summaries; canceled/invalid draft isolation; meal switching and saved-meal staging; deleting a meal while retaining other meals/dates; and concurrent-edit rejection. The initial fixture lifetime issue was corrected by retaining its in-memory ModelContainer.

Both Turkish and English UI flows passed: add 150 g rice, 200 g chicken and 100 g yogurt without closing the editor, save the 646 kcal meal, reopen, change rice to 200 g, remove chicken, save the 401 kcal meal, reopen to verify, and cancel a later edit. Screenshots in `Previews/tr-meal-draft.png` and `Previews/tr-meal-edited.png` were visually inspected. Resource audit: 364 bilingual keys. Swift formatting lint passed.

Result: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.05_18-07-22-+0300.xcresult` — TEST SUCCEEDED.

## Meal reaction popup — 7 September 2026

Saving a single food or a batch now presents one coach reaction after the editor dismisses. The reaction evaluates the contents of affected meals and respects coach intensity. Its exact message and nutrition snapshot export as a 1080×1920 PNG through the existing system share sheet. No reaction is shown for cancel, unchanged saves, or deletion-only saves.

Five meal-editor tests and three meal-reaction tests passed, covering composition classification, single foods, small desserts, changed-meal isolation, localization and six story renders. Both Turkish and English UI flows passed, including balanced/everyday/snack-heavy popups, dismissal, subsequent meal editing and cancel. Resource validation passed with 400 bilingual keys; 27 reaction message pairs supplement the existing 112 roast pairs. Swift formatting lint passed.

Turkish popup and Turkish/English story exports were visually inspected for clipping and legibility. Selected images are saved in Previews/tr-meal-reaction-popup.png, Previews/tr-meal-reaction-story.png and Previews/tr-meal-reaction-snack-story.png. Story nutrition values are synthetic test fixtures. Actual Instagram share-extension behavior on a physical device remains unverified.

Result: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.07_18-36-58-+0300.xcresult` — TEST SUCCEEDED (8 unit tests and 2 UI tests).

## Dashboard coach refresh — 7 September 2026, 18:56

The dashboard now displays the latest committed meal reaction for its selected date, using a persisted localized message key and date. The popup and dashboard share the same message. Consecutive saves in the same verdict/tone cycle through all three variants before repeating. Cancel and failed saves do not advance the message. Other dates retain the daily-context coach fallback.

Four MealReactionTests and the Turkish UI flow passed. The new rotation test checks 24 consecutive selections for each of nine verdict/tone combinations. UI assertions confirm the dashboard contains the popup's exact message after balanced, everyday and snack-heavy saves. Resource validation and formatting lint passed. Persistence is implemented with AppStorage; relaunch behavior was not separately UI-tested in this run.

Result: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.07_18-54-06-+0300.xcresult` — TEST SUCCEEDED.

## Food catalog and liquid units — 7 September 2026, 19:06

The Turkish standard coach heading is now KOÇUN YORUMU. The bundled food catalog grew from 33 to 67 entries, with manufacturer-backed branded drinks, two TürKomp vegetables, water/coffee and documented recipe estimates. See FOOD_SOURCES.md for provenance, denominators and recipe yields.

Foods have an explicit grams/ml unit. Portion prompts, presets, search nutrition denominators, draft rows and diary rows use the food's unit. Custom food creation supports values per 100 ml. SwiftData entries snapshot the unit, and saved-meal JSON carries it. Missing legacy cola/ayran units resolve to ml with unchanged numeric amounts and nutrient totals; other old foods default to g. There is no universal density conversion. Protein/carbs/fat remain measured in grams.

Six MealEditorTests and four MealReactionTests passed. Unit coverage includes legacy JSON without a unit, historical diary snapshots, 330 ml cola yielding 138.6 kcal, an edit to 200 ml yielding 84 kcal, and custom ml drinks serialized into saved meals. The Turkish UI flow passed, including the ml prompt, 330 ml preset, successful save and 330 ml diary label. Resource validation passed: 408 bilingual keys, 112 existing roast pairs, 67 unique foods. Formatting lint passed.

Result: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.07_19-03-41-+0300.xcresult` — TEST SUCCEEDED (10 unit tests and 1 UI test). A production-store migration from a separately installed older binary was not exercised in this run.

## 80 foods/meals and 20 drinks — 7 September 2026

Catalog validation now enforces exactly 100 unique IDs and localized names, 80 gram-based food/meal entries and 20 ml-based drinks. Added 28 basic foods and five drinks; all previous 67 IDs remain. The review list is FOOD_CATALOG_100.md, with new source records in CATALOG100_SOURCES.json. This is a curated practical list rather than a measured popularity ranking.

Resource audit passed (408 bilingual keys, 100 foods). Six MealEditorTests and four MealReactionTests passed, including exact catalog counts, core food availability, legacy units, quantity edits, preserved snapshots and reaction classification. This data-only update did not change view layout; UI tests were not repeated. Test log: `/tmp/calorude-catalog100.log`.

## Turkish PRO currency — 7 September 2026, 19:38

The local Development.storekit storefront was USA/en_US. It now defaults to TUR/tr_TR with the originally requested Turkish planning amounts: monthly 79.99, annual 499.99 and lifetime 799.99 TRY. Paywall already uses Product.displayPrice and priceFormatStyle; no hardcoded currency substitution or currency conversion was introduced. Live App Store Connect regional pricing was not modified.

Two StoreIntegrationTests passed: default Turkish amounts and TRY currency; USA/USD; TUR with English locale still TRY; verified monthly purchase, expiration, lifetime access; annual savings 47 percent. Local storefront switching changes currency presentation, not the file's numerical price schedule. Regional production behavior follows Apple's StoreKit storefront: https://developer.apple.com/documentation/storekit/product/displayprice .

Result: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.07_19-37-57-+0300.xcresult` — TEST SUCCEEDED.

## Daily coach and catalog review — 7 September 2026, 19:43

Dashboard coach no longer receives the last saved meal reaction. It uses a dedicated daily rule based on selected-day calories/protein, targets, logged-entry presence and time of day; streak/history/individual food categories do not override that daily decision. Daily totals are shown on the card. Meal popup selection, sharing and consecutive-message rotation remain separate.

13 CoreTests and the Turkish UI flow passed. New coverage exercises the daily rule despite conflicting meal/history context, morning versus evening and empty days. UI verifies that the dashboard comment differs from each saved meal popup; batch editing and ml drink logging still pass. Resource validation and formatting lint passed. Catalog review in FOOD_CATALOG_REVIEW.md identifies preparation-state, local-meal, portion and nutrient-coverage gaps; the catalog remains 80 foods/meals plus 20 drinks.

Result: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.07_19-40-38-+0300.xcresult` — TEST SUCCEEDED.

## Preparation selection and household portions — 8 September 2026

Food list names omit preparation-state suffixes. Supported foods expose raw/dry and cooked profiles inside the portion editor. The chosen profile changes nutrient calculations and is snapshotted in diary entries and saved meals. Editing can change preparation while preserving the entry date and target snapshots. Legacy entries retain their historical nutrient values.

The catalog now contains 88 foods/meals and 20 drinks. Eight additions: sea bass, trout, peas, barbunya, whole-wheat pasta, mushrooms, anchovy and grilled meatballs. Sources and estimates are recorded in PREPARATION_SOURCES.json and FOOD_SOURCES.md. Missing micronutrient coverage remains deferred as requested. Household portions use food-specific approximate weights, with gram/ml input retained; incompatible cooked household measures are hidden for raw profiles.

Seven MealEditorTests and four MealReactionTests passed (7 September unit result: Test-Calorude-2026.09.07_20-03-26-+0300.xcresult). The Turkish UI flow passed on 8 September, checking raw chicken 100 g = 120 kcal versus cooked 165 kcal, two 200 ml glasses of cola = 168 kcal, batch saving and editing, and liquid diary units. The initial UI quantity replacement positioned the cursor at the start; the test now taps the trailing edge before replacing text. No production input change was needed. Resource validation passed: 424 bilingual strings, 112 roast pairs and 108 foods. Swift formatting lint passed.

UI result: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.08_13-04-25-+0300.xcresult` — TEST SUCCEEDED. English UI and migration from an independently installed older binary were not rerun in this change.

## Stronger coach tone separation — 8 September 2026

Rewrote 70 savage/unhinged context messages and 18 savage/unhinged meal reactions in both Turkish and English (88 bilingual pairs). Normal copy stays unchanged. All free and Pro variants in the two stronger modes now use more direct criticism and sharper sarcasm; unhinged adds colloquial profanity. Positive outcomes keep their praise with an abrasive delivery. Criticism addresses the plan, logging and choices; low-intake messages still prompt eating and high-intake messages do not recommend compensatory restriction.

Resource validation passed (424 bilingual keys, 112 unique context messages per language, 108 foods). All 13 CoreTests and four MealReactionTests passed, covering localization, rule evaluation, consecutive reaction rotation and 1080×1920 story exports. Visually reviewed the Turkish unhinged snack-heavy story export for text fit. Full UI flow was not rerun for this copy-only change.

Result: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.08_13-13-39-+0300.xcresult` — TEST SUCCEEDED (17 tests).

## Meal editor visual redesign — 9 September 2026

Replaced the settings-style List with a ScrollView and app-native rounded panels. Breakfast, lunch, dinner and snack are selectable emoji cards with the name below the emoji, a lime selected background and an accessibility selected trait. Food search has a custom field, favorites chip, individual food cards and clear action. Draft entries retain edit/remove controls and macro totals. Save is pinned to the bottom outside keyboard entry. Saved templates retain add, delete and creation controls; explicit deletion replaces List-only swipe actions.

The portion detail also uses panels and a primary action instead of Form. Tapping the padded quantity field focuses input; gram/ml presets avoid wrapping. Existing persistence, preparation profiles and reaction logic are unchanged.

The Turkish full UI flow passed after the quantity-field tap fix: Test-Calorude-2026.09.09_16-41-39-+0300.xcresult. It exercises selected meal cards, multi-food saves, portion edits, removal, cancellation, raw/cooked profiles, glass quantities and diary units. A subsequent visual adjustment makes all meal tile backgrounds fill an equal square instead of hugging their contents. Resource validation (425 bilingual keys) and formatting lint passed.

Final English full flow passed with the equal-square tiles: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.09_16-47-46-+0300.xcresult`. The reveal helper now scrolls targets clear of the pinned bottom action before tapping; an earlier run incorrectly treated a partly obscured search field as tappable. Visually reviewed the final English tile layout; preview saved as Documentation/Previews/meal-editor-cards.png. Turkish full flow passed before the final square-sizing adjustment; English passed after it. Both include the quantity-field focus fix. No new persistence changes or unit tests were required.

## Reference-based food picker — 10 September 2026

Adapted the supplied reference into the native food picker: centered title/subtitle, numbered meal and food steps, five outlined-symbol meal cards, horizontal category pills, compact food rows with food emoji, serving amounts, serving-based calories and plus affordances, and a pinned green commit action. Added the separate treat meal type without renaming existing stored meal values. Meal drafts appear only when populated. Preparation selection remains in detail; raw/cooked names remain absent from the list.

Popular prioritizes six common entries while keeping the catalog available. Recent uses actual diary entries. Breakfast, mains, snacks and favorites filter the catalog; typing searches across the catalog. Favorite management is in each food row's context menu. The reference's photographic thumbnails are represented by emoji; barcode scanning is not implemented or presented as a dead control.

Seven MealEditorTests passed. Resource validation passed with 437 bilingual strings and 108 foods. Visually inspected the Turkish picker and saved Documentation/Previews/meal-editor-reference-tr.png. UI assertions cover the fifth meal card and breakfast filtering in addition to existing multi-food, preparation, edit/cancel and liquid flows. The test scroll helper was adjusted to avoid overshooting fields under the navigation bar or pinned footer.

Final Turkish UI flow passed: `/tmp/calorude-signed/Logs/Test/Test-Calorude-2026.09.10_12-17-42-+0300.xcresult` (TEST SUCCEEDED). English flow was not rerun in this reference update.
