import SwiftUI
import SwiftData

struct HistoryView: View {
    let baby: Baby
    @Query private var entries: [LogEntry]
    @State private var filter: EntryType?

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _entries = Query(filter: #Predicate<LogEntry> { $0.babyID == id && !$0.deleted },
                         sort: \.date, order: .reverse)
    }

    private var filtered: [LogEntry] {
        guard let filter else { return entries }
        return entries.filter { $0.type == filter }
    }

    private var grouped: [(day: Date, items: [LogEntry])] {
        let cal = Fmt.calendar
        let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filterChips
                if filtered.isEmpty {
                    Card { EmptyHint(icon: "tray", title: "Kayıt yok", message: "Bu filtre için kayıt bulunmuyor.") }
                } else {
                    ForEach(grouped, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: Fmt.relativeDay(group.day))
                            Card(padding: 8) {
                                VStack(spacing: 0) {
                                    ForEach(group.items) { entry in
                                        NavigationLink { EntryDetailView(baby: baby, entry: entry) } label: {
                                            EntryRow(entry: entry)
                                        }
                                        .buttonStyle(.plain)
                                        if entry.id != group.items.last?.id { Divider() }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Tüm kayıtlar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Tümü", active: filter == nil) { filter = nil }
                ForEach(EntryType.allCases) { t in
                    chip(t.title, active: filter == t) { filter = t }
                }
            }
        }
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(active ? .white : Theme.ink)
                .background(active ? Theme.brand : Theme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Entry detail + edit

struct EntryDetailView: View {
    let baby: Baby
    let entry: LogEntry
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: entry.type.icon).font(.title3).foregroundStyle(Theme.brand)
                            Text(entry.type.title).font(.title3.bold()).foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        Divider()
                        ForEach(detailRows, id: \.0) { row in
                            HStack {
                                Text(row.0).foregroundStyle(Theme.inkSecondary)
                                Spacer()
                                Text(row.1).foregroundStyle(Theme.ink).fontWeight(.medium)
                            }
                            .font(.subheadline)
                        }
                    }
                }
                SecondaryButton(title: "Düzenle", systemImage: "pencil") { editing = true }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Sil", systemImage: "trash").frame(maxWidth: .infinity).frame(height: 50)
                }
                .background(Theme.danger.opacity(0.1)).foregroundStyle(Theme.danger)
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(Fmt.relativeDay(entry.date))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) {
            NavigationStack { editForm }
        }
        .alert("Kaydı sil", isPresented: $confirmDelete) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sil", role: .destructive) { env.delete(entry); dismiss() }
        } message: { Text("Bu kayıt silinsin mi?") }
    }

    @ViewBuilder private var editForm: some View {
        switch entry.type {
        case .feeding: FeedingFormView(baby: baby, existing: entry, onClose: { editing = false })
        case .sleep: SleepFormView(baby: baby, existing: entry, onClose: { editing = false })
        case .diaper: DiaperFormView(baby: baby, existing: entry, onClose: { editing = false })
        case .medicine: MedicineFormView(baby: baby, existing: entry, onClose: { editing = false })
        case .pumping: PumpingFormView(baby: baby, existing: entry, onClose: { editing = false })
        case .note: NoteFormView(baby: baby, existing: entry, onClose: { editing = false })
        case .growth: GrowthFormView(baby: baby, existing: entry, onClose: { editing = false })
        case .vaccine: VaccineFormView(baby: baby, existing: entry, onClose: { editing = false })
        }
    }

    private var detailRows: [(String, String)] {
        var rows: [(String, String)] = [("Saat", Fmt.time(entry.date)), ("Tarih", Fmt.dayMonthYear(entry.date))]
        switch entry.type {
        case .feeding:
            if let t = entry.feedingType { rows.append(("Tür", t.label)) }
            if let ml = entry.amountML { rows.append(("Miktar", Fmt.ml(ml))) }
            if let d = entry.durationMin { rows.append(("Süre", Fmt.duration(minutes: d))) }
            if let s = entry.side { rows.append(("Taraf", s.label)) }
        case .sleep:
            rows.append(("Süre", entry.endDate == nil ? "Devam ediyor" : Fmt.duration(minutes: entry.sleepMinutes)))
        case .diaper:
            if let k = entry.diaperKind { rows.append(("Tür", k.label)) }
        case .medicine:
            if let m = entry.medName { rows.append(("İlaç", m)) }
            if let d = entry.dose { rows.append(("Doz", d)) }
            if let t = entry.temperatureC { rows.append(("Ateş", Fmt.temp(t))) }
        case .pumping:
            if let ml = entry.amountML { rows.append(("Miktar", Fmt.ml(ml))) }
            if let d = entry.durationMin { rows.append(("Süre", Fmt.duration(minutes: d))) }
        case .growth:
            if let w = entry.weightKg { rows.append(("Kilo", Fmt.decimal(w, suffix: "kg"))) }
            if let h = entry.heightCm { rows.append(("Boy", Fmt.decimal(h, suffix: "cm"))) }
            if let hc = entry.headCm { rows.append(("Baş çevresi", Fmt.decimal(hc, suffix: "cm"))) }
        case .vaccine:
            if let v = entry.vaccineName { rows.append(("Aşı / kontrol", v)) }
            rows.append(("Durum", entry.vaccineDone ? "Yapıldı" : "Planlandı"))
        case .note:
            break
        }
        if let text = entry.text, !text.isEmpty { rows.append(("Not", text)) }
        if !entry.tags.isEmpty { rows.append(("Etiketler", entry.tags.joined(separator: ", "))) }
        return rows
    }
}
