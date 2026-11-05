# Build First Move without owning a Mac

This repository contains a native SwiftUI iPhone app, not a website. GitHub's hosted Mac can generate its Xcode project, compile it, run the chess tests and interface tests, and save a simulator screenshot. You can start that workflow from Windows or your iPhone. Apple Developer Program membership is not required for the unsigned simulator build. GitHub Actions usage limits and any charges depend on your GitHub plan.

The cloud workflows are prepared, but have not been run for you. A real GitHub run must pass before treating the app as compiled or tested. A simulator build cannot be installed on your iPhone; the later signed TestFlight route requires Apple developer membership and account setup.

## 1. Run the free simulator build

1. Create a GitHub repository and put the contents of this folder at its root. The root must contain `project.yml`, `Knightly/`, `KnightlyTests/`, `FirstMoveUITests/`, and `.github/workflows/`.
2. On Windows, GitHub Desktop is a convenient way to publish the entire folder, including the hidden `.github` directory. You may also use GitHub's browser upload, but verify that both workflow files are present under `.github/workflows` afterward. Keep the repository private if you do not want to share its source.
3. Open the repository's **Actions** tab. Enable workflows if GitHub prompts you. Select **iPhone build and tests**, then **Run workflow**. It also runs automatically on pushes to `main` or `master` and on pull requests.
4. Wait for the green result. If it fails, open the failed step and its log. The build is using Apple's Xcode and a real iPhone simulator in the cloud; Windows does not compile SwiftUI locally.
5. Open the completed run and download the artifact named `FirstMove-simulator-…`. It contains the screenshot, Xcode log, `.xcresult` test report, and simulator `.app` bundle. View the PNG on Windows. The `.app` is for a Mac simulator, not a device installer; `.xcresult` is intended for Xcode.

The workflow selects an available iPhone on the hosted runner rather than requiring one particular phone model. Interface tests can attach additional screens to the Xcode test report. A failed build may have logs without a screenshot or app bundle.

## 2. Install on your iPhone later with TestFlight

You can keep using the free simulator workflow before paying for Apple membership. This optional workflow archives and uploads a signed app; it never asks you to put an Apple ID password into GitHub.

Before running **Upload signed build to TestFlight**, you need:

- An active Apple Developer Program membership, an App Store Connect app record, and an explicit registered bundle ID you own. `org.firstmove.chess` is a source placeholder, not a registered identity provided to you.
- An Apple Distribution signing certificate exported with its private key as a password-protected `.p12`, plus an **App Store distribution** provisioning profile for the same team, bundle ID, and certificate. The Windows helper below can prepare a certificate request and `.p12`; you still create the certificate and profile in your own Apple developer account.
- A team App Store Connect API key permitted to upload builds, its key ID and issuer ID, and its `.p8` private key. Only download this key from your own account and store it securely.

Register the chosen bundle ID and add the app in App Store Connect before uploading. For a permanent project identity, change the three `PRODUCT_BUNDLE_IDENTIFIER` values in `project.yml` and the app's bundle ID in `.github/workflows/ios.yml`; the TestFlight workflow also accepts your registered app bundle ID as a run input.

Under your repository's **Settings → Secrets and variables → Actions**, create these repository secrets. Do not commit their values or signing files:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | The ten-character developer Team ID |
| `IOS_DISTRIBUTION_P12_BASE64` | Base64 text of the password-protected distribution `.p12` |
| `IOS_DISTRIBUTION_P12_PASSWORD` | That file's export password |
| `IOS_APP_STORE_PROFILE_BASE64` | Base64 text of the App Store `.mobileprovision` |
| `APP_STORE_CONNECT_KEY_ID` | The API key's ID |
| `APP_STORE_CONNECT_ISSUER_ID` | The API key issuer's UUID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | The complete `.p8` text, including its BEGIN/END lines |

