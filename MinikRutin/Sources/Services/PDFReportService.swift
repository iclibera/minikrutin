import UIKit

/// Builds a shareable doctor report PDF summarising the last N days.
enum PDFReportService {

    static func makeReport(baby: Baby, entries: [LogEntry], days: Int = 7) -> URL? {
        let pageW: CGFloat = 595, pageH: CGFloat = 842
        let margin: CGFloat = 48
        let bottom = pageH - margin
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH), format: format)

        let brand = UIColor(red: 0.239, green: 0.682, blue: 0.557, alpha: 1)
        let ink = UIColor(red: 0.17, green: 0.24, blue: 0.29, alpha: 1)
        let gray = UIColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MinikRutin-Doktor-Raporu.pdf")

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = margin

                func ensureSpace(_ h: CGFloat, _ context: UIGraphicsPDFRendererContext) {
                    if y + h > bottom {
                        context.beginPage()
                        y = margin
                    }
                }

                func draw(_ text: String, font: UIFont, color: UIColor, gapAfter: CGFloat = 6, indent: CGFloat = 0) {
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                    let maxW = pageW - margin * 2 - indent
                    let rect = (text as NSString).boundingRect(
                        with: CGSize(width: maxW, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                    ensureSpace(rect.height + gapAfter, ctx)
                    (text as NSString).draw(with: CGRect(x: margin + indent, y: y, width: maxW, height: rect.height),
                                            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                    y += rect.height + gapAfter
                }

                func divider() {
                    ensureSpace(14, ctx)
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: margin, y: y))
                    path.addLine(to: CGPoint(x: pageW - margin, y: y))
                    UIColor(white: 0.88, alpha: 1).setStroke()
                    path.lineWidth = 1
                    path.stroke()
                    y += 14
                }

                // Header
                draw("MinikRutin", font: .systemFont(ofSize: 24, weight: .bold), color: brand, gapAfter: 2)
                draw("Doktor Raporu", font: .systemFont(ofSize: 14, weight: .semibold), color: gray, gapAfter: 12)

                draw("Bebek: \(baby.name)", font: .systemFont(ofSize: 13, weight: .semibold), color: ink, gapAfter: 2)
                draw("Yaş: \(Fmt.age(from: baby.birthDate))", font: .systemFont(ofSize: 12), color: gray, gapAfter: 2)
                draw("Doğum tarihi: \(Fmt.dayMonthYear(baby.birthDate))", font: .systemFont(ofSize: 12), color: gray, gapAfter: 2)
                draw("Rapor aralığı: Son \(days) gün — \(Fmt.dayMonthYear(Date()))",
                     font: .systemFont(ofSize: 12), color: gray, gapAfter: 10)
                divider()

                // Summary stats
                draw("Özet", font: .systemFont(ofSize: 16, weight: .bold), color: ink, gapAfter: 8)
                let lines = [
                    "Günlük ortalama beslenme: \(String(format: "%.1f", Insights.avgFeedingsPerDay(entries, days: days))) kez",
                    "Toplam mama/süt: \(Fmt.ml(Insights.totalFeedingML(entries, days: days)))",
                    "Günlük ortalama uyku: \(Fmt.duration(minutes: Insights.avgSleepMinutesPerDay(entries, days: days)))",
                    "Günlük ortalama bez: \(String(format: "%.1f", Insights.avgDiapersPerDay(entries, days: days))) kez",
                    "Kaka kaydı: \(Insights.dirtyDiaperDays(entries, days: days)) gün / \(days) gün",
                ]
                for l in lines { draw("• \(l)", font: .systemFont(ofSize: 12), color: ink, gapAfter: 4) }

                let fevers = Insights.feverEntries(entries, days: days)
                if let maxFever = fevers.compactMap({ $0.temperatureC }).max() {
                    draw("• Ateş kaydı: \(fevers.count) kez (en yüksek \(Fmt.temp(maxFever)))",
                         font: .systemFont(ofSize: 12), color: ink, gapAfter: 4)
                } else {
                    draw("• Ateş kaydı: Yok", font: .systemFont(ofSize: 12), color: ink, gapAfter: 4)
                }
                y += 6
                divider()

                // Medicine list
                let meds = Insights.entries(Insights.windowEntries(entries, days: days), type: .medicine)
                    .filter { ($0.medName?.isEmpty == false) }
                if !meds.isEmpty {
                    draw("İlaçlar", font: .systemFont(ofSize: 16, weight: .bold), color: ink, gapAfter: 8)
                    for m in meds.sorted(by: { $0.date > $1.date }) {
                        let dose = (m.dose?.isEmpty == false) ? " — \(m.dose!)" : ""
                        draw("\(Fmt.relativeDay(m.date)) \(Fmt.time(m.date)): \(m.medName ?? "")\(dose)",
                             font: .systemFont(ofSize: 12), color: ink, gapAfter: 4)
                    }
                    y += 6; divider()
                }

                // Notes
                let notes = Insights.noteEntries(entries, days: days).filter { ($0.text?.isEmpty == false) }
                if !notes.isEmpty {
                    draw("Notlar", font: .systemFont(ofSize: 16, weight: .bold), color: ink, gapAfter: 8)
                    for n in notes.sorted(by: { $0.date > $1.date }) {
                        let tags = n.tags.isEmpty ? "" : " [\(n.tags.joined(separator: ", "))]"
                        draw("\(Fmt.relativeDay(n.date)) \(Fmt.time(n.date)): \(n.text ?? "")\(tags)",
                             font: .systemFont(ofSize: 12), color: ink, gapAfter: 4)
                    }
                    y += 6; divider()
                }

                // Disclaimer
                draw("Bu rapor yalnızca bilgilendirme amaçlıdır ve tıbbi teşhis ya da tedavi önerisi değildir. Lütfen kararlar için doktorunuza danışın.",
                     font: .italicSystemFont(ofSize: 10), color: gray, gapAfter: 0)
            }
            return url
        } catch {
            return nil
        }
    }
}
