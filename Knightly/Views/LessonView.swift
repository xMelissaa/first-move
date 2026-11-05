import SwiftUI

struct LessonView: View {
    let lesson: Lesson
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var selectedChoice: Int?
    @State private var selectedSquare: Int?
    @State private var position: ChessPosition?
    @State private var lastMove: ChessMove?
    @State private var promotionChoices: [ChessMove] = []
    @State private var showPromotion = false
    @State private var solved = false
    @State private var feedback: String?
    @State private var feedbackIsCorrect = false
    @State private var showHint = false
    @State private var mistakes = 0
    @State private var awardedXP: Int?
    @State private var showExit = false

    private var step: LessonStep { lesson.steps[min(index, lesson.steps.count - 1)] }
    private var questionCount: Int { lesson.steps.filter { $0.type != "read" }.count }
    private var targets: [Int] {
        guard let position = position, let square = selectedSquare else { return [] }
        return position.legalMoves(from: square).map(\.to)
    }
    var body: some View {
        NavigationStack {
            Group {
                if let xp = awardedXP { completion(xp: xp) }
                else { exercise }
            }
            .background(Palette.cream).foregroundStyle(Palette.ink)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("Choose your promotion", isPresented: $showPromotion, titleVisibility: .visible) {
                ForEach(promotionChoices, id: \.uci) { move in
                    Button("Promote to \(move.promotion?.title ?? "queen")") { submit(move) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Leave this lesson?", isPresented: $showExit, titleVisibility: .visible) {
                Button("Leave lesson", role: .destructive) { dismiss() }
                Button("Keep learning", role: .cancel) {}
            } message: { Text("Your completed lessons are saved. This lesson will restart when you return.") }
            .task(id: index) { loadStep() }
        }.interactiveDismissDisabled(awardedXP == nil)
    }

    private var exercise: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Button { showExit = true } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(Palette.muted).padding(8)
                }.accessibilityLabel("Leave lesson")
                ProgressView(value: Double(index), total: Double(max(lesson.steps.count, 1))).tint(Palette.green)
                Text("\(index + 1)/\(lesson.steps.count)").font(.caption.weight(.bold)).foregroundStyle(Palette.muted)
            }.padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionEyebrow(text: step.type == "read" ? "Let’s understand it" : step.type == "move" ? "Your turn" : "A quick check")
                    Text(step.title ?? step.prompt ?? lesson.title)
                        .font(.system(.title, design: .rounded).weight(.bold)).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("lessonPrompt")
                    if let body = step.body { Text(body).font(.body).lineSpacing(5).foregroundStyle(Palette.muted) }
                    if let position = position {
                        HStack {
                            Label("\(position.turn.title) to move", systemImage: "circle.lefthalf.filled")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if step.type == "move" && !solved {
                                Text("Tap a piece, then a square").font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                        ChessBoardView(position: position, selected: selectedSquare, targets: targets,
                                       highlights: (step.highlights ?? []).compactMap { ChessPosition.square(named: $0) },
                                       lastMove: lastMove, orientation: step.orientation == "black" ? .black : .white,
                                       interactive: step.type == "move" && !solved, onTap: tap)
                        if step.type == "move" && !solved {
                            Button { showHint.toggle() } label: {
                                Label(showHint ? "Hide hint" : "A little hint", systemImage: "lightbulb")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.green)
                            }.padding(.vertical, 4)
                            if showHint, let hint = step.hint {
                                Text(hint).font(.subheadline).foregroundStyle(Palette.green)
                                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Palette.mint, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    if step.type == "choice" {
                        VStack(spacing: 12) {
                            ForEach(Array((step.options ?? []).enumerated()), id: \.offset) { optionIndex, option in
                                Button { choose(optionIndex) } label: {
                                    HStack(spacing: 14) {
                                        Text(String(UnicodeScalar(65 + optionIndex)!))
                                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                                            .frame(width: 30, height: 30)
                                            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 9))
                                        Text(option).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                        if solved && selectedChoice == optionIndex {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.green)
                                        }
                                    }
                                    .padding(16).foregroundStyle(Palette.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selectedChoice == optionIndex ? (solved ? Palette.mint : Color(hex: "FBE9DA")) : .white,
                                                in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedChoice == optionIndex ? Palette.green : Palette.line, lineWidth: 1.5))
                                }.buttonStyle(.plain).disabled(solved)
                                .accessibilityIdentifier("choice_\(optionIndex)")
                            }
                        }
                    }
                    if let feedback = feedback {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(feedbackIsCorrect ? "That’s it." : "Keep exploring.", systemImage: feedbackIsCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise")
                                .font(.headline)
                            Text(feedback).font(.subheadline).lineSpacing(3)
                        }.foregroundStyle(feedbackIsCorrect ? Palette.forest : Color(hex: "82502D"))
                            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(feedbackIsCorrect ? Palette.mint : Color(hex: "FBE9DA"), in: RoundedRectangle(cornerRadius: 20))
                            .accessibilityElement(children: .combine).accessibilityIdentifier("lessonFeedback")
                    }
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryButton(title: index == lesson.steps.count - 1 ? "Finish lesson" : "Continue", icon: "arrow.right", action: advance)
                    .opacity(step.type == "read" || solved ? 1 : 0.4)
                    .disabled(step.type != "read" && !solved)
                    .accessibilityIdentifier("lessonContinue")
                if step.type != "read" && !solved {
                    Text("Take your time. You have unlimited tries.").font(.caption).foregroundStyle(Palette.muted)
                }
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
                .frame(maxWidth: 620).frame(maxWidth: .infinity).background(Palette.cream)
        }
    }

    private func completion(xp: Int) -> some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 30)
                RookCharacter(size: 180)
                SectionEyebrow(text: "One step stronger")
                Text("Nicely played,\n\(progress.profileName).")
                    .font(.system(size: 34, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                Text("You’ve finished “\(lesson.title)”.\nEvery bit of practice adds up.")
                    .multilineTextAlignment(.center).foregroundStyle(Palette.muted).lineSpacing(4)
                HStack(spacing: 14) {
                    summaryStat("XP earned", "bolt.fill", "+\(xp)")
                    summaryStat("Day streak", "flame.fill", "\(progress.streak)")
                }
                Surface {
                    Label(mistakes == 0 ? "A clear run" : "Learning happens in the retries", systemImage: "leaf")
                        .font(.headline)
                    Text(mistakes == 0 ? "You worked through every exercise. Revisit the lesson to help it stick." : "You stayed with it and found the answers. Review this lesson again when it comes due.")
                        .font(.subheadline).foregroundStyle(Palette.muted).padding(.top, 5)
                }
                DailyGoalCard()
                PrimaryButton(title: "Back to my path", icon: "map") { dismiss() }.accessibilityIdentifier("lessonDone")
                Text(progress.errorMessage ?? (xp == 0 ? "This lesson’s XP has already been awarded today. You can keep practicing as much as you like." : "Your progress has been saved."))
                    .font(.footnote).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            }.padding(26).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("lessonCompleteScreen")
    }
    private func summaryStat(_ title: String, _ icon: String, _ value: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(icon == "flame.fill" ? Palette.orange : Palette.green)
            Text(value).font(.system(.title, design: .rounded).weight(.bold))
            Text(title).font(.caption).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity).padding(22).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
    private func loadStep() {
        selectedChoice = nil; selectedSquare = nil; solved = false; feedback = nil
        showHint = false; lastMove = nil; promotionChoices = []
        position = step.fen.flatMap { try? ChessPosition(fen: $0) }
    }
    private func choose(_ choice: Int) {
        guard !solved else { return }
        selectedChoice = choice
        if choice == step.answer {
            solved = true; feedbackIsCorrect = true
            feedback = step.explanation ?? "Well done."
            Haptics.success(enabled: progress.haptics)
        } else {
            mistakes += 1; feedbackIsCorrect = false
            feedback = "Take another look. \(step.explanation ?? "Try a different answer.")"
            Haptics.gentle(enabled: progress.haptics)
        }
    }
    private func tap(_ square: Int) {
        guard !solved, let position = position else { return }
        if let selected = selectedSquare {
            let moves = position.legalMoves(from: selected).filter { $0.to == square }
            if moves.count > 1 {
                promotionChoices = moves; showPromotion = true; return
            } else if let move = moves.first { submit(move); return }
        }
        if let piece = position.pieces[square], piece.color == position.turn {
            selectedSquare = selectedSquare == square ? nil : square
            Haptics.gentle(enabled: progress.haptics)
        } else { selectedSquare = nil }
    }
    private func submit(_ move: ChessMove) {
        guard let position = position, position.legalMoves().contains(move), !solved else { return }
        selectedSquare = nil
        if (step.accept ?? []).contains(move.uci) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { self.position = position.applying(move) }
            lastMove = move; solved = true; feedbackIsCorrect = true
            feedback = step.explanation ?? "You found it."
            Haptics.success(enabled: progress.haptics)
        } else {
            mistakes += 1; feedbackIsCorrect = false
            feedback = "That move is legal. For this exercise, try the move described above.\(step.hint.map { " " + $0 } ?? "")"
            Haptics.gentle(enabled: progress.haptics)
        }
    }
    private func advance() {
        guard step.type == "read" || solved else { return }
        if index + 1 < lesson.steps.count {
            index += 1
            loadStep()
        } else if awardedXP == nil {
            awardedXP = progress.complete(lesson, mistakes: mistakes, questionCount: questionCount)
            Haptics.success(enabled: progress.haptics)
        }
    }
}
