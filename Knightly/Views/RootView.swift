import SwiftUI

struct LessonRoute: Identifiable {
    var lesson: Lesson
    var id: String { lesson.id }
}

struct RootView: View {
    let catalog: CourseCatalog
    @EnvironmentObject private var progress: ProgressStore
    @State private var tab = 0
    @State private var route: LessonRoute?

    var body: some View {
        Group {
            if let error = catalog.errorMessage {
                ContentUnavailableView("The course could not load", systemImage: "book.closed", description: Text(error))
            } else if !progress.onboardingComplete {
                OnboardingView()
            } else {
                TabView(selection: $tab) {
                    LearnView(catalog: catalog) { route = .init(lesson: $0) }
                        .tabItem { Label("Learn", systemImage: "map") }.tag(0)
                    PracticeView(catalog: catalog) { route = .init(lesson: $0) }
                        .tabItem { Label("Practice", systemImage: "square.grid.3x3") }.tag(1)
                    ProgressViewScreen(catalog: catalog)
                        .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }.tag(2)
                    ProfileView(catalog: catalog)
                        .tabItem { Label("You", systemImage: "person.crop.circle") }.tag(3)
                }
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.white, for: .tabBar)
            }
        }
        .foregroundStyle(Palette.ink)
        .fullScreenCover(item: $route) { item in
            LessonView(lesson: item.lesson)
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var page = 0
    @State private var name = ""
    @State private var goal = 20
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Label("first move", systemImage: "checkerboard.rectangle")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                        Spacer()
                        Text("\(page + 1) / 3").font(.subheadline.weight(.medium)).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 10)
                    RookCharacter(size: min(geo.size.width * 0.49, 210)).frame(maxWidth: .infinity)
                    if page == 0 {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionEyebrow(text: "A little curiosity. A better game.")
                            Text("Great chess starts\nwith a first move.")
                                .font(.system(size: 37, weight: .bold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                            Text("Learn from the very beginning. Make moves, find patterns, and build a habit that stays with you.")
                                .font(.body).foregroundStyle(Palette.muted).lineSpacing(4)
                        }
                        Label("No ads. No hearts. Unlimited tries.", systemImage: "checkmark.seal")
                            .font(.subheadline.weight(.medium)).foregroundStyle(Palette.green)
                    } else if page == 1 {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionEyebrow(text: "Make yourself at home")
                            Text("What should we\ncall you?").font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("Your name stays on your device until you choose to sync your progress.")
                                .foregroundStyle(Palette.muted)
                            TextField("Your first name", text: $name)
                                .textContentType(.givenName).textInputAutocapitalization(.words)
                                .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 18))
                                .accessibilityIdentifier("profileNameField")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionEyebrow(text: "Consistency over perfection")
                            Text("Small steps.\nReal progress.").font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("Pick a daily XP goal. You can change it any time, and you never lose access to a lesson.")
                                .foregroundStyle(Palette.muted)
                            ForEach([20, 40, 60], id: \.self) { xp in
                                Button { goal = xp } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(xp == 20 ? "A gentle start" : xp == 40 ? "Find your rhythm" : "A little more focus").fontWeight(.semibold)
                                            Text("\(xp) XP each day").font(.subheadline).foregroundStyle(Palette.muted)
                                        }
                                        Spacer()
                                        Image(systemName: goal == xp ? "checkmark.circle.fill" : "circle").font(.title2)
                                    }.padding(16).background(goal == xp ? Palette.mint : .white, in: RoundedRectangle(cornerRadius: 16))
                                }.buttonStyle(.plain).accessibilityIdentifier("goal_\(xp)")
                            }
                        }
                    }
                    Spacer(minLength: 12)
                    PrimaryButton(title: page == 2 ? "Make my first move" : "Continue") {
                        Haptics.gentle(enabled: true)
                        if page < 2 {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { page += 1 }
                        } else {
                            progress.profileName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Chess explorer" : String(name.prefix(40))
                            progress.dailyGoal = goal
                            progress.onboardingComplete = true
                            progress.savePreferences()
                        }
                    }.accessibilityIdentifier("onboardingContinue")
                    if page > 0 {
                        Button("Back") { page -= 1 }.frame(maxWidth: .infinity).font(.subheadline)
                    }
                }
                .padding(26).frame(maxWidth: 600).frame(minHeight: geo.size.height, alignment: .top)
                .frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively).background(Palette.cream)
        }
    }
}

