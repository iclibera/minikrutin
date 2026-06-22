import SwiftUI

/// One-line summary of any log entry. Reused on Today and History.
struct EntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.16)).frame(width: 38, height: 38)
                Image(systemName: entry.type.icon).font(.footnote.weight(.bold)).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                if let detail { Text(detail).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(1) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.time(entry.date)).font(.caption.weight(.medium)).foregroundStyle(Theme.ink)
                Text(Fmt.relativeDay(entry.date)).font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var tint: Color {
        switch entry.type {
        case .feeding: return Theme.brand
        case .sleep: return Color(hex: 0x6C7BD1)
        case .diaper: return Color(hex: 0xCFA15A)
        case .medicine: return Theme.danger
        case .pumping: return Color(hex: 0x4FA3C7)
        case .note: return Color(hex: 0x8E8E93)
        case .growth: return Theme.brandDark
        case .vaccine: return Color(hex: 0xC75AA0)
        }
    }

    private var title: String { entry.type.title }

    private var detail: String? {
        switch entry.type {
        case .feeding:
            let t = entry.feedingType?.label ?? "Beslenme"
            if let ml = entry.amountML { return "\(t) • \(Fmt.ml(ml))" }
            if let d = entry.durationMin { return "\(t) • \(Fmt.duration(minutes: d))" }
            return t
        case .sleep:
            return entry.endDate == nil ? "Uyuyor" : Fmt.duration(minutes: entry.sleepMinutes)
        case .diaper:
            return entry.diaperKind?.label
        case .medicine:
            var parts: [String] = []
            if let m = entry.medName, !m.isEmpty { parts.append(m) }
            if let d = entry.dose, !d.isEmpty { parts.append(d) }
            if let t = entry.temperatureC { parts.append(Fmt.temp(t)) }
            return parts.joined(separator: " • ")
        case .pumping:
            return Fmt.ml(entry.amountML)
        case .note:
            let tags = entry.tags.isEmpty ? "" : " [\(entry.tags.joined(separator: ", "))]"
            return (entry.text ?? "") + tags
        case .growth:
            var parts: [String] = []
            if let w = entry.weightKg { parts.append(Fmt.decimal(w, suffix: "kg")) }
            if let h = entry.heightCm { parts.append(Fmt.decimal(h, suffix: "cm")) }
            return parts.joined(separator: " • ")
        case .vaccine:
            let status = entry.vaccineDone ? "Yapıldı" : "Planlandı"
            return "\(entry.vaccineName ?? "") • \(status)"
        }
    }
}
