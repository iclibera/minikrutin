import SwiftUI
import SwiftData

struct DoctorReportView: View {
    let baby: Baby
    @EnvironmentObject var subscriptions: SubscriptionStore
    @Query private var entries: [LogEntry]

    @State private var days = 7
    @State private var pdfURL: URL?
    @State private var showPaywall = false

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _entries = Query(filter: #Predicate<LogEntry> { $0.babyID == id && !$0.deleted },
                         sort: \.date, order: .reverse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                rangePicker

                Card(background: Theme.brandSoft) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Doktor Raporu").font(.title3.bold()).foregroundStyle(Theme.ink)
                        Text("Son \(days) günün özeti hazır").font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                }

                summaryRows

                if let url = pdfURL, subscriptions.isSubscribed {
                    ShareLink(item: url) {
                        Text("PDF olarak paylaş")
                            .fontWeight(.semibold).frame(maxWidth: .infinity).frame(height: 54)
                            .foregroundStyle(.white).background(Theme.brand)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
                    }
                } else {
                    PrimaryButton(title: "PDF olarak paylaş", systemImage: "square.and.arrow.up") {
                        showPaywall = true
                    }
                    if !subscriptions.isSubscribed {
                        Label("PDF dışa aktarma Premium özelliğidir", systemImage: "crown.fill")
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                Text("Bu rapor bilgilendirme amaçlıdır, tıbbi teşhis veya tedavi önerisi değildir. Kararlar için doktorunuza danışın.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Doktor raporu")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear(perform: regenerate)
        .onChange(of: days) { _, _ in regenerate() }
    }

    private var rangePicker: some View {
        Picker("Aralık", selection: $days) {
            Text("Son 7 gün").tag(7)
            Text("Son 14 gün").tag(14)
            Text("Son 30 gün").tag(30)
        }.pickerStyle(.segmented)
    }

    private var summaryRows: some View {
        let fevers = Insights.feverEntries(entries, days: days)
        let feverText = fevers.isEmpty ? "Yok" : "\(fevers.count) kez"
        let notes = Insights.noteEntries(entries, days: days).filter { ($0.text?.isEmpty == false) }
        let notesText = notes.isEmpty ? "Kayıt yok" : "\(notes.count) not"
        return Card(padding: 8) {
            VStack(spacing: 0) {
                reportRow("Günlük ortalama beslenme", String(format: "%.0f kez", Insights.avgFeedingsPerDay(entries, days: days)))
                Divider()
                reportRow("Toplam mama/süt", Fmt.ml(Insights.totalFeedingML(entries, days: days)))
                Divider()
                reportRow("Günlük ortalama uyku", Fmt.duration(minutes: Insights.avgSleepMinutesPerDay(entries, days: days)))
                Divider()
                reportRow("Kaka kaydı", "\(Insights.dirtyDiaperDays(entries, days: days)) gün / \(days) gün")
                Divider()
                reportRow("Ateş kaydı", feverText)
                Divider()
                reportRow("Notlar", notesText)
            }
        }
    }

    private func reportRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.brandDark)
        }
        .padding(.vertical, 10).padding(.horizontal, 8)
    }

    private func regenerate() {
        pdfURL = PDFReportService.makeReport(baby: baby, entries: entries, days: days)
    }
}