To copy a signing file as base64 on Windows, run PowerShell locally and paste the clipboard into the corresponding GitHub secret field:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\distribution.p12')) | Set-Clipboard
```

Repeat with the `.mobileprovision` file. Keep these values out of chat, workflow logs, and source files. The signing workflow writes them to a temporary directory, imports the certificate into a dedicated temporary keychain, and removes its keychain, private keys, and installed profile in its final cleanup step. It does not upload signing materials as artifacts.

Run **Upload signed build to TestFlight** manually and enter your registered bundle ID. Leave **Enable Apple sign-in and iCloud key-value sync** off initially unless you have completed the capability setup below. The workflow uses Release, a unique GitHub run build number, your distribution profile, and API-key authentication to upload. It does not submit the app for public App Store review or add testers automatically.

After Apple processes the build, open the app's **TestFlight** tab in App Store Connect, finish any required export-compliance or beta details, and add yourself as an internal tester. Install Apple's TestFlight app on your iPhone and accept the invitation. External testing may require Apple's beta review. Upload success does not guarantee processing or review approval.

## Optional Apple sign-in and cloud progress

The default build has `FIRSTMOVE_ACCOUNTS_ENABLED=NO` and no signing entitlements. Local practice and progress work without an Apple developer team. The two Info.plist flags `FirstMoveAppleSignInEnabled` and `FirstMoveCloudEnabled` read the same build setting so unsupported account actions remain disabled.

When you are ready, enable **Sign in with Apple** and **iCloud key-value storage** for the registered App ID in your Apple developer account, regenerate its App Store distribution profile, and replace the profile secret. Then select the accounts checkbox in the TestFlight workflow. That sets:

```text
FIRSTMOVE_ACCOUNTS_ENABLED=YES
FIRSTMOVE_ENTITLEMENTS=Knightly/FirstMove.entitlements
CODE_SIGN_ENTITLEMENTS=$(FIRSTMOVE_ENTITLEMENTS)
```

The workflow checks the profile for both entitlements before archiving. The entitlements file uses the signing team's prefix and the app bundle ID for its iCloud key-value store identifier. iCloud key-value progress follows the device's iCloud account; Sign in with Apple is the app's sign-in identity, and signing in does not create a separate cross-platform storage service. Check both account features on an actual signed iPhone build.

## Technical notes

### Prepare a signing certificate on Windows later

After enrolling with Apple, you can prepare the signing key without a Mac. Install a trusted OpenSSL distribution (Git for Windows also includes OpenSSL), then run this in PowerShell, choosing a private folder **outside the repository**:

```powershell
./Tools/apple-signing.ps1 -Stage CreateRequest -OutputDirectory C:/Private/FirstMoveSigning
```

OpenSSL prompts for a private-key passphrase. In Apple's developer portal, create an **Apple Distribution** certificate and upload only the generated `.csr`. Download its `.cer`, then run:

```powershell
./Tools/apple-signing.ps1 -Stage ExportP12 -OutputDirectory C:/Private/FirstMoveSigning -CertificatePath C:/Downloads/distribution.cer
```

If `openssl` is not on PATH, add `-OpenSSLPath 'C:/Program Files/Git/usr/bin/openssl.exe'` when that is your installed path. The helper prompts for the key passphrase and a new `.p12` export password. It refuses to overwrite existing signing files. Keep the key, `.p12`, and passphrases private; the `.csr` is the public certificate request. These commands are prepared, not executed in this authoring session.

Use Apple's portal to create the matching App Store provisioning profile for your explicit App ID and certificate. To copy a file's base64 into a GitHub Actions secret on Windows without printing it into terminal logs, use:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:/Private/FirstMoveSigning/FirstMove-Distribution.p12')) | Set-Clipboard
```

Paste directly into the corresponding repository secret and clear the clipboard afterward. Repeat for the provisioning profile. Do not paste these values into chat.

- `project.yml` is the source of truth. [XcodeGen](https://github.com/yonaskolb/XcodeGen) generates `FirstMove.xcodeproj` on the runner. Keep the YAML in Git; you do not need to hand-edit an Xcode project on Windows.
- The app targets iOS 17 or later and uses Swift 5 language mode with a current compiler. The cloud runner supplies the Xcode SDK for compilation and App Store upload requirements.
- Unit tests cover legal moves, standard perft node counts, checkmate, stalemate, pins, both special pawn moves, castling, and FEN parsing. The test files are included; successful execution must be verified in Actions.
- [GitHub's current runner inventory](https://github.com/actions/runner-images) documents the `macos-26` image used here. If GitHub retires that image later, update the two workflows to a supported Mac image.
- [GitHub's signing guide](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications) describes certificate/profile secrets. [Apple's build upload documentation](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/) explains processing and supported upload tools.
