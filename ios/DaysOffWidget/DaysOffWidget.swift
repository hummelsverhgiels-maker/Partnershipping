import SwiftUI
import WidgetKit

// Виджет «Ближайший выходной». Тексты готовит приложение (Flutter) и кладёт
// в общее хранилище (App Group) на 14 дней вперёд. Здесь берём строки за нужный день.

private let groupId = "group.com.partnershipping.partnershipping"

struct DaysOffEntry: TimelineEntry {
    let date: Date
    let me: String
    let partner: String
    let both: String
}

struct DaysOffProvider: TimelineProvider {
    private func read(for date: Date) -> DaysOffEntry {
        let defaults = UserDefaults(suiteName: groupId)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let key = f.string(from: date)
        let me = defaults?.string(forKey: "wm_\(key)") ?? "Откройте приложение, чтобы обновить"
        let partner = defaults?.string(forKey: "wp_\(key)") ?? ""
        let both = defaults?.string(forKey: "wb_\(key)") ?? ""
        return DaysOffEntry(date: date, me: me, partner: partner, both: both)
    }

    func placeholder(in context: Context) -> DaysOffEntry {
        DaysOffEntry(
            date: Date(),
            me: "Я: Выходной в пятницу, 2 дня подряд",
            partner: "Аня: Выходной завтра",
            both: "Вместе: Выходной в субботу, 2 дня подряд")
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysOffEntry) -> Void) {
        completion(read(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysOffEntry>) -> Void) {
        var entries = [read(for: Date())]
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for i in 1...7 {
            if let d = cal.date(byAdding: .day, value: i, to: today) {
                entries.append(read(for: d))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DaysOffView: View {
    let entry: DaysOffEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("БЛИЖАЙШИЕ ВЫХОДНЫЕ")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(red: 0.55, green: 0.50, blue: 0.47))
            Text(entry.me)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.29, green: 0.25, blue: 0.23))
                .minimumScaleFactor(0.7)
            if !entry.partner.isEmpty {
                Text(entry.partner)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.29, green: 0.25, blue: 0.23))
                    .minimumScaleFactor(0.7)
            }
            if !entry.both.isEmpty {
                Text(entry.both)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.76, green: 0.38, blue: 0.25))
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(2)
    }
}

extension View {
    @ViewBuilder
    func softBackground() -> some View {
        let bg = Color(red: 1.0, green: 0.95, blue: 0.92)
        if #available(iOS 17.0, *) {
            self.containerBackground(bg, for: .widget)
        } else {
            self.padding(12).background(bg)
        }
    }
}

@main
struct DaysOffWidget: Widget {
    let kind = "DaysOffWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DaysOffProvider()) { entry in
            DaysOffView(entry: entry).softBackground()
        }
        .configurationDisplayName("Ближайший выходной")
        .description("Ваш выходной, выходной партнёра и общий выходной.")
        .supportedFamilies([.systemMedium, .systemSmall])
    }
}
