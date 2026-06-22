import SwiftUI
import SwiftData

struct TodayView: View {
    let baby: Baby
    let openLog: (QuickLogTarget) -> Void

    @EnvironmentObject var env: AppEnvironment
    @Query private var entries: [LogEntry]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query private var reminders: [ReminderItem]

    init(baby: Baby, openLog: @escaping (QuickLogTarget) -> Void) {
        self.baby = baby
        self.openLog = openLog
        let id = baby.id
        _entries = Query(filter: #Predicate<LogEntry> { $0.babyID == id && !$0.deleted },
                         sort: \.date, order: .reverse)
        _reminders = Query(filter: #Predicate<ReminderItem> { $0.babyID == id && $0.enabled },
                           sort: \.hour)
    }

    private var lastFeeding: LogEntry? { Insights.last(entries, type: .feeding) }
    private var lastDiaper: LogEntry? { Insights.last(entries, type: .diaper) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                babyCard
                statGrid
                addButton
                quickIcons
                reminderCard
                recentSection
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Bugün")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { babySwitcher }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { HistoryView(baby: baby) } label: { Image(systemName: "list.bullet.rectangle") }
            }
        }
    }

    // MARK: Sections

    private var babyCard: some View {
        HStack(spacing: 14) {
            BabyAvatar(baby: baby, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(baby.name).font(.title3.bold()).foregroundStyle(Theme.ink)
                Text(Fmt.age(from: baby.birthDate)).font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.peach)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var statGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatTile(label: "Son beslenme",
                     value: lastFeeding.map { Fmt.elapsed(since: $0.date) } ?? "—",
                     tint: Theme.mint, icon: "drop.fill")
            StatTile(label: "Son bez",
                     value: lastDiaper.map { Fmt.elapsed(since: $0.date) } ?? "—",
                     tint: Theme.sky, icon: "leaf.fill")
            StatTile(label: "Bugünkü uyku",
                     value: Fmt.duration(minutes: Insights.todaySleepMinutes(entries)),
                     tint: Theme.lilac, icon: "moon.stars.fill")
            StatTile(label: "Mama toplamı",
                     value: Fmt.ml(Insights.todayFeedingML(entries)),
                     tint: Theme.cream, icon: "chart.bar.fill")
        }
    }

    private var addButton: some View {
        PrimaryButton(title: "Hızlı kayıt ekle", systemImage: "plus") { openLog(.menu) }
    }

    private var quickIcons: some View {
        HStack(spacing: 10) {
            quickIcon("Beslenme", "drop.fill", Theme.brand) { openLog(.feeding) }
            quickIcon("Uyku", "moon.stars.fill", Color(hex: 0x6C7BD1)) { openLog(.sleep) }
            quickIcon("Bez", "leaf.fill", Color(hex: 0xCFA15A)) { openLog(.diaper) }
            quickIcon("İlaç", "cross.case.fill", Theme.danger) { openLog(.medicine) }
        }
    }

    private func quickIcon(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(tint.opacity(0.16)).frame(width: 48, height: 48)
                    Image(systemName: icon).foregroundStyle(tint).font(.system(size: 18, weight: .semibold))
                }
                Text(title).font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var reminderCard: some View {
        if let next = nextReminder {
            HStack(spacing: 12) {
                Image(systemName: next.kind.icon).foregroundStyle(Theme.brandDark)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sıradaki hatırlatma").font(.caption).foregroundStyle(Theme.inkSecondary)
                    Text("\(next.title) • \(next.timeLabel)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.brandSoft)
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Son kayıtlar")
                Spacer()
                NavigationLink("Tümü") { HistoryView(baby: baby) }
                    .font(.caption.weight(.semibold))
            }
            if entries.isEmpty {
                Card { EmptyHint(icon: "tray", title: "Henüz kayıt yok", message: "Hızlı kayıt ekleyerek bugünü takip etmeye başlayın.") }
            } else {
                Card(padding: 8) {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.prefix(6))) { entry in
                            NavigationLink { EntryDetailView(baby: baby, entry: entry) } label: {
                                EntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            if entry.id != entries.prefix(6).last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }

    private var babySwitcher: some View {
        Menu {
            ForEach(babies) { b in
                Button {
                    env.selectedBabyID = b.id
                } label: {
                    Label(b.name, systemImage: b.id == baby.id ? "checkmark" : "person.crop.circle")
                }
            }
            Divider()
            NavigationLink { AddBabyView(isOnboarding: false) } label: { Label("Bebek ekle", systemImage: "plus") }
        } label: {
            HStack(spacing: 4) {
                Text(baby.name).font(.headline)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(Theme.ink)
        }
    }

    private var nextReminder: ReminderItem? {
        let now = Fmt.calendar.dateComponents([.hour, .minute], from: Date())
        let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let upcoming = reminders.filter { $0.hour * 60 + $0.minute >= nowMin }
        return (upcoming.first) ?? reminders.first
    }
}

/// Round baby avatar showing the photo or a coloured initial.
struct BabyAvatar: View {
    let baby: Baby
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let image = ImageStore.load(baby.photoFileName) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.blush
                    Text(String(baby.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
