import SwiftUI
import SwiftData

struct GrowthHubView: View {
    let baby: Baby
    @Query private var growth: [LogEntry]

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _growth = Query(filter: #Predicate<LogEntry> { $0.babyID == id && $0.typeRaw == "growth" && !$0.deleted },
                        sort: \.date, order: .reverse)
    }

    private var latest: LogEntry? { growth.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card(background: Theme.mint) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Son ölçüm").font(.caption).foregroundStyle(Theme.inkSecondary)
                        if let g = latest {
                            HStack(spacing: 18) {
                                measure("Kilo", Fmt.decimal(g.weightKg, suffix: "kg"))
                                measure("Boy", Fmt.decimal(g.heightCm, suffix: "cm"))
                                measure("Baş", Fmt.decimal(g.headCm, suffix: "cm"))
                            }
                        } else {
                            Text("Henüz ölçüm eklenmedi.").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }

                NavigationLink { GrowthView(baby: baby) } label: {
                    QuickActionRow(title: "Büyüme takibi", subtitle: "Kilo, boy ve baş çevresi", icon: "ruler.fill", tint: Theme.brandDark)
                }
                NavigationLink { VaccineView(baby: baby) } label: {
                    QuickActionRow(title: "Aşı & kontroller", subtitle: "Aşı takvimi ve doktor kontrolleri", icon: "syringe.fill", tint: Color(hex: 0xC75AA0))
                }
                NavigationLink { MemoriesView(baby: baby) } label: {
                    QuickActionRow(title: "Anılar", subtitle: "Fotoğraflı gelişim anıları", icon: "photo.on.rectangle.angled", tint: Color(hex: 0x4FA3C7))
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Gelişim & Sağlık")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func measure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).foregroundStyle(Theme.ink)
            Text(label).font(.caption2).foregroundStyle(Theme.inkSecondary)
        }
    }
}
