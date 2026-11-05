import SwiftUI
import AuthenticationServices
import UniformTypeIdentifiers

struct ProgressBackup: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw ProgressError.invalidBackup }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct ProfileView: View {
    let catalog: CourseCatalog
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var account: AccountSession
    @State private var exportDocument: ProgressBackup?
    @State private var showExport = false
    @State private var showImport = false
    @State private var pendingImport: Data?
    @State private var confirmImport = false
    @State private var showReset = false
    @State private var showDelete = false
    @State private var showSignOut = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionEyebrow(text: "Your own kind of chess player")
                    HStack(spacing: 20) {
                        RookCharacter(size: 82)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(progress.profileName).font(.system(.title, design: .rounded).weight(.bold))
                            Text(account.isSignedIn ? "Your First Move account" : "Learning on this iPhone")
                                .font(.subheadline).foregroundStyle(Palette.muted)
                        }
                    }
                    Surface {
                        Text("A little about you").font(.headline)
                        TextField("Your name", text: $progress.profileName)
                            .textContentType(.givenName).textInputAutocapitalization(.words)
                            .padding(14).background(Palette.cream, in: RoundedRectangle(cornerRadius: 12)).padding(.top, 12)
                            .onSubmit { progress.savePreferences() }
                        Text("Your daily goal").font(.subheadline.weight(.semibold)).padding(.top, 18)
                        Picker("Daily XP goal", selection: $progress.dailyGoal) {
                            Text("20 XP").tag(20); Text("40 XP").tag(40); Text("60 XP").tag(60)
                        }.pickerStyle(.segmented).padding(.top, 8)
                        Toggle("Gentle haptics", isOn: $progress.haptics).font(.subheadline).padding(.top, 18)
                    }
                    Surface {
                        Label(account.isSignedIn ? "Connected with Apple" : "Your progress, your choice", systemImage: account.isSignedIn ? "checkmark.shield" : "person.crop.circle.badge.checkmark")
                            .font(.headline)
                        Text(progress.syncStatus).font(.subheadline).foregroundStyle(Palette.muted).padding(.top, 8)
                        if account.isSignedIn {
                            Text("iCloud progress uses the Apple Account signed into iCloud on this iPhone. Your account is identified by Apple, and your lessons work offline.")
                                .font(.caption).foregroundStyle(Palette.muted).lineSpacing(3).padding(.top, 10)
                            Button("Sign out") { showSignOut = true }.font(.subheadline.weight(.semibold)).padding(.top, 16)
                        } else if AppConfig.appleSignInEnabled {
                            Text("Sign in to bring this device’s progress into your account. iCloud sync keeps it available on your other iPhones using the same iCloud account.")
                                .font(.subheadline).foregroundStyle(Palette.muted).padding(.top, 10)
                            SignInWithAppleButton(.signIn, onRequest: { request in request.requestedScopes = [.fullName] }, onCompletion: account.handleAppleAuthorization)
                                .signInWithAppleButtonStyle(.black).frame(height: 50).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.top, 16)
                        } else {
                            Text("Your lessons and progress are stored on this iPhone. Export a backup to keep a copy or move to another device.")
                                .font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(3).padding(.top, 10)
                        }
                    }
                    Surface {
                        Text("Keep a copy").font(.headline)
                        Text("A progress backup contains your profile name, preferences, and lesson history. Keep it somewhere private.")
                            .font(.subheadline).foregroundStyle(Palette.muted).padding(.top, 8)
                        Button {
                            progress.savePreferences()
                            if let data = progress.exportData() { exportDocument = .init(data: data); showExport = true }
                            else { message = "Your backup could not be prepared. Please try again." }
                        } label: { Label("Export progress", systemImage: "square.and.arrow.up") }.padding(.top, 16)
                        Button { showImport = true } label: { Label("Restore a backup", systemImage: "square.and.arrow.down") }.padding(.top, 16)
                    }
                    Surface {
                        Label("Made for learning", systemImage: "leaf").font(.headline)
                        Text("No ads, no hearts, and no limit on tries. First Move teaches chess through short lessons and practice, without promising a rating or perfect play.")
                            .font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(3).padding(.top, 10)
                        NavigationLink("Privacy & your data") { PrivacyView() }.padding(.top, 16).font(.subheadline.weight(.semibold))
                        Text("\(catalog.units.count) units · \(catalog.lessons.count) lessons · Version 1.0")
                            .font(.caption).foregroundStyle(Palette.muted).padding(.top, 12)
                    }
                    Button("Reset lesson progress", role: .destructive) { showReset = true }.font(.subheadline).padding(.horizontal, 6)
                    if account.isSignedIn {
                        Button("Delete my First Move profile", role: .destructive) { showDelete = true }.font(.subheadline).padding(.horizontal, 6)
                    }
                }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .background(Palette.cream).toolbar(.hidden, for: .navigationBar)
            .onDisappear { progress.savePreferences() }
            .onChange(of: progress.dailyGoal) { _, _ in progress.savePreferences() }
            .onChange(of: progress.haptics) { _, _ in progress.savePreferences() }
            .onChange(of: account.errorMessage) { _, text in if let text { message = text; account.errorMessage = nil } }
            .onChange(of: progress.errorMessage) { _, text in if let text { message = text } }
            .fileExporter(isPresented: $showExport, document: exportDocument, contentType: .json, defaultFilename: "First-Move-Progress") { result in
                if case .failure = result { message = "The backup was not saved. You can try exporting it again." }
            }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 5_000_000 else { throw ProgressError.invalidBackup }
                    pendingImport = try Data(contentsOf: url)
                    confirmImport = true
                } catch { message = error.localizedDescription }
            }
            .confirmationDialog("Restore this backup?", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("Restore backup") {
                    if let data = pendingImport {
                        do { try progress.importData(data); message = "Your progress backup has been restored." }
                        catch { message = error.localizedDescription }
                    }
                    pendingImport = nil
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: { Text("This replaces the current profile’s lesson history and settings with the backup. Export your current progress first if you want to keep it.") }
            .confirmationDialog("Reset your learning path?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Reset lesson progress", role: .destructive) { progress.resetProgress() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Your XP, streak, and lesson history will be erased. Your name and preferences stay. Export a backup first if you want to keep your progress.") }
            .confirmationDialog("Delete this First Move profile?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete profile", role: .destructive) { progress.deleteAccountData(); account.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This erases this profile’s progress and preferences from the app and iCloud sync, then signs you out. Your Apple Account remains unchanged.") }
            .confirmationDialog("Sign out of First Move?", isPresented: $showSignOut, titleVisibility: .visible) {
                Button("Sign out") { account.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Your account’s progress stays saved. The app will return to the local profile on this iPhone.") }
            .alert("First Move", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your data is yours.").font(.system(.largeTitle, design: .rounded).weight(.bold))
                privacySection("Lessons stay with you", "The course is bundled with the app. Your profile name, preferences, completed lessons, XP, and practice dates are saved on this device. Board practice games are temporary and disappear when you leave the board.")
                privacySection("An optional Apple connection", "When enabled, Sign in with Apple provides an account identifier and, if you share it, your name. The app stores that identity in the iPhone Keychain. It never asks for your Apple password. Apple sign-in and iCloud sync are optional; the local course works without either.")
                privacySection("iCloud progress", "Signed-in profiles can sync learning history and settings through Apple’s iCloud key-value storage, using the iCloud account on your device. Sync is eventual and may be delayed or unavailable. A reset keeps an anonymous reset timestamp to prevent old devices from restoring erased history.")
                privacySection("No ads or tracking", "First Move includes no advertising SDKs, third-party analytics, cross-app tracking, or subscription purchases. The chess bot runs locally. The app does not watch Chess.com, your screen, or other apps.")
                privacySection("Backups and deletion", "Export a JSON backup from your profile to keep a copy of your progress. Backups contain your profile name and study history. Reset progress to erase the learning history, or delete a connected First Move profile to erase its name and settings as well. Removing an exported file is your responsibility. Deleting this profile does not delete your Apple Account.")
                Link("Read the FIDE Laws of Chess", destination: URL(string: "https://handbook.fide.com/chapter/E012023")!).font(.subheadline.weight(.semibold))
                Text("Privacy information · First Move 1.0").font(.caption).foregroundStyle(Palette.muted)
            }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.background(Palette.cream).navigationTitle("Privacy").navigationBarTitleDisplayMode(.inline)
    }
    private func privacySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(5)
        }
    }
}
