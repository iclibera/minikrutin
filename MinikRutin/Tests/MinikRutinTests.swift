import XCTest
@testable import MinikRutin

final class MinikRutinTests: XCTestCase {

    func testDurationFormatting() {
        XCTAssertEqual(Fmt.duration(minutes: 400), "6s 40dk")
        XCTAssertEqual(Fmt.duration(minutes: 45), "45dk")
        XCTAssertEqual(Fmt.duration(minutes: 60), "1s")
    }

    func testTodayFeedingTotal() {
        let babyID = "baby-1"
        let now = Date()
        let a = LogEntry(babyID: babyID, type: .feeding, date: now)
        a.amountML = 120
        let b = LogEntry(babyID: babyID, type: .feeding, date: now)
        b.amountML = 100
        let old = LogEntry(babyID: babyID, type: .feeding,
                           date: Calendar.current.date(byAdding: .day, value: -2, to: now)!)
        old.amountML = 999
        let total = Insights.todayFeedingML([a, b, old], now: now)
        XCTAssertEqual(total, 220, accuracy: 0.01)
    }

    func testSleepMinutes() {
        let start = Date()
        let e = LogEntry(babyID: "b", type: .sleep, date: start)
        e.endDate = start.addingTimeInterval(90 * 60)
        XCTAssertEqual(e.sleepMinutes, 90, accuracy: 0.5)
    }

    func testFeverDetection() {
        let e = LogEntry(babyID: "b", type: .medicine, date: Date())
        e.temperatureC = 38.2
        let fevers = Insights.feverEntries([e])
        XCTAssertEqual(fevers.count, 1)
    }
}
