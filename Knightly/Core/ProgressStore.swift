import Foundation
import Combine
import CryptoKit

struct LearningActivity: Codable, Identifiable, Equatable {
    let id: String
    let lessonID: String
    let completedAt: Date
    let day: String
    let xp: Int
    let mistakes: Int
    let questionCount: Int
    // recordedAt permits an explicit backup restore while retaining the original study dates.
    let recordedAt: Date

    var isFirstCompletion: Bool { id.hasPrefix("learn:") }
    var accuracy: Double {
        guard questionCount > 0 else { return 1 }
        return max(0, 1 - Double(mistakes) / Double(questionCount))
    }
}

struct LessonMastery: Equatable {
    let lessonID: String
    let completedAt: Date
    let reviewCount: Int
    let nextReviewAt: Date
    let bestAccuracy: Double
}

struct LearnerPreferences: Codable, Equatable {
    var name = "Learner"
    var dailyGoal = 20
    var haptics = true
    var onboardingComplete = false
    var updatedAt = Date.distantPast
}

struct ProgressDocument: Codable, Equatable {
    var version = 1
    var preferences = LearnerPreferences()
    var activities: [LearningActivity] = []
    var resetAt = Date.distantPast

    /// Events have deterministic IDs. Two offline devices completing the same lesson
    /// therefore award its first-completion XP once when their histories merge.
    func merged(with other: ProgressDocument) -> ProgressDocument {
        var result = self
        result.resetAt = max(resetAt, other.resetAt)
        if other.preferences.updatedAt > preferences.updatedAt {
            result.preferences = other.preferences
        }
        var indexed: [String: LearningActivity] = [:]
        for activity in activities + other.activities where activity.recordedAt > result.resetAt {
            if let existing = indexed[activity.id] {
                // Prefer the earliest real completion, with a stable tie-breaker.
                if activity.completedAt < existing.completedAt ||
                    (activity.completedAt == existing.completedAt && activity.mistakes < existing.mistakes) {
                    indexed[activity.id] = activity
                }
            } else {
                indexed[activity.id] = activity
            }
        }
        result.activities = indexed.values.sorted {
            $0.completedAt == $1.completedAt ? $0.id < $1.id : $0.completedAt < $1.completedAt
        }
        return result
    }

    func validated() throws -> ProgressDocument {
        guard version == 1, activities.count <= 50_000,
              (5...200).contains(preferences.dailyGoal),
              preferences.name.count <= 60 else { throw ProgressError.invalidBackup }
        var ids: Set<String> = []
        for event in activities {
            guard !event.id.isEmpty, ids.insert(event.id).inserted,
                  !event.lessonID.isEmpty, (0...1_000).contains(event.xp),
                  (0...100_000).contains(event.mistakes),
                  (0...1_000).contains(event.questionCount),
                  ProgressAnalytics.date(for: event.day) != nil,
                  event.completedAt <= Date().addingTimeInterval(86_400),
                  event.recordedAt <= Date().addingTimeInterval(86_400),
                  event.id == (event.isFirstCompletion ? "learn:\(event.lessonID)" : "review:\(event.lessonID):\(event.day)") else {
                throw ProgressError.invalidBackup
            }
        }
        return self
    }
}

enum ProgressError: LocalizedError {
    case invalidBackup
    var errorDescription: String? { "This file is not a valid First Move progress backup." }
}

