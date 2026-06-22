import Foundation
import SwiftData

/// Seeds a realistic baby ("Elif") with a week of records so screenshots and
/// first-run previews look rich. Triggered only with the `-SeedDemo` launch arg.
enum DemoData {
    @MainActor
    static func seed(into context: ModelContext, env: AppEnvironment) {
        let cal = Fmt.calendar
        let now = Date()
        let birth = cal.date(byAdding: .day, value: -72, to: now)! // ~2 ay 12 gün

        let baby = Baby(name: "Elif", birthDate: birth, gender: .girl)
        context.insert(baby)
        let id = baby.id

        func at(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        func feeding(_ date: Date, type: FeedingType, ml: Double?, dur: Double? = nil) {
            let e = LogEntry(babyID: id, type: .feeding, date: date)
            e.feedingType = type; e.amountML = ml; e.durationMin = dur
            if type == .nursing { e.side = .both }
            context.insert(e)
        }
        func sleep(_ start: Date, minutes: Double) {
            let e = LogEntry(babyID: id, type: .sleep, date: start)
            e.endDate = start.addingTimeInterval(minutes * 60)
            context.insert(e)
        }
        func diaper(_ date: Date, kind: DiaperKind) {
            let e = LogEntry(babyID: id, type: .diaper, date: date)
            e.diaperKind = kind
            context.insert(e)
        }

        // Today — tuned to mirror the pitch deck dashboard numbers.
        feeding(now.addingTimeInterval(-2 * 3600 - 15 * 60), type: .formula, ml: 120)   // son beslenme 2s 15dk
        feeding(at(0, 11, 30), type: .breastMilk, ml: 100, dur: 18)
        feeding(at(0, 9, 0), type: .formula, ml: 110)
        feeding(at(0, 6, 30), type: .breastMilk, ml: 90, dur: 15)
        feeding(at(0, 3, 30), type: .formula, ml: 100)
        diaper(now.addingTimeInterval(-1 * 3600 - 5 * 60), kind: .wet)                   // son bez 1s 05dk
        diaper(at(0, 12, 10), kind: .both)
        diaper(at(0, 9, 15), kind: .wet)
        diaper(at(0, 6, 40), kind: .dirty)
        sleep(at(0, 1, 0), minutes: 180)
        sleep(at(0, 9, 30), minutes: 90)
        sleep(at(0, 13, 0), minutes: 130)   // total ~6s 40dk

        // Note + medicine/fever today
        let note = LogEntry(babyID: id, type: .note, date: at(0, 10, 0))
        note.text = "Beslenme sonrası hafif gaz şikayeti oldu."
        note.tags = ["gaz", "huzursuzluk"]
        context.insert(note)

        let med = LogEntry(babyID: id, type: .medicine, date: at(1, 21, 0))
        med.medName = "Parol şurup"; med.dose = "2.5 ml"; med.temperatureC = 37.8
        context.insert(med)

        // Past 6 days of feedings/sleeps/diapers for charts.
        for d in 1...6 {
            for h in [3, 6, 9, 12, 15, 18, 21] {
                feeding(at(d, h, 0), type: h % 2 == 0 ? .formula : .breastMilk, ml: Double(90 + (h % 3) * 15))
            }
            sleep(at(d, 1, 0), minutes: 200)
            sleep(at(d, 13, 0), minutes: 120)
            sleep(at(d, 16, 0), minutes: 110)
            for h in [4, 8, 11, 15, 19, 22] { diaper(at(d, h, 0), kind: h % 3 == 0 ? .dirty : .wet) }
        }

        // Growth + vaccine history
        let g1 = LogEntry(babyID: id, type: .growth, date: at(40, 10, 0))
        g1.weightKg = 4.2; g1.heightCm = 54; g1.headCm = 37
        context.insert(g1)
        let g2 = LogEntry(babyID: id, type: .growth, date: at(5, 10, 0))
        g2.weightKg = 5.1; g2.heightCm = 58; g2.headCm = 38.5
        context.insert(g2)

        let vac = LogEntry(babyID: id, type: .vaccine, date: at(3, 14, 0))
        vac.vaccineName = "2. ay aşıları (5'li karma)"; vac.vaccineDone = true
        context.insert(vac)
        let vac2 = LogEntry(babyID: id, type: .vaccine, date: cal.date(byAdding: .day, value: 20, to: now)!)
        vac2.vaccineName = "4. ay kontrolü"; vac2.vaccineDone = false
        context.insert(vac2)

        // Reminder
        let reminder = ReminderItem(babyID: id, title: "D vitamini", kind: .vitaminD, hour: 20, minute: 0)
        context.insert(reminder)

        try? context.save()
        env.selectedBabyID = id
    }
}
