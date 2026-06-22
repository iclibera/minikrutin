import SwiftUI
import SwiftData
import Charts

struct WeeklySummaryView: View {
    let baby: Baby
    @EnvironmentObject var subscriptions: SubscriptionStore
    @Query private var entries: [LogEntry]
    @State private var showPaywall = false

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _entries = Query(filter: #Predicate<LogEntry> { $0.babyID == id && !$0.deleted },
                         sort: \.date, order: .reverse)
    }

    private var feedingCounts: [(day: Date, count: Int)] { Insights.dailyCounts(entries, type: .feeding) }
    private var sleepDaily: [(day: Date, minutes: Double)] { Insights.dailySleepMinutes(entries) }
    private var feedingML: [(day: Date, ml: Double)] { Insights.dailyFeedingML(entries) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bu haftanın özeti").font(.headline).foregroundStyle(Theme.ink)
                        Chart(feedingCounts, id: \.day) { item in
                            BarMark(
                                x: .value("Gün", Fmt.weekdayShort(item.day)),
                                y: .value("Beslenme", item.count)
                            )
                            .foregroundStyle(Theme.brand.gradient)
                            .cornerRadius(6)
                        }
                        .frame(height: 170)
                        .chartYAxis { AxisMarks(position: .leading) }
                        Text("Beslenme sayısı (kez/gün)").font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }

                statRow("Ortalama uyku", Fmt.duration(minutes: Insights.avgSleepMinutesPerDay(entries)), "moon.stars.fill")
                statRow("Beslenme", "\(String(format: "%.0f", Insights.avgFeedingsPerDay(entries))) kez/gün", "drop.fill")
                statRow("Bez", "\(String(format: "%.0f", Insights.avgDiapersPerDay(entries))) kez/gün", "leaf.fill")

                advancedSection
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Haftalık özet")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func statRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Theme.brandDark).frame(width: 28)
            Text(title).foregroundStyle(Theme.inkSecondary)
            Spacer()
            Text(value).font(.headline).foregroundStyle(Theme.ink)
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
    }

    @ViewBuilder private var advancedSection: some View {
        HStack {
            SectionLabel(text: "Gelişmiş grafikler ve trend analizi")
            Spacer()
            if !subscriptions.isSubscribed { PremiumBadge() }
        }
        if subscriptions.isSubscribed {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Uyku trendi (dk/gün)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Chart(sleepDaily, id: \.day) { item in
                        LineMark(x: .value("Gün", Fmt.weekdayShort(item.day)),
                                 y: .value("Dakika", item.minutes))
                        .foregroundStyle(Color(hex: 0x6C7BD1))
                        AreaMark(x: .value("Gün", Fmt.weekdayShort(item.day)),
                                 y: .value("Dakika", item.minutes))
                        .foregroundStyle(Color(hex: 0x6C7BD1).opacity(0.15))
                    }
                    .frame(height: 150)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mama/süt trendi (ml/gün)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    Chart(feedingML, id: \.day) { item in
                        BarMark(x: .value("Gün", Fmt.weekdayShort(item.day)),
                                y: .value("ml", item.ml))
                        .foregroundStyle(Theme.brandDark.gradient)
                        .cornerRadius(5)
                    }
                    .frame(height: 150)
                }
            }
        } else {
            Button { showPaywall = true } label: {
                Card(background: Theme.brandSoft) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill").foregroundStyle(Theme.brand)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Premium ile detaylı grafikler").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Text("Uyku ve beslenme trendlerini görün.").font(.caption).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
