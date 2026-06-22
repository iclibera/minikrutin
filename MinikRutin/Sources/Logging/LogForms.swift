import SwiftUI

// MARK: - Shared form scaffolding

private struct SaveBar: View {
    var enabled: Bool = true
    let action: () -> Void
    var body: some View {
        PrimaryButton(title: "Kaydet", systemImage: "checkmark", enabled: enabled, action: action)
            .padding(16)
            .background(.ultraThinMaterial)
    }
}

private func parseDouble(_ s: String) -> Double? {
    let cleaned = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
    guard !cleaned.isEmpty, let v = Double(cleaned) else { return nil }
    return v
}

// MARK: - Feeding

struct FeedingFormView: View {
    let baby: Baby
    var existing: LogEntry? = nil
    let onClose: () -> Void
    @EnvironmentObject var env: AppEnvironment

    @State private var type: FeedingType = .formula
    @State private var amount = ""
    @State private var duration = ""
    @State private var side: NursingSide = .both
    @State private var date = Date()

    var body: some View {
        Form {
            Section("Beslenme türü") {
                Picker("Tür", selection: $type) {
                    ForEach(FeedingType.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            if type == .nursing {
                Section("Süre ve taraf") {
                    HStack {
                        TextField("Dakika", text: $duration).keyboardType(.numberPad)
                        Text("dk").foregroundStyle(Theme.inkSecondary)
                    }
                    Picker("Taraf", selection: $side) {
                        ForEach(NursingSide.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                }
            } else {
                Section("Miktar") {
                    HStack {
                        TextField("120", text: $amount).keyboardType(.decimalPad).font(.title3.bold())
                        Text("ml").foregroundStyle(Theme.inkSecondary)
                    }
                    HStack(spacing: 8) {
                        ForEach([60, 90, 120, 150], id: \.self) { v in
                            Button("\(v)") { amount = "\(v)" }
                                .buttonStyle(.bordered).tint(Theme.brand)
                        }
                    }
                }
            }
            Section("Saat") {
                DatePicker("Zaman", selection: $date)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Beslenme")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { SaveBar(action: save) }
        .onAppear(perform: load)
    }

    private func load() {
        guard let e = existing else { return }
        type = e.feedingType ?? .formula
        amount = e.amountML.map { String(Int($0)) } ?? ""
        duration = e.durationMin.map { String(Int($0)) } ?? ""
        side = e.side ?? .both
        date = e.date
    }

    private func save() {
        let entry = existing ?? LogEntry(babyID: baby.id, type: .feeding)
        entry.type = .feeding
        entry.feedingType = type
        entry.date = date
        if type == .nursing {
            entry.durationMin = parseDouble(duration)
            entry.side = side
            entry.amountML = nil
        } else {
            entry.amountML = parseDouble(amount)
            entry.durationMin = nil
            entry.side = nil
        }
        if existing == nil { env.add(entry) } else { env.touch(entry) }
        onClose()
    }
}

// MARK: - Sleep

struct SleepFormView: View {
    let baby: Baby
    var existing: LogEntry? = nil
    let onClose: () -> Void
    @EnvironmentObject var env: AppEnvironment

    @State private var start = Date().addingTimeInterval(-3600)
    @State private var ongoing = false
    @State private var end = Date()

    var body: some View {
        Form {
            Section("Başlangıç") { DatePicker("Uyudu", selection: $start) }
            Section {
                Toggle("Şu an uyuyor", isOn: $ongoing.animation())
                if !ongoing { DatePicker("Uyandı", selection: $end, in: start...) }
            }
            if !ongoing {
                Section {
                    LabeledContent("Süre", value: Fmt.duration(minutes: max(0, end.timeIntervalSince(start) / 60)))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Uyku")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { SaveBar(action: save) }
        .onAppear(perform: load)
    }

    private func load() {
        guard let e = existing else { return }
        start = e.date
        if let endDate = e.endDate { end = endDate; ongoing = false } else { ongoing = true }
    }

    private func save() {
        let entry = existing ?? LogEntry(babyID: baby.id, type: .sleep)
        entry.type = .sleep
        entry.date = start
        entry.endDate = ongoing ? nil : end
        if existing == nil { env.add(entry) } else { env.touch(entry) }
        onClose()
    }
}

// MARK: - Diaper

struct DiaperFormView: View {
    let baby: Baby
    var existing: LogEntry? = nil
    let onClose: () -> Void
    @EnvironmentObject var env: AppEnvironment

    @State private var kind: DiaperKind = .wet
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        Form {
            Section("Bez türü") {
                Picker("Tür", selection: $kind) {
                    ForEach(DiaperKind.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
            }
            Section("Saat") { DatePicker("Zaman", selection: $date) }
            Section("Not (isteğe bağlı)") {
                TextField("Renk, kıvam vb.", text: $note, axis: .vertical)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Bez")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { SaveBar(action: save) }
        .onAppear(perform: load)
    }

    private func load() {
        guard let e = existing else { return }
        kind = e.diaperKind ?? .wet; date = e.date; note = e.text ?? ""
    }

    private func save() {
        let entry = existing ?? LogEntry(babyID: baby.id, type: .diaper)
        entry.type = .diaper
        entry.diaperKind = kind
        entry.date = date
        entry.text = note.isEmpty ? nil : note
        if existing == nil { env.add(entry) } else { env.touch(entry) }
        onClose()
    }
}

// MARK: - Medicine & fever

struct MedicineFormView: View {
    let baby: Baby
    var existing: LogEntry? = nil
    let onClose: () -> Void
    @EnvironmentObject var env: AppEnvironment

    @State private var medName = ""
    @State private var dose = ""
    @State private var hasFever = false
    @State private var temperature = 37.5
    @State private var date = Date()

    var body: some View {
        Form {
            Section("İlaç") {
                TextField("İlaç adı (örn. D vitamini)", text: $medName)
                TextField("Doz (örn. 3 damla / 2.5 ml)", text: $dose)
            }
            Section("Ateş") {
                Toggle("Ateş ölçüldü", isOn: $hasFever.animation())
                if hasFever {
                    Stepper(value: $temperature, in: 34...43, step: 0.1) {
                        Text(Fmt.temp(temperature))
                    }
                }
            }
            Section("Saat") { DatePicker("Zaman", selection: $date) }
            Section {
                Text("Bu uygulama tıbbi teşhis veya tedavi önerisi vermez. İlaç ve doz için doktorunuza danışın.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("İlaç & ateş")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { SaveBar(enabled: !medName.isEmpty || hasFever, action: save) }
        .onAppear(perform: load)
    }

    private func load() {
        guard let e = existing else { return }
        medName = e.medName ?? ""; dose = e.dose ?? ""; date = e.date
        if let t = e.temperatureC { hasFever = true; temperature = t }
    }

    private func save() {
        let entry = existing ?? LogEntry(babyID: baby.id, type: .medicine)
        entry.type = .medicine
        entry.medName = medName.isEmpty ? nil : medName
        entry.dose = dose.isEmpty ? nil : dose
        entry.temperatureC = hasFever ? temperature : nil
        entry.date = date
        if existing == nil { env.add(entry) } else { env.touch(entry) }
        onClose()
    }
}

// MARK: - Pumping

struct PumpingFormView: View {
    let baby: Baby
    var existing: LogEntry? = nil
    let onClose: () -> Void
    @EnvironmentObject var env: AppEnvironment

    @State private var amount = ""
    @State private var duration = ""
    @State private var side: NursingSide = .both
    @State private var date = Date()

    var body: some View {
        Form {
            Section("Miktar") {
                HStack {
                    TextField("90", text: $amount).keyboardType(.decimalPad).font(.title3.bold())
                    Text("ml").foregroundStyle(Theme.inkSecondary)
                }
            }
            Section("Süre ve taraf") {
                HStack {
                    TextField("Dakika", text: $duration).keyboardType(.numberPad)
                    Text("dk").foregroundStyle(Theme.inkSecondary)
                }
                Picker("Taraf", selection: $side) {
                    ForEach(NursingSide.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented)
            }
            Section("Saat") { DatePicker("Zaman", selection: $date) }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Süt sağma")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { SaveBar(action: save) }
        .onAppear(perform: load)
    }

    private func load() {
        guard let e = existing else { return }
        amount = e.amountML.map { String(Int($0)) } ?? ""
        duration = e.durationMin.map { String(Int($0)) } ?? ""
        side = e.side ?? .both; date = e.date
    }

    private func save() {
        let entry = existing ?? LogEntry(babyID: baby.id, type: .pumping)
        entry.type = .pumping
        entry.amountML = parseDouble(amount)
        entry.durationMin = parseDouble(duration)
        entry.side = side
        entry.date = date
        if existing == nil { env.add(entry) } else { env.touch(entry) }
        onClose()
    }
}

// MARK: - Note

struct NoteFormView: View {
    let baby: Baby
    var existing: LogEntry? = nil
    let onClose: () -> Void
    @EnvironmentObject var env: AppEnvironment

    private let allTags = ["kusma", "gaz", "huzursuzluk", "ateş", "ishal", "döküntü"]
    @State private var text = ""
    @State private var selectedTags: Set<String> = []
    @State private var date = Date()

    var body: some View {
        Form {
            Section("Not") {
                TextField("Bugün neler oldu?", text: $text, axis: .vertical)
                    .lineLimit(3...8)
            }
            Section("Etiketler") {
                FlowTags(all: allTags, selected: $selectedTags)
            }
            Section("Saat") { DatePicker("Zaman", selection: $date) }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Not")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { SaveBar(enabled: !text.isEmpty || !selectedTags.isEmpty, action: save) }
        .onAppear(perform: load)
    }

    private func load() {
        guard let e = existing else { return }
        text = e.text ?? ""; selectedTags = Set(e.tags); date = e.date
    }

    private func save() {
        let entry = existing ?? LogEntry(babyID: baby.id, type: .note)
        entry.type = .note
        entry.text = text.isEmpty ? nil : text
        entry.tags = Array(selectedTags)
        entry.date = date
        if existing == nil { env.add(entry) } else { env.touch(entry) }
        onClose()
    }
}

/// Simple wrapping tag selector.
struct FlowTags: View {
    let all: [String]
    @Binding var selected: Set<String>

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(all, id: \.self) { tag in
                let on = selected.contains(tag)
                Button {
                    if on { selected.remove(tag) } else { selected.insert(tag) }
                } label: {
                    Text(tag)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(on ? .white : Theme.ink)
                        .background(on ? Theme.brand : Theme.surfaceAlt)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