enum ProgressAnalytics {
    static var studyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    static func dayStamp(_ date: Date, calendar: Calendar = ProgressAnalytics.studyCalendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(for stamp: String, calendar: Calendar = ProgressAnalytics.studyCalendar) -> Date? {
        let values = stamp.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3, (1900...9999).contains(values[0]),
              let date = calendar.date(from: DateComponents(year: values[0], month: values[1], day: values[2])),
              dayStamp(date, calendar: calendar) == stamp else { return nil }
        return date
    }

    static func currentStreak(days: Set<String>, now: Date = Date(), calendar: Calendar = ProgressAnalytics.studyCalendar) -> Int {
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(dayStamp(cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(dayStamp(yesterday, calendar: calendar)) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(dayStamp(cursor, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func longestStreak(days: Set<String>, calendar: Calendar = ProgressAnalytics.studyCalendar) -> Int {
        let dates = days.compactMap { date(for: $0, calendar: calendar) }.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for date in dates {
            if let previous, calendar.dateComponents([.day], from: previous, to: date).day == 1 {
                run += 1
            } else { run = 1 }
            best = max(best, run)
            previous = date
        }
        return best
    }
}

@MainActor
final class ProgressStore: ObservableObject {
    @Published var profileName = "Learner"
    @Published var dailyGoal = 20
    @Published var haptics = true
    @Published var onboardingComplete = false
    @Published private(set) var syncStatus = "Saved on this iPhone"
    @Published private(set) var errorMessage: String?
    @Published private var document = ProgressDocument()

    private var accountID: String?
    private let directory: URL
    private let cloudEnabled: Bool
    private let cloud: NSUbiquitousKeyValueStore
    private var cloudObserver: NSObjectProtocol?
    private var identityObserver: NSObjectProtocol?
    private var cloudSuspended = false
    private let now: () -> Date

    init(directory: URL? = nil, cloudEnabled: Bool = AppConfig.cloudEnabled,
         cloud: NSUbiquitousKeyValueStore = .default, now: @escaping () -> Date = Date.init) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FirstMove", isDirectory: true)
        self.cloudEnabled = cloudEnabled
        self.cloud = cloud
        self.now = now
        loadLocal()
        if cloudEnabled {
            cloudObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.mergeCloud() }
            }
            identityObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.cloudSuspended = true
                    self?.syncStatus = "iCloud account changed. Sign out and in to reconnect."
                }
            }
        }
    }

    deinit {
        if let cloudObserver { NotificationCenter.default.removeObserver(cloudObserver) }
        if let identityObserver { NotificationCenter.default.removeObserver(identityObserver) }
    }

    var activities: [LearningActivity] { document.activities }
    var totalXP: Int { activities.reduce(0) { $0 + $1.xp } }
    var activeDayStamps: Set<String> { Set(activities.map(\.day)) }
    var streak: Int { ProgressAnalytics.currentStreak(days: activeDayStamps, now: now()) }
    var longestStreak: Int { ProgressAnalytics.longestStreak(days: activeDayStamps) }
    var todayXP: Int {
        let today = ProgressAnalytics.dayStamp(now())
        return activities.filter { $0.day == today }.reduce(0) { $0 + $1.xp }
    }
    var completedIDs: Set<String> { Set(activities.filter(\.isFirstCompletion).map(\.lessonID)) }

    func mastery(for lessonID: String) -> LessonMastery? {
        let history = activities.filter { $0.lessonID == lessonID }.sorted { $0.completedAt < $1.completedAt }
        guard let first = history.first(where: \.isFirstCompletion), let last = history.last else { return nil }
        let reviews = max(0, history.count - 1)
        let intervals = [1, 3, 7, 14, 30]
        let interval = last.mistakes == 0 ? intervals[min(reviews, intervals.count - 1)] : 1
        let next = Calendar.current.date(byAdding: .day, value: interval,
                                         to: Calendar.current.startOfDay(for: last.completedAt)) ?? last.completedAt
        return LessonMastery(lessonID: lessonID, completedAt: first.completedAt, reviewCount: reviews,
                             nextReviewAt: next, bestAccuracy: history.map(\.accuracy).max() ?? 0)
    }

    func isUnlocked(_ lesson: Lesson, catalog: CourseCatalog) -> Bool {
        guard let index = catalog.lessons.firstIndex(where: { $0.id == lesson.id }) else { return false }
        return index == 0 || completedIDs.contains(catalog.lessons[index - 1].id) || completedIDs.contains(lesson.id)
    }

    func nextLesson(in catalog: CourseCatalog) -> Lesson? {
        catalog.lessons.first { !completedIDs.contains($0.id) }
    }

    func dueLessons(in catalog: CourseCatalog) -> [Lesson] {
        catalog.lessons.filter { lesson in
            guard let mastery = mastery(for: lesson.id) else { return false }
            return mastery.nextReviewAt <= now()
        }.sorted {
            (mastery(for: $0.id)?.nextReviewAt ?? .distantFuture) <
            (mastery(for: $1.id)?.nextReviewAt ?? .distantFuture)
        }
    }

    @discardableResult
    func complete(_ lesson: Lesson, mistakes: Int, questionCount: Int) -> Int {
        savePreferences(write: false)
        let date = now()
        let day = ProgressAnalytics.dayStamp(date)
        let isFirst = !completedIDs.contains(lesson.id)
        let id = isFirst ? "learn:\(lesson.id)" : "review:\(lesson.id):\(day)"
        guard !activities.contains(where: { $0.id == id }) else { return 0 }
        let xp = isFirst ? lesson.xp : 5
        let recordedAt = max(date, document.resetAt.addingTimeInterval(0.001))
        let activity = LearningActivity(id: id, lessonID: lesson.id, completedAt: date, day: day,
                                        xp: xp, mistakes: max(0, mistakes), questionCount: max(0, questionCount),
                                        recordedAt: recordedAt)
        document.activities.append(activity)
        persist()
        return xp
    }

    func savePreferences() { savePreferences(write: true) }

    private func savePreferences(write: Bool) {
        profileName = String(profileName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        if profileName.isEmpty { profileName = "Learner" }
        dailyGoal = min(200, max(5, dailyGoal))
        let existing = document.preferences
        if existing.name != profileName || existing.dailyGoal != dailyGoal || existing.haptics != haptics ||
            existing.onboardingComplete != onboardingComplete {
            document.preferences = LearnerPreferences(name: profileName, dailyGoal: dailyGoal, haptics: haptics,
                                                       onboardingComplete: onboardingComplete, updatedAt: now())
        }
        if write { persist() }
    }

    /// A reset tombstone prevents an old offline device from restoring erased progress.
    /// Profile preferences are deliberately preserved.
    func resetProgress() {
        savePreferences(write: false)
        document.resetAt = now()
        document.activities = []
        persist()
    }

    /// Erase the app's account data. The tombstone contains no name or lesson history
    /// and prevents an offline device from restoring deleted personal data.
    /// Call AccountSession.signOut() afterwards to remove the local Apple identity.
    func deleteAccountData() {
        document = ProgressDocument()
        document.resetAt = now()
        document.preferences.updatedAt = now()
        publishPreferences()
        persist()
    }

    func switchAccount(id: String?) {
        guard id != accountID else { return }
        savePreferences()
        let guest = accountID == nil ? document : nil
        accountID = id
        cloudSuspended = false
        let hasExistingLocalAccount = FileManager.default.fileExists(atPath: fileURL.path)
        document = ProgressDocument()
        loadLocal()
        if id != nil {
            if cloudEnabled { _ = cloud.synchronize(); mergeCloud() }
            // Migrate guest work once, only when no account history exists locally or in iCloud.
            if !hasExistingLocalAccount, document.activities.isEmpty,
               document.resetAt == .distantPast, let guest {
                document = guest
                publishPreferences()
            }
        }
        persist()
    }

    func refreshSync() {
        // Refresh date-derived streak and goal values after midnight or a time-zone
        // change even for a guest profile with cloud access disabled.
        objectWillChange.send()
        guard canSync else { return }
        _ = cloud.synchronize()
        mergeCloud()
    }

    func exportData() -> Data? {
        savePreferences(write: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(document)
    }

    func importData(_ data: Data) throws {
        guard data.count <= 5_000_000 else { throw ProgressError.invalidBackup }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var imported = try decoder.decode(ProgressDocument.self, from: data).validated()
        let date = now()
        imported.resetAt = date
        imported.preferences.updatedAt = date
        imported.activities = imported.activities.map {
            LearningActivity(id: $0.id, lessonID: $0.lessonID, completedAt: $0.completedAt, day: $0.day,
                             xp: $0.xp, mistakes: $0.mistakes, questionCount: $0.questionCount,
                             recordedAt: date.addingTimeInterval(0.001))
        }
        document = imported
        publishPreferences()
        persist()
    }

    private var canSync: Bool {
        cloudEnabled && accountID != nil && !cloudSuspended && FileManager.default.ubiquityIdentityToken != nil
    }
    private var accountKey: String {
        guard let accountID else { return "guest" }
        return SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    // KVS keys may contain at most 64 bytes. A 160-bit account digest keeps this key
    // below that limit while avoiding any name, email, or raw Apple subject in it.
    private var cloudKey: String { "firstmove.progress.\(accountKey.prefix(40))" }
    private var fileURL: URL { directory.appendingPathComponent("progress-\(accountKey).json") }

    private func loadLocal() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                document = try JSONDecoder().decode(ProgressDocument.self, from: data).validated()
            }
            errorMessage = nil
        } catch {
            // Keep the original file for recovery, rather than overwriting a corrupt backup.
            let recovery = fileURL.deletingPathExtension().appendingPathExtension("recovery-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: recovery)
            errorMessage = "Your saved progress could not be read. A recovery copy was kept on this iPhone."
        }
        publishPreferences()
    }

    private func publishPreferences() {
        profileName = document.preferences.name
        dailyGoal = document.preferences.dailyGoal
        haptics = document.preferences.haptics
        onboardingComplete = document.preferences.onboardingComplete
    }

    private func persist() {
        if canSync { mergeCloud(writeBack: false) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(document)
            try data.write(to: fileURL, options: .atomic)
            #if os(iOS)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                                   ofItemAtPath: fileURL.path)
            #endif
            errorMessage = nil
            if canSync {
                // synchronize() is not a delivery receipt. Never label a write as confirmed uploaded.
                if data.count < 900_000 {
                    cloud.set(data, forKey: cloudKey)
                    syncStatus = "iCloud sync enabled"
                } else { syncStatus = "Saved locally. Export a backup; iCloud storage is full." }
            } else if !cloudSuspended { syncStatus = "Saved on this iPhone" }
        } catch {
            errorMessage = "Progress could not be saved. Please check the free storage on your iPhone."
            syncStatus = "Could not save progress"
        }
    }

    private func mergeCloud(writeBack: Bool = true) {
        guard canSync, let data = cloud.data(forKey: cloudKey),
              let remote = try? JSONDecoder().decode(ProgressDocument.self, from: data).validated() else { return }
        let merged = document.merged(with: remote)
        guard merged != document else { return }
        document = merged
        publishPreferences()
        if writeBack { persist() }
    }
}
