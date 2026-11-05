import XCTest

final class FirstMoveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingRetriesCompletionUnlockAndPersistence() throws {
        try launchFreshAndOnboard(name: "Sam")

        // The second lesson is reachable in the path but cannot be opened early.
        let lockedLesson = app.buttons["lessonRow_rooks-and-bishops"]
        try reveal(lockedLesson, requireHittable: false)
        XCTAssertFalse(lockedLesson.isEnabled)
        capture("02-Learning-path")

        try tap(app.buttons["continueLesson"], scrolling: .down)
        let prompt = element("lessonPrompt")
        try expect(prompt, labelContaining: "64 squares")
        XCTAssertTrue(app.buttons["lessonContinue"].isEnabled)
        try tap(app.buttons["lessonContinue"])
        try expect(prompt, labelContaining: "Every square has an address")
        try tap(app.buttons["lessonContinue"])

        try expect(prompt, labelContaining: "Which address")
        XCTAssertFalse(app.buttons["lessonContinue"].isEnabled)
        XCTAssertTrue(app.buttons["choice_0"].label.contains("4e"))
        XCTAssertTrue(app.buttons["choice_1"].label.contains("e4"))
        try answerWithRetry()
        capture("03-Lesson-feedback")
        try tap(app.buttons["lessonContinue"])

        try expect(prompt, labelContaining: "What is the goal of chess?")
        XCTAssertFalse(app.buttons["lessonContinue"].isEnabled)
        try answerWithRetry()
        try tap(app.buttons["lessonContinue"])

        let completion = element("lessonCompleteScreen")
        XCTAssertTrue(completion.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["+30"].waitForExistence(timeout: 5))
        capture("04-Lesson-complete")
        try tap(app.buttons["lessonDone"])
        try expect(element("totalXPValue"), labelContaining: "30")

        let unlockedLesson = app.buttons["lessonRow_rooks-and-bishops"]
        try reveal(unlockedLesson, requireHittable: false)
        XCTAssertTrue(unlockedLesson.isEnabled)
        XCTAssertTrue(unlockedLesson.label.contains("available"))
        let completedLesson = app.buttons["lessonRow_meet-the-board"]
        XCTAssertTrue(completedLesson.label.contains("completed"))

        // Relaunch without the reset flag: this must read real persisted progress.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Learn"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["onboardingContinue"].exists)
        try expect(element("totalXPValue"), labelContaining: "30")
        let greeting = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Hello, Sam.")).firstMatch
        XCTAssertTrue(greeting.waitForExistence(timeout: 5))
        try tap(app.tabBars.buttons["You"])
        XCTAssertTrue(profileNameExists("Sam"))
        let selectedGoal = app.segmentedControls.buttons["40 XP"]
        XCTAssertTrue(selectedGoal.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedGoal.isSelected, "The onboarding goal must survive a relaunch.")
        capture("05-Persisted-profile")
    }

    @MainActor
    func testPracticeBoardLegalDestinationsUndoAndTabs() throws {
        try launchFreshAndOnboard(name: "Alex")
        try tap(app.tabBars.buttons["Practice"])
        let openBoard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Open the practice board")).firstMatch
        try tap(openBoard)
        try expect(element("practiceStatus"), labelContaining: "White to move")
        try tap(app.segmentedControls.buttons["Both sides"])

        // Coordinate and piece labels provide useful board navigation without sight.
        let e2 = squareButton(prefix: "e2, White pawn")
        XCTAssertTrue(e2.waitForExistence(timeout: 5))
        XCTAssertFalse(e2.label.isEmpty)
        try tap(e2)
        let e4 = squareButton(prefix: "e4, empty")
        try expect(e4, labelContaining: "legal destination")
        try tap(e4)
        try expect(element("practiceStatus"), labelContaining: "Black to move")
        XCTAssertTrue(squareButton(prefix: "e4, White pawn").exists)
        capture("06-Practice-board")

        try tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Undo")).firstMatch)
        try expect(element("practiceStatus"), labelContaining: "White to move")
        XCTAssertTrue(squareButton(prefix: "e2, White pawn").exists)
        try tap(app.buttons["Close practice board"])
        try tap(app.tabBars.buttons["Progress"])
        XCTAssertTrue(app.tabBars.buttons["Progress"].isSelected)
        try tap(app.tabBars.buttons["You"])
        XCTAssertTrue(profileNameExists("Alex"))
        try tap(app.tabBars.buttons["Learn"])
        try expect(element("totalXPValue"), labelContaining: "0")
    }

    @MainActor
    private func launchFreshAndOnboard(name: String) throws {
        app = XCUIApplication()
        app.launchArguments = ["-firstmove-ui-test-reset"]
        app.launch()
        let next = app.buttons["onboardingContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        XCTAssertFalse(next.label.isEmpty)
        capture("01-Welcome")
        try tap(next)
        let nameField = app.textFields["profileNameField"]
        try tap(nameField)
        nameField.typeText(name)
        try tap(next)
        try tap(app.buttons["goal_40"])
        try tap(next)
        XCTAssertTrue(app.tabBars.buttons["Learn"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Learn"].isSelected)
    }

    @MainActor
    private func answerWithRetry() throws {
        try tap(app.buttons["choice_0"])
        try expect(element("lessonFeedback"), labelContaining: "Keep exploring.")
        XCTAssertFalse(app.buttons["lessonContinue"].isEnabled)
        XCTAssertTrue(app.buttons["choice_1"].isEnabled, "A wrong answer must leave retries available.")
        try tap(app.buttons["choice_1"])
        try expect(element("lessonFeedback"), labelContaining: "That’s it.")
        XCTAssertTrue(app.buttons["lessonContinue"].isEnabled)
        XCTAssertFalse(app.buttons["choice_1"].isEnabled, "A solved question should not accept duplicate answers.")
    }

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func squareButton(prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func profileNameExists(_ name: String) -> Bool {
        let match = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ OR value == %@", name, name)
        ).firstMatch
        return match.waitForExistence(timeout: 5)
    }

    private enum ScrollDirection { case up, down }
    private enum InteractionError: Error { case elementUnavailable, expectedLabelMissing }

    @MainActor
    private func reveal(_ target: XCUIElement, scrolling direction: ScrollDirection = .up,
                        requireHittable: Bool = true, file: StaticString = #filePath, line: UInt = #line) throws {
        for attempt in 0..<7 {
            if target.exists && (!requireHittable || target.isHittable) { return }
            if attempt == 6 { break }
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                if direction == .up { scrollView.swipeUp() } else { scrollView.swipeDown() }
            } else if target.waitForExistence(timeout: 2) && (!requireHittable || target.isHittable) {
                return
            }
        }
        XCTFail("Could not reach element: \(target)", file: file, line: line)
        throw InteractionError.elementUnavailable
    }

    @MainActor
    private func tap(_ target: XCUIElement, scrolling direction: ScrollDirection = .up,
                     file: StaticString = #filePath, line: UInt = #line) throws {
        try reveal(target, scrolling: direction, file: file, line: line)
        target.tap()
    }

    @MainActor
    private func expect(_ target: XCUIElement, labelContaining text: String,
                        file: StaticString = #filePath, line: UInt = #line) throws {
        let predicate = NSPredicate(format: "exists == true AND label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        guard XCTWaiter.wait(for: [expectation], timeout: 8) == .completed else {
            XCTFail("Expected accessible label containing '\(text)': \(target)", file: file, line: line)
            throw InteractionError.expectedLabelMissing
        }
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
