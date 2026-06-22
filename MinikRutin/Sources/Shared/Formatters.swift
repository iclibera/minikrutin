import Foundation

enum Fmt {
    static let locale = Locale(identifier: "tr_TR")
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        c.firstWeekday = 2 // Monday
        return c
    }

    // MARK: Time / date

    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f.string(from: date)
    }

    static func dayMonthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .medium
        return f.string(from: date)
    }

    static func weekdayShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    static func relativeDay(_ date: Date) -> String {
        let cal = calendar
        if cal.isDateInToday(date) { return "Bugün" }
        if cal.isDateInYesterday(date) { return "Dün" }
        return shortDate(date)
    }

    // MARK: Age

    /// "2 ay 12 günlük", "14 günlük", "1 yıl 3 ay".
    static func age(from birth: Date, to now: Date = Date()) -> String {
        let cal = calendar
        let comps = cal.dateComponents([.year, .month, .day], from: birth, to: now)
        let y = comps.year ?? 0, m = comps.month ?? 0, d = comps.day ?? 0
        var parts: [String] = []
        if y > 0 { parts.append("\(y) yıl") }
        if m > 0 { parts.append("\(m) ay") }
        if y == 0 { parts.append("\(max(d, 0)) gün") }
        return parts.joined(separator: " ") + "lük"
    }

    // MARK: Durations

    /// minutes -> "6s 40dk", "45dk", "1s".
    static func duration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return "\(h)s \(m)dk" }
        if h > 0 { return "\(h)s" }
        return "\(m)dk"
    }

    /// Elapsed since a date as "2s 15dk", "35dk", "2g".
    static func elapsed(since date: Date, to now: Date = Date()) -> String {
        let mins = max(0, now.timeIntervalSince(date) / 60)
        if mins >= 60 * 24 {
            let days = Int(mins / (60 * 24))
            return "\(days)g önce"
        }
        return duration(minutes: mins) + " önce"
    }

    static func ml(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        return "\(Int(value.rounded())) ml"
    }

    static func temp(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f°C", value)
    }

    static func decimal(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        let s = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        return "\(s) \(suffix)"
    }
}
