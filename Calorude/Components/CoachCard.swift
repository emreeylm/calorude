import SwiftData
import SwiftUI

struct CoachCard: View {
  var profile: UserProfile
  var stats: DayStats
  @Environment(AppLocalization.self) private var l
  @Environment(StoreService.self) private var store
  @State private var showShare = false

  private var voice: CoachVoice {
CoachVoice(level: profile.coachIntensity, isPro: store.isPro)
  }

  var body: some View {
    let context = RoastContext(stats: stats)
    let key = DayCoach.key(
      state: DayCoach.state(for: context), voice: voice,
      variant: DayCoach.variant(day: stats.day, context: context))
    let comment = context.text(l.text(key), l: l)
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "quote.bubble.fill")
        Text(l.text(voice.titleKey)).font(.caption.weight(.heavy)).tracking(2).lineLimit(1)
          .minimumScaleFactor(0.7)
        Text(l.text("intensity." + voice.level.key))
          .font(.caption2.weight(.bold)).lineLimit(1).padding(.horizontal, 8).padding(.vertical, 3)
          .overlay(Capsule().stroke(Theme.ink.opacity(0.5), lineWidth: 1))
        Spacer()
      }.foregroundStyle(Theme.ink.opacity(0.7))
      Text(comment).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("coach.message")
      Text(
        l.number(stats.calories) + " / " + l.number(stats.target) + " " + l.text("unit.kcal")
          + " · " + l.text("protein") + " " + l.number(stats.protein) + " / "
          + l.number(stats.proteinTarget) + " " + l.text("unit.g")
      )
      .font(.caption).accessibilityIdentifier("coach.dailyTotals")
    }.padding(22).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Theme.ink)
      .background(Theme.accent, in: RoundedRectangle(cornerRadius: 24)).accessibilityElement(
        children: .combine
      ).accessibilityIdentifier("coach.card")
      // Outside the combined element so VoiceOver can reach it as its own control.
      .overlay(alignment: .topTrailing) {
        Button {
          showShare = true
        } label: {
          Image(systemName: "square.and.arrow.up").font(.body.weight(.semibold))
            .foregroundStyle(Theme.ink.opacity(0.7)).frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }.padding(8).accessibilityLabel(l.text("coach.shareStory"))
          .accessibilityIdentifier("coach.share")
      }
      .sheet(isPresented: $showShare) {
        ShareComposerView(profile: profile, date: stats.day, kind: .roast, roast: comment)
      }
  }
}
