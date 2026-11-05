import SwiftUI

struct ProgressViewScreen: View {
    let catalog: CourseCatalog
    @EnvironmentObject private var progress: ProgressStore
    private var level: Int { progress.totalXP / 250 + 1 }
    private var recentDays: [Date] {
        (-6...0).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date())) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionEyebrow(text: "Look how far you’ve come")
                    Text("Little by little,\nyou’re growing.").font(.system(size: 36, weight: .bold, design: .rounded))
                    HStack(spacing: 14) {
                        metric("Current streak", "\(progress.streak)", "flame.fill", Palette.orange)
                        metric("Total XP", "\(progress.totalXP)", "bolt.fill", Palette.green)
                    }
                    DailyGoalCard()
                    Surface {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                SectionEyebrow(text: "Your growing habit")
                                Text("The last seven days").font(.system(.headline, design: .rounded))
                            }
                            Spacer()
                            Label("\(progress.longestStreak) best", systemImage: "flame").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                        }
                        HStack(spacing: 8) {
                            ForEach(recentDays, id: \.self) { day in
                                let active = progress.activeDayStamps.contains(ProgressAnalytics.dayStamp(day))
                                VStack(spacing: 10) {
                                    Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
                                    ZStack {
                                        Circle().fill(active ? Palette.forest : Palette.cream)
                                        if active { Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(Palette.lime) }
                                        else { Text(day.formatted(.dateTime.day())).font(.caption.weight(.semibold)).foregroundStyle(Palette.muted) }
                                    }.aspectRatio(1, contentMode: .fit)
                                }.frame(maxWidth: .infinity)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(active ? "practiced" : "no completed lesson")")
                            }
                        }.padding(.top, 20)
                        Text("Complete a lesson or review to keep your streak. A new day gives you a fresh start.")
                            .font(.caption).foregroundStyle(Palette.muted).padding(.top, 14)
                    }
                    Surface {
                        HStack {
                            Image(systemName: "leaf.fill").font(.title2).foregroundStyle(Palette.green)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Level \(level) · \(levelName)").font(.system(.headline, design: .rounded))
                                Text("\(progress.totalXP % 250) / 250 XP to the next level").font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                        ProgressView(value: Double(progress.totalXP % 250), total: 250).tint(Palette.green).padding(.top, 16)
                        Text("Levels celebrate your practice. They aren’t chess ratings.").font(.caption).foregroundStyle(Palette.muted).padding(.top, 10)
                    }
                    Text("Milestones worth a smile").font(.system(.title2, design: .rounded).weight(.bold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        achievement("The first move", "Finish one lesson", "flag.fill", !progress.completedIDs.isEmpty)
                        achievement("Showing up", "Practice three days in a row", "flame.fill", progress.longestStreak >= 3)
                        achievement("Finding a rhythm", "Earn 100 XP", "bolt.fill", progress.totalXP >= 100)
                        achievement("A growing toolkit", "Complete eight lessons", "square.stack.3d.up.fill", progress.completedIDs.count >= 8)
                        achievement("A week of chess", "Build a seven-day streak", "sun.max.fill", progress.longestStreak >= 7)
                        achievement("Ready to keep growing", "Finish the full course", "graduationcap.fill", progress.completedIDs.count == catalog.lessons.count)
                    }
                    Text("Your recent practice").font(.system(.title2, design: .rounded).weight(.bold))
                    if progress.activities.isEmpty {
                        Surface { Text("Your story starts with your first lesson.").font(.subheadline).foregroundStyle(Palette.muted) }
                    } else {
                        Surface {
                            VStack(spacing: 18) {
                                ForEach(Array(progress.activities.suffix(8).reversed())) { activity in
                                    HStack(spacing: 12) {
                                        Image(systemName: activity.isFirstCompletion ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill").foregroundStyle(Palette.green)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(catalog.lessons.first { $0.id == activity.lessonID }?.title ?? "Chess practice").font(.subheadline.weight(.semibold))
                                            Text(activity.completedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(Palette.muted)
                                        }
                                        Spacer(minLength: 0)
                                        Text("+\(activity.xp) XP").font(.caption.weight(.bold)).foregroundStyle(Palette.green)
                                    }
                                }
                            }
                        }
                    }
                }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.background(Palette.cream).toolbar(.hidden, for: .navigationBar)
        }
    }
    private var levelName: String {
        switch level { case 1: return "Curious beginner"; case 2...3: return "Pattern finder"; case 4...6: return "Thoughtful mover"; default: return "Lifelong learner" }
    }
    private func metric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(value).font(.system(size: 34, weight: .bold, design: .rounded)).accessibilityIdentifier(title == "Total XP" ? "totalXP" : "currentStreak")
            Text(title).font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 23))
    }
    private func achievement(_ title: String, _ description: String, _ icon: String, _ unlocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: unlocked ? icon : "lock").font(.title2).foregroundStyle(unlocked ? Palette.green : Palette.muted)
                .frame(width: 48, height: 48).background(unlocked ? Palette.lime : Palette.cream, in: RoundedRectangle(cornerRadius: 16))
            Text(title).font(.system(.subheadline, design: .rounded).weight(.bold))
            Text(description).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.padding(18).frame(maxWidth: .infinity, minHeight: 175, alignment: .topLeading)
            .background(unlocked ? .white : .white.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.line, lineWidth: 1))
            .accessibilityElement(children: .combine).accessibilityLabel("\(title). \(description). \(unlocked ? "Earned" : "Not yet earned")")
    }
}
