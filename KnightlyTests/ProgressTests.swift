import XCTest
@testable import FirstMove

final class ProgressTests: XCTestCase {
    private var berlin: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    func testStreakIncludesYesterdayBeforeTodaysLesson() {
        let now = berlin.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 9))!
        XCTAssertEqual(ProgressAnalytics.currentStreak(days: ["2026-11-03", "2026-11-04"], now: now, calendar: berlin), 2)
        XCTAssertEqual(ProgressAnalytics.currentStreak(days: ["2026-11-03"], now: now, calendar: berlin), 0)
    }

    func testStreakCrossesSpringDSTWithoutUsing24HourSubtraction() {
        let now = berlin.date(from: DateComponents(year: 2026, month: 3, day: 30, hour: 1))!
        let days: Set<String> = ["2026-03-28", "2026-03-29", "2026-03-30"]
        XCTAssertEqual(ProgressAnalytics.currentStreak(days: days, now: now, calendar: berlin), 3)
        XCTAssertEqual(ProgressAnalytics.longestStreak(days: days, calendar: berlin), 3)
    }

    func testLongestStreakHandlesGapsAndYearBoundary() {
        XCTAssertEqual(ProgressAnalytics.longestStreak(days: ["2025-12-31", "2026-01-01", "2026-01-02", "2026-01-04"], calendar: berlin), 3)
    }

    func testInvalidDatesAreRejected() {
        XCTAssertNil(ProgressAnalytics.date(for: "2026-02-30", calendar: berlin))
        XCTAssertNil(ProgressAnalytics.date(for: "not-a-date", calendar: berlin))
    }

    func testMergeDeduplicatesOfflineMasteryAwardsAndIsCommutative() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = LearningActivity(id: "learn:pawns", lessonID: "pawns", completedAt: date, day: "2023-11-14",
                                 xp: 20, mistakes: 1, questionCount: 2, recordedAt: date)
        let b = LearningActivity(id: "learn:pawns", lessonID: "pawns", completedAt: date.addingTimeInterval(60), day: "2023-11-14",
                                 xp: 20, mistakes: 0, questionCount: 2, recordedAt: date.addingTimeInterval(60))
        var first = ProgressDocument(); first.activities = [a]
        var second = ProgressDocument(); second.activities = [b]
        let merged = first.merged(with: second)
        XCTAssertEqual(merged, second.merged(with: first))
        XCTAssertEqual(merged.activities.count, 1)
        XCTAssertEqual(merged.activities.reduce(0) { $0 + $1.xp }, 20)
    }

    func testResetTombstonePreventsOfflineHistoryResurrection() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var old = ProgressDocument()
        old.activities = [LearningActivity(id: "learn:pawns", lessonID: "pawns", completedAt: date, day: "2023-11-14",
                                           xp: 20, mistakes: 0, questionCount: 2, recordedAt: date)]
        var reset = ProgressDocument(); reset.resetAt = date.addingTimeInterval(1)
        XCTAssertTrue(old.merged(with: reset).activities.isEmpty)
        XCTAssertTrue(reset.merged(with: old).activities.isEmpty)
    }

    @MainActor
    func testFirstCompletionReviewCapAndGuestAccountIsolation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(directory: directory, cloudEnabled: false)
        let lesson = Lesson(id: "pawns", unit: "rules", title: "Pawns", summary: "Move pawns", xp: 20, minutes: 2, steps: [])
        XCTAssertEqual(store.complete(lesson, mistakes: 1, questionCount: 2), 20)
        XCTAssertEqual(store.complete(lesson, mistakes: 0, questionCount: 2), 5)
        XCTAssertEqual(store.complete(lesson, mistakes: 0, questionCount: 2), 0)
        XCTAssertEqual(store.totalXP, 25)
        store.switchAccount(id: "apple-user-a")
        XCTAssertEqual(store.totalXP, 25, "First account adopts this device's guest history")
        store.switchAccount(id: "apple-user-b")
        XCTAssertEqual(store.totalXP, 0, "A different account must not inherit another user's history")
        store.switchAccount(id: "apple-user-a")
        XCTAssertEqual(store.totalXP, 25)
    }

    @MainActor
    func testBackupRoundTripAndRestoreAfterReset() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(directory: directory, cloudEnabled: false)
        let lesson = Lesson(id: "pawns", unit: "rules", title: "Pawns", summary: "Move pawns", xp: 20, minutes: 2, steps: [])
        store.profileName = "Alex"; store.savePreferences()
        store.complete(lesson, mistakes: 0, questionCount: 2)
        let backup = try XCTUnwrap(store.exportData())
        store.resetProgress()
        XCTAssertEqual(store.totalXP, 0)
        try store.importData(backup)
        XCTAssertEqual(store.totalXP, 20)
        XCTAssertEqual(store.profileName, "Alex")
    }
}
