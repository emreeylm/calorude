import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> CoachEntry {
    CoachEntry(date: .now, content: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (CoachEntry) -> Void) {
    let content = context.isPreview ? .placeholder : (WidgetStore.load()?.content(at: .now) ?? .placeholder)
    completion(CoachEntry(date: .now, content: content))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CoachEntry>) -> Void) {
    let now = Date()
    let snapshot = WidgetStore.load()
    let midnight =
      Calendar.current.nextDate(
        after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
      ?? now.addingTimeInterval(3600 * 12)
    // The second entry flips to the empty day at midnight, before the app has had a chance to run.
    let entries = [now, midnight].map {
      CoachEntry(date: $0, content: snapshot?.content(at: $0) ?? .placeholder)
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

struct CalorudeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "CalorudeWidget", provider: Provider()) { entry in
      CoachWidgetView(entry: entry)
    }
    .configurationDisplayName("widget.name")
    .description("widget.description")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main struct CalorudeWidgetBundle: WidgetBundle {
  var body: some Widget { CalorudeWidget() }
}

#Preview("Medium", as: .systemMedium) {
  CalorudeWidget()
} timeline: {
  CoachEntry(date: .now, content: .placeholder)
}

#Preview("Small", as: .systemSmall) {
  CalorudeWidget()
} timeline: {
  CoachEntry(date: .now, content: .placeholder)
}
