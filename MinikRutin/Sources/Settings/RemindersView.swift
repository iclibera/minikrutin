import SwiftUI
import SwiftData

struct RemindersView: View {
    let baby: Baby
    @EnvironmentObject var env: AppEnvironment
    @Query private var reminders: [ReminderItem]
    @State private var adding = false

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _reminders = Query(filter: #Predicate<ReminderItem> { $0.babyID == id }, sort: \.hour)
    }

    var body: some View {
        List {
            Section {
                Text("Beslenme, D vitamini, ilaç ve doktor kontrolleri için hatırlatma kurun. Tıbbi kararlar için doktorunuza danışın.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            ForEach(reminders) { reminder in
                HStack {
                    Image(systemName: reminder.kind.icon).foregroundStyle(Theme.brandDark).frame(width: 28)
                    VStack(alignment: .leading) {
                        Text(reminder.title).foregroundStyle(Theme.ink)
                        Text("\(reminder.timeLabel)\(reminder.repeatsDaily ? " • her gün" : "")")
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { reminder.enabled },
                        set: { newValue in
                            reminder.enabled = newValue
                            env.save()
                            Task {
                                if newValue { _ = await env.notifications.requestAuthorization() }
                                env.notifications.sync(reminder)
                            }
                        }))
                    .labelsHidden()
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Hatırlatmalar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $adding) { NavigationStack { ReminderFormView(baby: baby) { adding = false } } }
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets {
            let r = reminders[i]
            env.notifications.cancel(r.id)
            env.modelContext.delete(r)
        }
        env.save()
    }
}

struct ReminderFormView: View {
    let baby: Baby
    let onClose: () -> Void
    @EnvironmentObject var env: AppEnvironment

    @State private var kind: ReminderKind = .vitaminD
    @State private var title = "D vitamini"
    @State private var time = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var repeatsDaily = true

    var body: some View {
        Form {
            Section("Tür") {
                Picker("Tür", selection: $kind) {
                    ForEach(ReminderKind.allCases) { Text($0.label).tag($0) }
                }
                .onChange(of: kind) { _, new in if new != .custom { title = new.label } }
            }
            Section("Başlık") { TextField("Başlık", text: $title) }
            Section("Zaman") {
                DatePicker("Saat", selection: $time, displayedComponents: .hourAndMinute)
                Toggle("Her gün tekrarla", isOn: $repeatsDaily)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Hatırlatma")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Kaydet", enabled: !title.isEmpty, action: save).padding(16).background(.ultraThinMaterial)
        }
    }

    private func save() {
        let comps = Fmt.calendar.dateComponents([.hour, .minute], from: time)
        let reminder = ReminderItem(babyID: baby.id, title: title, kind: kind,
                                    hour: comps.hour ?? 20, minute: comps.minute ?? 0, repeatsDaily: repeatsDaily)
        env.modelContext.insert(reminder)
        env.save()
        Task {
            if await env.notifications.requestAuthorization() { env.notifications.sync(reminder) }
        }
        onClose()
    }
}
