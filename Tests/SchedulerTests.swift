import XCTest

final class SchedulerTests: XCTestCase {
    func testCorrectAnswersSpreadReviewsOut() {
        var s = Scheduler.State()
        s = Scheduler.next(s, grade: .correct)
        XCTAssertEqual(s.intervalDays, 3)
        s = Scheduler.next(s, grade: .correct)
        XCTAssertEqual(s.intervalDays, 7)
        s = Scheduler.next(s, grade: .correct)
        XCTAssertGreaterThan(s.intervalDays, 14)
        XCTAssertEqual(s.streak, 3)
    }

    func testMissResetsToTomorrowAndLowersEase() {
        var s = Scheduler.State(intervalDays: 30, ease: 2.5, streak: 4)
        s = Scheduler.next(s, grade: .missed)
        XCTAssertEqual(s.intervalDays, 1)
        XCTAssertEqual(s.streak, 0)
        XCTAssertEqual(s.ease, 2.3, accuracy: 0.0001)
    }

    func testEaseNeverDropsBelowMinimum() {
        var s = Scheduler.State()
        for _ in 0..<20 { s = Scheduler.next(s, grade: .missed) }
        XCTAssertEqual(s.ease, Scheduler.minEase, accuracy: 0.0001)
    }

    func testIntervalIsCapped() {
        var s = Scheduler.State(intervalDays: 300, ease: 2.8, streak: 10)
        s = Scheduler.next(s, grade: .correct)
        XCTAssertEqual(s.intervalDays, Scheduler.maxIntervalDays)
    }

    func testDueDateIsStartOfDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let afternoon = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 15))!
        let due = Scheduler.dueDate(afterDays: 3, from: afternoon, calendar: cal)
        XCTAssertEqual(due, cal.date(from: DateComponents(year: 2026, month: 3, day: 13))!)
    }
}

final class RotationTests: XCTestCase {
    let ids = (0..<50).map { "word-\($0)" }

    func testStableHashIsDeterministic() {
        XCTAssertEqual(Rotation.stableHash("ameliorate"), Rotation.stableHash("ameliorate"))
        XCTAssertEqual(Rotation.order(ids), Rotation.order(ids.reversed()))
    }

    func testConsecutiveDaysGiveDifferentWords() {
        let order = Rotation.order(ids)
        var introduced = Set<String>()
        var seen = [String]()
        for day in 100..<130 {
            let id = Rotation.pickDaily(orderedIDs: order, dayIndex: day, introducedBeforeToday: introduced)!
            seen.append(id)
            introduced.insert(id)
        }
        XCTAssertEqual(Set(seen).count, seen.count, "no repeats while unseen words remain")
    }

    func testWordIntroducedTodayIsNotSkipped() {
        // Another device already introduced today's word; this device must agree.
        let order = Rotation.order(ids)
        let first = Rotation.pickDaily(orderedIDs: order, dayIndex: 7, introducedBeforeToday: [])
        let again = Rotation.pickDaily(orderedIDs: order, dayIndex: 7, introducedBeforeToday: [])
        XCTAssertEqual(first, again)
    }

    func testSkipsWordsLearnedOnEarlierDays() {
        let order = Rotation.order(ids)
        let natural = Rotation.pickDaily(orderedIDs: order, dayIndex: 3, introducedBeforeToday: [])!
        let next = Rotation.pickDaily(orderedIDs: order, dayIndex: 3, introducedBeforeToday: [natural])!
        XCTAssertNotEqual(natural, next)
    }

    func testMakeID() {
        XCTAssertEqual(Entry.makeID(for: "Devil's advocate"), "devils-advocate")
        XCTAssertEqual(Entry.makeID(for: "tête-à-tête"), "tete-a-tete")
        XCTAssertEqual(Entry.makeID(for: "  by the same token "), "by-the-same-token")
    }
}
