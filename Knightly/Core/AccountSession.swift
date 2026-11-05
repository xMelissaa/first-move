import Foundation
import Combine
import AuthenticationServices
import Security

@MainActor
final class AccountSession: ObservableObject {
    @Published private(set) var currentUserID: String?
    @Published private(set) var displayName: String?
    @Published var errorMessage: String?
    var isSignedIn: Bool { currentUserID != nil }

    private var savedIdentity: SavedAppleIdentity?

    init() {
        savedIdentity = try? IdentityKeychain.read()
        if AppConfig.appleSignInEnabled, let identity = savedIdentity {
            // This restores access to this device's protected offline profile. It does
            // not grant a new remote session or claim a fresh online authentication.
            currentUserID = identity.userID
            displayName = identity.name
        }
        checkCredentialState()
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        guard AppConfig.appleSignInEnabled else {
            errorMessage = "Apple sign-in will be available in the signed TestFlight build. You can keep learning with your local profile."
            return
        }
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  !credential.user.isEmpty else {
                errorMessage = "Apple did not return an account. Please try again."
                return
            }
            let formatter = PersonNameComponentsFormatter()
            let returnedName = credential.fullName.map { formatter.string(from: $0) }
            let name = returnedName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let existingName = savedIdentity?.userID == credential.user ? savedIdentity?.name : nil
            let identity = SavedAppleIdentity(userID: credential.user,
                                              name: name?.isEmpty == false ? name : existingName)
            do {
                try IdentityKeychain.write(identity)
                savedIdentity = identity
                currentUserID = identity.userID
                displayName = identity.name
                errorMessage = nil
            } catch {
                errorMessage = "This iPhone could not save your account securely. Please unlock it and try again."
            }
        case .failure(let error):
            if let appleError = error as? ASAuthorizationError, appleError.code == .canceled { return }
            errorMessage = "Apple sign-in could not finish. Please check your connection and try again. Your local lessons are still available."
        }
    }

    func checkCredentialState() {
        guard AppConfig.appleSignInEnabled, let identity = savedIdentity else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: identity.userID) { [weak self] state, error in
            Task { @MainActor [weak self] in
                guard let self, self.savedIdentity?.userID == identity.userID else { return }
                if state == .authorized {
                    self.currentUserID = identity.userID
                    self.displayName = identity.name
                } else if error == nil {
                    self.signOut()
                } else {
                    self.errorMessage = "Your saved account is available offline. Connect to the internet to check its Apple sign-in status."
                }
            }
        }
    }

    func signOut() {
        do { try IdentityKeychain.remove() }
        catch { errorMessage = "The saved account could not be removed from Keychain. Please try again."; return }
        savedIdentity = nil
        currentUserID = nil
        displayName = nil
    }
}

private struct SavedAppleIdentity: Codable {
    let userID: String
    let name: String?
}

private enum IdentityKeychain {
    private static let service = "FirstMove.AppleIdentity"
    private static let account = "active"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read() throws -> SavedAppleIdentity? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError.status(status) }
        return try JSONDecoder().decode(SavedAppleIdentity.self, from: data)
    }

    static func write(_ identity: SavedAppleIdentity) throws {
        let data = try JSONEncoder().encode(identity)
        let attributes: [String: Any] = [kSecValueData as String: data,
                                        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let insertion = query.merging(attributes) { _, new in new }
            let addStatus = SecItemAdd(insertion as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.status(addStatus) }
        } else if status != errSecSuccess { throw KeychainError.status(status) }
    }

    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }

    private enum KeychainError: Error { case status(OSStatus) }
}
