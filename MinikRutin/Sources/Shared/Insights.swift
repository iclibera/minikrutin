import Foundation

/// Pure aggregation helpers over a baby's log entries. Operate on already
/// baby-filtered arrays so views can pass `@Query` results straight in.
enum Insights {
    static var cal: Calendar { Fmt.calendar }

    static func entries(_ all: [LogEntry], type: EntryType) -> [LogEntry] {
        all.filter { $0.type == type && !$0.deleted }
    }

    static func last(_ all: [LogEntry], type: EntryType) -> LogEntry? {
        entries(all, type: type).max(by: { $0.date < $1.date })
    }

    static func today(_ all: [LogEntry], type: EntryType, now: Date = Date()) -> [LogEntry] {
        entries(all, type: type).filter { cal.isDate($0.date, inSameDayAs: now) }
    }

    static func todayFeedingML(_ all: [LogEntry], now: Date = Date()) -> Double {
        today(all, type: .feeding, now: now).compactMap { $0.amountML }.reduce(0, +)
    }

    static func todaySleepMinutes(_ all: [LogEntry], now: Date = Date()) -> Double {
        entries(all, type: .sleep)
            .filter { cal.isDate($0.date, inSameDayAs: now) }
            .map { $0.sleepMinutes }
            .reduce(0, +)
    }

    static func todayDiaperCount(_ all: [LogEntry], now: Date = Date()) -> Int {
        today(all, type: .diaper, now: now).count
    }

    // MARK: Last 7 days

    /// Returns the last 7 calendar days (oldest first) with the matching entries.
    static func lastSevenDays(now: Date = Date()) -> [Date] {
        let start = cal.startOfDay(for: now)
        return (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: start) }
    }

    static func dailyCounts(_ all: [LogEntry], type: EntryType, now: Date = Date()) -> [(day: Date, count: Int)] {
        let days = lastSevenDays(now: now)
        let items = entries(all, type: type)
        return days.map { day in
            (day, items.filter { cal.isDate($0.date, inSameDayAs: day) }.count)
        }
    }

    static func dailyFeedingML(_ all: [LogEntry], now: Date = Date()) -> [(day: Date, ml: Double)] {
        let days = lastSevenDays(now: now)
        let items = entries(all, type: .feeding)
        return days.map { day in
            (day, items.filter { cal.isDate($0.date, inSameDayAs: day) }.compactMap { $0.amountML }.reduce(0, +))
        }
    }

    static func dailySleepMinutes(_ all: [LogEntry], now: Date = Date()) -> [(day: Date, minutes: Double)] {
        let days = lastSevenDays(now: now)
        let items = entries(all, type: .sleep)
        return days.map { day in
            (day, items.filter { cal.isDate($0.date, inSameDayAs: day) }.map { $0.sleepMinutes }.reduce(0, +))
        }
    }

    // MARK: 7-day summaries

    static func windowEntries(_ all: [LogEntry], days: Int = 7, now: Date = Date()) -> [LogEntry] {
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: now)) else { return [] }
        return all.filter { !$0.deleted && $0.date >= start }
    }

    static func avgFeedingsPerDay(_ all: [LogEntry], days: Int = 7, now: Date = Date()) -> Double {
        Double(entries(windowEntries(all, days: days, now: now), type: .feeding).count) / Double(days)
    }

    static func avgDiapersPerDay(_ all: [LogEntry], days: Int = 7, now: Date = Date()) -> Double {
        Double(entries(windowEntries(all, days: days, now: now), type: .diaper).count) / Double(days)
    }

    static func avgSleepMinutesPerDay(_ all: [LogEntry], days: Int = 7, now: Date = Date()) -> Double {
        let total = entries(windowEntries(all, days: days, now: now), type: .sleep).map { $0.sleepMinutes }.reduce(0, +)
        return total / Double(days)
    }

    static func totalFeedingML(_ all: [LogEntry], days: Int = 7, now: Date = Date()) -> Double {
        entries(windowEntries(all, days: days, now: now), type: .feeding).compactMap { $0.amountML }.reduce(0, +)
    }

    static func feverEntries(_ all: [LogEntry], days: Int = 7, now: Date = Date()) -> [LogEntry] {
        entries(windowEntries(all, days: days, now: now), type: .medicine).filter { $0.temperatureC != nil }
    }

    static func noteEntries(_ all: [LogEntry], days: Int = 7, now: Date = Date()) -> [LogEntry] {
        entries(windowEntries(all, days: days, now: now), type: .note)
    }

    /// Days (out of `days`) that have at least one dirty/both diaper.
    static func dirtyDiaperDays(_ all: [LogEntry], days: Int = 7, now: Date = Date()) -> Int {
        let dirty = entries(windowEntries(all, days: days, now: now), type: .diaper)
            .filter { $0.diaperKind == .dirty || $0.diaperKind == .both }
        let grouped = Set(dirty.map { cal.startOfDay(for: $0.date) })
        return grouped.count
    }
}
