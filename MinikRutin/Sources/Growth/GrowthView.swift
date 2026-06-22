import SwiftUI
import SwiftData
import Charts

struct GrowthView: View {
    let baby: Baby
    @Query private var growth: [LogEntry]
    @State private var adding = false

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _growth = Query(filter: #Predicate<LogEntry> { $0.babyID == id && $0.typeRaw == "growth" && !$0.deleted },
                        sort: \.date, order: .forward)
    }

    private var weightSeries: [LogEntry] { growth.filter { $0.weightKg != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if weightSeries.count >= 2 {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kilo gelişimi (kg)").font(.headline).foregroundStyle(Theme.ink)
                            Chart(weightSeries) { e in
                                LineMark(x: .value("Tarih", e.date), y: .value("Kilo", e.weightKg ?? 0))
                                    .foregroundStyle(Theme.brand)
                                PointMark(x: .value("Tarih", e.date), y: .value("Kilo", e.weightKg ?? 0))
                                    .foregroundStyle(Theme.brand)
                            }
                            .frame(height: 160)
                        }
                    }
                }

                if growth.isEmpty {
                    Card { EmptyHint(icon: "ruler", title: "Ölçüm yok", message: "Kilo, boy ve baş çevresi ölçümlerini ekleyin.") }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Ölçümler")
                        Card(padding: 8) {
                            VStack(spacing: 0) {
                                ForEach(growth.reversed()) { e in
                                    NavigationLink { EntryDetailView(baby: baby, entry: e) } label: { EntryRow(entry: e) }
                                        .buttonStyle(.plain)
                                    if e.id != growth.first?.id { Divider() }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Büyüme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $adding) {
            NavigationStack { GrowthFormView(baby: baby, onClose: { adding = false }) }
        }
    }
}

struct GrowthFormView: View {
    let baby: Baby
    var existing: LogEntry? = nil
    let onClose: () -> Void
    @EnvironmentObject var env: AppEnvironment

    @State private var weight = ""
    @State private var height = ""
    @State private var head = ""
    @State private var date = Date()

    var body: some View {
        Form {
            Section("Ölçümler") {
                field("Kilo", "kg", $weight)
                field("Boy", "cm", $height)
                field("Baş çevresi", "cm", $head)
            }
            Section("Tarih") {
                DatePicker("Tarih", selection: $date, in: ...Date(), displayedComponents: .date)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Büyüme ölçümü")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Kaydet", systemImage: "checkmark",
                          enabled: !weight.isEmpty || !height.isEmpty || !head.isEmpty, action: save)
                .padding(16).background(.ultraThinMaterial)
        }
        .onAppear(perform: load)
    }

    private func field(_ title: String, _ unit: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: binding).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
            Text(unit).foregroundStyle(Theme.inkSecondary)
        }
    }

    private func load() {
        guard let e = existing else { return }
        weight = e.weightKg.map { String($0) } ?? ""
        height = e.heightCm.map { String($0) } ?? ""
        head = e.headCm.map { String($0) } ?? ""
        date = e.date
    }

    private func save() {
        let entry = existing ?? LogEntry(babyID: baby.id, type: .growth)
        entry.type = .growth
        entry.weightKg = Double(weight.replacingOccurrences(of: ",", with: "."))
        entry.heightCm = Double(height.replacingOccurrences(of: ",", with: "."))
        entry.headCm = Double(head.replacingOccurrences(of: ",", with: "."))
        entry.date = date
        if existing == nil { env.add(entry) } else { env.touch(entry) }
        onClose()
    }
}