struct LearnView: View {
    let catalog: CourseCatalog
    var openLesson: (Lesson) -> Void
    @EnvironmentObject private var progress: ProgressStore
    @State private var expandedUnit: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Label("first move", systemImage: "checkerboard.rectangle").font(.system(.title3, design: .rounded).weight(.heavy))
                        Spacer()
                        StatPill(symbol: "flame.fill", value: "\(progress.streak)", tint: Palette.orange)
                        StatPill(symbol: "bolt.fill", value: "\(progress.totalXP)")
                            .accessibilityElement(children: .ignore).accessibilityLabel("\(progress.totalXP) XP").accessibilityIdentifier("totalXPValue")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        SectionEyebrow(text: "Your chess journey")
                        Text("One good move\nat a time.").font(.system(size: 37, weight: .bold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                        Text("Hello, \(progress.profileName). Let’s build on what you know.")
                            .font(.subheadline).foregroundStyle(Palette.muted).padding(.top, 4)
                    }
                    if let next = progress.nextLesson(in: catalog) {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("UP NEXT").font(.caption.weight(.heavy)).tracking(1.7).foregroundStyle(Palette.lime)
                                    Text(next.title).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(.white)
                                    Text("\(next.minutes) min  ·  +\(next.xp) XP").font(.subheadline).foregroundStyle(.white.opacity(0.72))
                                }
                                Spacer(minLength: 0)
                                RookCharacter(size: 87).rotationEffect(.degrees(7))
                            }
                            Button { openLesson(next) } label: {
                                HStack {
                                    Text("Let’s learn").fontWeight(.bold)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }.padding(16).foregroundStyle(Palette.forest).background(Palette.lime, in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain).accessibilityIdentifier("continueLesson")
                        }.padding(24).background(Palette.forest, in: RoundedRectangle(cornerRadius: 27))
                    } else {
                        Surface {
                            Label("You’ve completed the course!", systemImage: "trophy.fill").font(.headline)
                            Text("Keep your skills fresh with reviews and practice games.").foregroundStyle(Palette.muted)
                        }
                    }
                    DailyGoalCard()
                    HStack {
                        Text("The learning path").font(.system(.title2, design: .rounded).weight(.bold))
                        Spacer()
                        Text("\(progress.completedIDs.count)/\(catalog.lessons.count)").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                    }
                    LazyVStack(spacing: 16) {
                        ForEach(Array(catalog.units.enumerated()), id: \.element.id) { index, unit in
                            unitCard(unit, index: index)
                        }
                    }
                    Text("A course builds your foundation. Practice, review, and thoughtful games help it grow.")
                        .font(.footnote).foregroundStyle(Palette.muted).lineSpacing(3).padding(.horizontal, 6)
                }
                .padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .background(Palette.cream).toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if expandedUnit == nil { expandedUnit = progress.nextLesson(in: catalog)?.unit ?? catalog.units.first?.id }
            }
        }
    }

    private func unitCard(_ unit: CourseUnit, index: Int) -> some View {
        let lessons = catalog.lessons.filter { $0.unit == unit.id }
        let done = lessons.filter { progress.completedIDs.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { expandedUnit = expandedUnit == unit.id ? nil : unit.id } } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15).fill(done == lessons.count ? Palette.forest : Palette.mint).frame(width: 54, height: 54)
                        Image(systemName: done == lessons.count ? "checkmark" : unitSymbol(index)).font(.title3.weight(.semibold))
                            .foregroundStyle(done == lessons.count ? .white : Palette.forest)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("UNIT \(index + 1)  ·  \(done)/\(lessons.count)").font(.system(.caption2, design: .rounded).weight(.bold)).tracking(1).foregroundStyle(Palette.muted)
                        Text(unit.title).font(.system(.headline, design: .rounded)).foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: expandedUnit == unit.id ? "chevron.up" : "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Palette.muted)
                }.padding(18)
            }.buttonStyle(.plain)
            if expandedUnit == unit.id {
                Text(unit.subtitle).font(.subheadline).foregroundStyle(Palette.muted).padding(.horizontal, 20).padding(.bottom, 16)
                ForEach(Array(lessons.enumerated()), id: \.element.id) { offset, lesson in
                    let completed = progress.completedIDs.contains(lesson.id)
                    let unlocked = progress.isUnlocked(lesson, catalog: catalog)
                    Button { openLesson(lesson) } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(completed ? Palette.forest : unlocked ? Palette.lime : Palette.cream).frame(width: 40, height: 40)
                                if completed || !unlocked {
                                    Image(systemName: completed ? "checkmark" : "lock.fill").font(.subheadline.weight(.bold)).foregroundStyle(completed ? .white : Palette.muted)
                                } else { Text("\(offset + 1)").font(.system(.headline, design: .rounded)).foregroundStyle(Palette.forest) }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lesson.title).font(.subheadline.weight(.semibold)).foregroundStyle(unlocked ? Palette.ink : Palette.muted)
                                Text(completed ? "Review anytime" : "\(lesson.minutes) min · \(lesson.xp) XP").font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            if unlocked { Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Palette.green) }
                        }.padding(.horizontal, 20).padding(.vertical, 12)
                    }.buttonStyle(.plain).disabled(!unlocked).accessibilityIdentifier("lessonRow_\(lesson.id)")
                    .accessibilityLabel("\(lesson.title), \(completed ? "completed" : unlocked ? "available" : "complete the previous lesson first")")
                    if offset != lessons.count - 1 { Divider().overlay(Palette.line).padding(.leading, 74) }
                }
                Spacer().frame(height: 10)
            }
        }.background(.white, in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).stroke(Palette.line, lineWidth: 1))
    }
    private func unitSymbol(_ index: Int) -> String {
        ["square.grid.3x3", "arrow.up.right", "crown", "shield.lefthalf.filled", "scope", "flag", "sparkles", "brain.head.profile"][index % 8]
    }
}

struct DailyGoalCard: View {
    @EnvironmentObject private var progress: ProgressStore
    var body: some View {
        Surface {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: progress.todayXP >= progress.dailyGoal ? "checkmark.seal.fill" : "sun.max")
                    .font(.title2).foregroundStyle(Palette.green)
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(progress.todayXP >= progress.dailyGoal ? "Daily goal, done." : "A little practice today").font(.subheadline.weight(.bold))
                        Spacer(minLength: 0)
                        Text("\(progress.todayXP)/\(progress.dailyGoal) XP").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                    }
                    ProgressView(value: Double(min(progress.todayXP, progress.dailyGoal)), total: Double(max(1, progress.dailyGoal))).tint(Palette.green)
                }
            }
        }
    }
}
