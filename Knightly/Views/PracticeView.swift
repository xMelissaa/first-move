import SwiftUI

struct PracticeView: View {
    let catalog: CourseCatalog
    var openLesson: (Lesson) -> Void
    @EnvironmentObject private var progress: ProgressStore
    @State private var showBoard = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionEyebrow(text: "Make it second nature")
                    Text("A place to\ntry things.").font(.system(size: 37, weight: .bold, design: .rounded))
                    Text("Revisit a pattern. Explore a position. There’s no clock and no pressure.")
                        .foregroundStyle(Palette.muted).lineSpacing(4)
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "square.grid.3x3").font(.largeTitle).foregroundStyle(Palette.lime)
                            Spacer()
                            Text("UNLIMITED PRACTICE").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white.opacity(0.7))
                        }
                        Text("Meet me at the board.").font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(.white)
                        Text("Play a gentle practice bot, or explore moves for both sides. Legal squares are always one tap away.")
                            .foregroundStyle(.white.opacity(0.78)).font(.subheadline).lineSpacing(3)
                        Button { showBoard = true } label: {
                            HStack { Text("Open the practice board").fontWeight(.bold); Spacer(); Image(systemName: "arrow.right") }
                                .padding(16).background(Palette.lime, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(Palette.forest)
                        }.buttonStyle(.plain)
                    }.padding(24).background(Palette.forest, in: RoundedRectangle(cornerRadius: 26))
                    HStack {
                        Text("Ready for a refresh").font(.system(.title2, design: .rounded).weight(.bold))
                        Spacer()
                        Text("\(progress.dueLessons(in: catalog).count)").font(.subheadline.weight(.bold)).foregroundStyle(Palette.green)
                    }
                    if progress.dueLessons(in: catalog).isEmpty {
                        Surface {
                            Label("A clear review queue", systemImage: "leaf").font(.headline)
                            Text(progress.completedIDs.isEmpty ? "Finish your first lesson to start your review schedule." : "We’ll bring a lesson back when it’s time to help it stick. You can still revisit anything below.")
                                .font(.subheadline).foregroundStyle(Palette.muted).padding(.top, 6)
                        }
                    } else {
                        ForEach(progress.dueLessons(in: catalog)) { lesson in reviewCard(lesson, due: true) }
                    }
                    let completed = catalog.lessons.filter { progress.completedIDs.contains($0.id) }
                    if !completed.isEmpty {
                        Text("Your growing toolkit").font(.system(.title2, design: .rounded).weight(.bold))
                        ForEach(completed) { lesson in reviewCard(lesson, due: false) }
                    }
                    Surface {
                        Label("Before every move", systemImage: "brain.head.profile").font(.headline)
                        Text("1. What did my opponent’s last move change?\n2. Is my king safe?\n3. What checks, captures, or threats are available?\n4. What can my opponent do after my move?")
                            .font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(7).padding(.top, 8)
                    }
                }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.background(Palette.cream).toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showBoard) { PracticeBoardView() }
        }
    }
    private func reviewCard(_ lesson: Lesson, due: Bool) -> some View {
        Button { openLesson(lesson) } label: {
            HStack(spacing: 16) {
                Image(systemName: due ? "arrow.clockwise" : "checkmark.seal")
                    .font(.title2).foregroundStyle(Palette.green).frame(width: 34)
                VStack(alignment: .leading, spacing: 5) {
                    Text(lesson.title).font(.headline)
                    Text("\(lesson.minutes) min · +5 review XP once a day").font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
            }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

struct PracticeBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var progress: ProgressStore
    @State private var position = ChessPosition.initial
    @State private var history: [ChessPosition] = []
    @State private var moves: [String] = []
    @State private var selected: Int?
    @State private var lastMove: ChessMove?
    @State private var mode = 0
    @State private var flipped = false
    @State private var thinking = false
    @State private var showReset = false
    @State private var promotionChoices: [ChessMove] = []
    @State private var showPromotion = false
    @State private var requestID = UUID()
    @State private var botTask: Task<Void, Never>?
    @State private var claimedDraw: String?

    private var repetitionCount: Int {
        let key = position.repetitionKey
        return (history + [position]).filter { $0.repetitionKey == key }.count
    }
    private var drawReason: String? {
        if let claimedDraw { return claimedDraw }
        if position.isStalemate { return "Stalemate. The game is a draw." }
        if position.halfmoveClock >= 150 { return "Draw by the 75-move rule." }
        if repetitionCount >= 5 { return "Draw by fivefold repetition." }
        let nonKings = position.pieces.filter { $0.value.kind != .king }
        if nonKings.isEmpty { return "Draw: two kings cannot checkmate." }
        if nonKings.count == 1, let piece = nonKings.first?.value, piece.kind == .bishop || piece.kind == .knight {
            return "Draw: this material cannot produce checkmate."
        }
        if !nonKings.isEmpty, nonKings.values.allSatisfy({ $0.kind == .bishop }),
           Set(nonKings.keys.map { ($0 / 8 + $0 % 8) % 2 }).count == 1 {
            return "Draw: kings and bishops on one square color cannot produce checkmate."
        }
        return nil
    }
    private var gameOver: Bool { position.isCheckmate || drawReason != nil }
    private var status: String {
        if position.isCheckmate { return "Checkmate. \(position.turn.opposite.title) wins." }
        if let drawReason { return drawReason }
        if thinking { return "Your practice partner is thinking…" }
        if position.isCheck { return "\(position.turn.title) is in check. Protect the king." }
        return "\(position.turn.title) to move"
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Button { dismiss() } label: { Image(systemName: "xmark").padding(12).background(.white, in: Circle()) }.accessibilityLabel("Close practice board")
                        Spacer()
                        SectionEyebrow(text: "A little room to explore")
                    }
                    Text("The practice board").font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Picker("Practice mode", selection: $mode) {
                        Text("Gentle bot").tag(0)
                        Text("Both sides").tag(1)
                    }.pickerStyle(.segmented).onChange(of: mode) { _, _ in reset() }
                    HStack(spacing: 10) {
                        Circle().fill(position.turn == .white ? .white : Palette.forest).frame(width: 13, height: 13).overlay(Circle().stroke(Palette.forest.opacity(0.2)))
                        Text(status).font(.subheadline.weight(.semibold)).accessibilityIdentifier("practiceStatus")
                    }
                    ChessBoardView(position: position, selected: selected,
                                   targets: selected.map { position.legalMoves(from: $0).map(\.to) } ?? [],
                                   lastMove: lastMove, orientation: flipped ? .black : .white,
                                   interactive: !gameOver && !thinking, onTap: tap)
                    HStack {
                        Button { undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                            .disabled(history.isEmpty || thinking)
                        Spacer()
                        Button { flipped.toggle() } label: { Label("Flip", systemImage: "arrow.up.arrow.down") }
                        Spacer()
                        Button { showReset = true } label: { Label("New", systemImage: "arrow.clockwise") }
                    }.font(.subheadline.weight(.semibold)).padding(.vertical, 8)
                    if !gameOver && !thinking && (mode == 1 || position.turn == .white) && (position.halfmoveClock >= 100 || repetitionCount >= 3) {
                        Button("Claim a draw") {
                            requestID = UUID(); botTask?.cancel(); thinking = false
                            claimedDraw = "Draw claimed by \(position.turn.title)."
                        }.font(.headline)
                    }
                    Surface {
                        Label(mode == 0 ? "A practice partner, not a rating test" : "Follow your curiosity", systemImage: "leaf").font(.headline)
                        Text(mode == 0 ? "You play White. This simple bot looks for captures and safe moves. Take your time, undo freely, and use the thinking routine before each move." : "You control both colors. Tap any piece belonging to the side to move to see its legal destinations. Use Undo to compare ideas.")
                            .font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(4).padding(.top, 6)
                    }
                    if !moves.isEmpty {
                        SectionEyebrow(text: "Your moves · from → to")
                        Text(moves.enumerated().map { i, m in "\(i % 2 == 0 ? "\(i / 2 + 1). " : "")\(m)" }.joined(separator: "  "))
                            .font(.system(.subheadline, design: .monospaced)).foregroundStyle(Palette.muted).lineSpacing(5)
                    }
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(Palette.cream).toolbar(.hidden, for: .navigationBar)
                .confirmationDialog("Start a new practice game?", isPresented: $showReset, titleVisibility: .visible) {
                    Button("New game", role: .destructive) { reset() }
                    Button("Keep playing", role: .cancel) {}
                }
                .confirmationDialog("Choose your promotion", isPresented: $showPromotion, titleVisibility: .visible) {
                    ForEach(promotionChoices, id: \.uci) { move in
                        Button("Promote to \(move.promotion?.title ?? "queen")") { play(move) }
                    }
                }
                .onDisappear { requestID = UUID(); botTask?.cancel() }
        }
    }
    private func tap(_ square: Int) {
        guard !thinking, !gameOver, mode == 1 || position.turn == .white else { return }
        if let selected {
            let available = position.legalMoves(from: selected).filter { $0.to == square }
            if available.count > 1 { promotionChoices = available; showPromotion = true; return }
            if let move = available.first { play(move); return }
        }
        if position.pieces[square]?.color == position.turn { selected = selected == square ? nil : square }
        else { selected = nil }
    }
    private func play(_ move: ChessMove) {
        guard position.legalMoves().contains(move) else { return }
        history.append(position); moves.append(ChessPosition.name(of: move.from) + "–" + ChessPosition.name(of: move.to) + (move.promotion.map { "=" + $0.rawValue.uppercased() } ?? ""))
        position = position.applying(move); lastMove = move; selected = nil
        Haptics.gentle(enabled: progress.haptics)
        if mode == 0, position.turn == .black, !gameOver { scheduleBot() }
    }
    private func scheduleBot() {
        thinking = true
        let expectedID = UUID(); requestID = expectedID
        let snapshot = position
        botTask?.cancel()
        botTask = Task {
            let move = await Task.detached(priority: .userInitiated) { TrainingBot.choose(in: snapshot) }.value
            guard !Task.isCancelled, requestID == expectedID, !gameOver else { return }
            thinking = false
            if let move { play(move) }
        }
    }
    private func undo() {
        let count = mode == 0 ? min(2, history.count) : min(1, history.count)
        guard count > 0 else { return }
        requestID = UUID(); botTask?.cancel(); thinking = false; claimedDraw = nil
        for _ in 0..<count {
            if let previous = history.popLast() { position = previous; if !moves.isEmpty { moves.removeLast() } }
        }
        selected = nil; lastMove = nil
    }
    private func reset() {
        requestID = UUID(); botTask?.cancel(); thinking = false
        position = .initial; history = []; moves = []; selected = nil; lastMove = nil; claimedDraw = nil
    }
}

enum TrainingBot {
    // A small two-ply material search gives a forgiving local sparring partner.
    // This is not an analysis engine and doesn't claim a playing strength.
    static func choose(in position: ChessPosition) -> ChessMove? {
        let color = position.turn
        let choices = position.legalMoves()
        var best: ChessMove?
        var bestScore = -Double.infinity
        for move in choices.shuffled() {
            let next = position.applying(move)
            if next.isCheckmate { return move }
            let replies = next.legalMoves()
            let worst = replies.map { score(next.applying($0), for: color) }.min() ?? score(next, for: color)
            let centrality = 0.025 * (3.5 - abs(3.5 - Double(move.to % 8)))
            let value = worst + centrality
            if value > bestScore { bestScore = value; best = move }
        }
        return best
    }
    private static func score(_ position: ChessPosition, for color: ChessColor) -> Double {
        if position.isCheckmate { return position.turn == color ? -10_000 : 10_000 }
        if position.isStalemate { return 0 }
        let values: [PieceKind: Double] = [.pawn: 1, .knight: 3, .bishop: 3.1, .rook: 5, .queen: 9, .king: 0]
        return position.pieces.values.reduce(0) { $0 + (values[$1.kind] ?? 0) * ($1.color == color ? 1 : -1) }
    }
}
