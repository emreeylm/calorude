import SwiftUI

// Shows the automatically chosen pace and how long the goal should take at that pace.
struct WeeklyRateNote: View {
  var viewModel: OnboardingViewModel
  @Environment(AppLocalization.self) private var l

  var body: some View {
    if viewModel.goal != .maintain, let weeks = viewModel.weeksToGoal {
      VStack(alignment: .leading, spacing: 8) {
        Text(paceText).fontWeight(.semibold)
        Text(timelineText(weeks: weeks))
        Text(l.text("ob.result.auto"))
      }.font(.footnote).foregroundStyle(.secondary).accessibilityElement(children: .combine)
    }
  }

  private var paceText: String {
    let rate = l.number(viewModel.estimatedWeeklyChange, digits: 2)
    return l.text("weekly.estimated") + ": " + rate + " " + l.text("kg.week")
  }

  private func timelineText(weeks: Int) -> String {
    var text = l.text("ob.result.timeline") + ": ~" + l.number(Double(weeks))
    text += " " + l.text("ob.result.weeks")
    if let date = viewModel.targetDate {
      text += " (" + date.formatted(.dateTime.month(.wide).year().locale(l.locale)) + ")"
    }
    return text
  }
}
