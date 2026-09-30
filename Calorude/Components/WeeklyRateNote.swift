import SwiftUI

struct WeeklyRateNote: View {
  var viewModel: OnboardingViewModel
  @Environment(AppLocalization.self) private var l

  var body: some View {
    if viewModel.isWeeklyChangeLimited {
      VStack(alignment: .leading, spacing: 8) {
        Text(
          l.text("weekly.estimated") + ": " + l.number(viewModel.estimatedWeeklyChange, digits: 2)
            + " " + l.text("kg.week")
        )
        .fontWeight(.semibold)
        Text(l.text("weekly.limited"))
      }.font(.footnote).foregroundStyle(.secondary).accessibilityElement(children: .combine)
    }
  }
}
