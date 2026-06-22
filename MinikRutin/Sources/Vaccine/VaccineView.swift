import SwiftUI
import SwiftData

struct VaccineView: View {
    let baby: Baby
    @Query private var vaccines: [LogEntry]
    @State private var adding = false

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _vaccines = Query(filter: #Predicate<LogEntry> { $0.babyID == id && $0.typeRaw == "vaccine" && !$0.deleted },
                          sort: \.date, order: .forward)
    }

    private var planned: [LogEntry] { vaccines.filter { !$0.vaccineDone }.sorted { $0.date < $1.date } }
    private var done: [LogEntry] { vaccines.filter { $0.vaccineDone }.sorted { $0.date > $1.date } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Aşı takvimi ve ilaç kullanımı için doktorunuza/sağlık profesyonelinize danışın.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)

                if vaccines.isEmpty {
                    Card { EmptyHint(icon: "syringe", title: "Kayıt yok", message: "Aşı ve doktor kontrollerini ekleyin.") }
                }
                if !planned.isEmpty { group("Planlanan", planned) }
                if !done.isEmpty { group("Yapılan", done) }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Aşı & kontroller")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $adding) {
            NavigationStack { VaccineFormView(baby: baby, onClose: { adding = false }) }
        }
    }

    private func group(_ title: String, _ items: [LogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            Card(padding: 8) {
                VStack(spacing: 0) {
                    ForEach(items) { e in
                        NavigationLink { EntryDetailView(baby: baby, entry: e) } label: { EntryRow(entry: e) }
                            .buttonStyle(.plain)
                        if e.id != items.last?.id { Divider() }
                    }
                }
            }
        }
    }
}

struct VaccineFormView: View {
    let baby: Baby
    var existing: LogEntry? = nil
    let onClose: () -> Void
    @EnvironmentObject var env: AppEnvironment

    @State private var name = ""
    @State private var date = Date()
    @State private var done = false
    @State private var note = ""

    var body: some View {
        Form {
            Section("Aşı / kontrol") {
                TextField("Örn. 2. ay aşıları", text: $name)
            }
            Section("Tarih ve durum") {
                DatePicker("Tarih", selection: $date, displayedComponents: .date)
                Toggle("Yapıldı", isOn: $done)
            }
            Section("Not (isteğe bağlı)") {
                TextField("Not", text: $note, axis: .vertical)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Aşı / kontrol")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Kaydet", systemImage: "checkmark", enabled: !name.isEmpty, action: save)
                .padding(16).background(.ultraThinMaterial)
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let e = existing else { return }
        name = e.vaccineName ?? ""; date = e.date; done = e.vaccineDone; note = e.text ?? ""
    }

    private func save() {
        let entry = existing ?? LogEntry(babyID: baby.id, type: .vaccine)
        entry.type = .vaccine
        entry.vaccineName = name
        entry.vaccineDone = done
        entry.text = note.isEmpty ? nil : note
        entry.date = date
        if existing == nil { env.add(entry) } else { env.touch(entry) }
        onClose()
    }
}
