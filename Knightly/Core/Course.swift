import Foundation

struct CourseUnit: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: String
}

struct Lesson: Codable, Identifiable, Equatable {
    let id: String
    let unit: String
    let title: String
    let summary: String
    let xp: Int
    let minutes: Int
    let steps: [LessonStep]

    var questionCount: Int { steps.filter { $0.type != "read" }.count }
}

struct LessonStep: Codable, Identifiable, Equatable {
    let type: String
    let title: String?
    let body: String?
    let fen: String?
    let highlights: [String]?
    let prompt: String?
    let options: [String]?
    let answer: Int?
    let explanation: String?
    let accept: [String]?
    let hint: String?
    let orientation: String?

    // The view also uses the lesson's step index, so repeated instructions remain distinct.
    var id: String { [type, title ?? "", prompt ?? "", fen ?? ""].joined(separator: "|") }
}

struct CourseCatalog {
    private struct Document: Decodable {
        let units: [CourseUnit]
        let lessons: [Lesson]
    }

    private(set) var units: [CourseUnit] = []
    private(set) var lessons: [Lesson] = []
    private(set) var errorMessage: String?

    init(bundle: Bundle = .main) {
        do {
            guard let url = bundle.url(forResource: "course", withExtension: "json") else {
                throw CourseError.missingResource
            }
            self = try CourseCatalog(data: Data(contentsOf: url))
        } catch {
            errorMessage = "The lessons could not load. Close and reopen First Move. Your saved progress remains on this iPhone."
        }
    }

    init(data: Data) throws {
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard !document.units.isEmpty, !document.lessons.isEmpty,
              Set(document.units.map(\.id)).count == document.units.count,
              Set(document.lessons.map(\.id)).count == document.lessons.count else {
            throw CourseError.invalidContent
        }
        let unitIDs = Set(document.units.map(\.id))
        for lesson in document.lessons {
            guard unitIDs.contains(lesson.unit), lesson.xp > 0, lesson.minutes > 0,
                  !lesson.steps.isEmpty else { throw CourseError.invalidContent }
            for step in lesson.steps {
                switch step.type {
                case "read":
                    guard step.body?.isEmpty == false else { throw CourseError.invalidContent }
                case "choice":
                    guard let options = step.options, options.count >= 2,
                          let answer = step.answer, options.indices.contains(answer),
                          step.prompt?.isEmpty == false,
                          step.explanation?.isEmpty == false else { throw CourseError.invalidContent }
                case "move":
                    guard step.fen?.isEmpty == false, step.prompt?.isEmpty == false,
                          step.accept?.isEmpty == false,
                          step.explanation?.isEmpty == false else { throw CourseError.invalidContent }
                default: throw CourseError.invalidContent
                }
            }
        }
        units = document.units
        lessons = document.lessons
        errorMessage = nil
    }

    func lessons(in unit: CourseUnit) -> [Lesson] { lessons.filter { $0.unit == unit.id } }

    enum CourseError: Error { case missingResource, invalidContent }
}
