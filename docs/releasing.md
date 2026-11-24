# Releasing to TestFlight and Google Play

Push a version tag and GitHub Actions builds both apps and uploads them:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

- **iOS** goes to TestFlight (`.github/workflows/release.yml` > `ios/fastlane/Fastfile`).
- **Android** goes to the Play **internal testing** track (`android/fastlane/Fastfile`).
- The version name comes from the tag (`v1.0.0` > `1.0.0`). The build number is
  the number of commits on main, so it only ever goes up.
- You can also run it from GitHub > Actions > Release > Run workflow, and pick
  one store. Run by hand, the version name comes from `pubspec.yaml`.
- Analyze and tests run first; nothing uploads if they fail.
- A store whose secrets aren't set yet is skipped with a note, so you can set
  up one store at a time.

| | iOS | Android |
|---|---|---|
| App ID | `com.brownpaw.app` | `com.brownpaw.brownclaw` |
| Apple Team | `265ZKGV6P9` | |
| Firebase project | `brownclaw` | `brownclaw` |

## One-time setup (only you can do these)

Do them in this order. Each GitHub secret goes in the repo under
**Settings > Secrets and variables > Actions > New repository secret**.

### Firebase and the iOS app ID

1. **Register the App ID.** [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list)
   > Identifiers > + > App IDs > App. Bundle ID (explicit): `com.brownpaw.app`.
   Tick **Push Notifications** and **Sign In with Apple**. (The old
   `com.example.brownpaw` can't go on the App Store.)
2. **Add the iOS app to Firebase.** On your Mac, in the repo:
   `flutterfire configure --project=brownclaw --platforms=android,ios,web`
   and pick `com.brownpaw.app` for iOS. This rewrites
   `ios/Runner/GoogleService-Info.plist` and `lib/firebase_options.dart`.
   Then copy the new `REVERSED_CLIENT_ID` from that plist into
   `CFBundleURLSchemes` in `ios/Runner/Info.plist` (Google sign-in needs it),
   and commit.
3. **APNs key for flow alerts.** Apple Developer > Keys > + > tick **Apple
   Push Notifications service** > download the `.p8`. Firebase console >
   Project settings > Cloud Messaging > Apple app configuration > upload it
   with its Key ID and Team ID `265ZKGV6P9`.
4. **Sign in with Apple** console steps: see `docs/apple-sign-in.md`.
   Also turn on **Anonymous** in Firebase console > Authentication >
   Sign-in method, for "Continue without an account".

### App Store Connect / TestFlight

5. **Create the app.** [App Store Connect](https://appstoreconnect.apple.com/apps)
   > + > New App. Platform iOS, name **Brownpaw**, language English (Canada),
   bundle ID `com.brownpaw.app`, SKU `brownpaw`.
6. **API key for uploads.** App Store Connect > Users and Access >
   Integrations > App Store Connect API > + . Name "GitHub Actions", access
   **App Manager**. Download the `.p8` (only once). Add secrets:
   - `ASC_KEY_ID`: the key's ID
   - `ASC_ISSUER_ID`: the Issuer ID shown above the list
   - `ASC_KEY_P8_BASE64`: `base64 -i AuthKey_XXXX.p8 | pbcopy`, then paste
7. **Distribution certificate.** Xcode > Settings > Accounts > your team >
   Manage Certificates > + > **Apple Distribution**. Then in Keychain Access
   > My Certificates, right-click "Apple Distribution: ..." > Export, save as
   `dist.p12` with a password. Add secrets:
   - `IOS_DIST_CERT_P12_BASE64`: `base64 -i dist.p12 | pbcopy`, then paste
   - `IOS_DIST_CERT_PASSWORD`: the password you chose
8. **Testers.** After the first upload finishes processing (about 15 minutes),
   App Store Connect > Brownpaw > TestFlight > Internal Testing > + to add
   yourself and up to 100 people on your team. External testers need a short
   Beta App Review the first time; the notes in `docs/store-listing.md`
   cover it.

### Google Play / internal testing

9. **Developer account.** [Play Console](https://play.google.com/console)
   ($25 once). New personal accounts must run a closed test with at least 12
   testers for 14 days before going to production. Internal testing (up to
   100 people) works straight away.
10. **Create the app.** Name Brownpaw, App, Free. Then work through
    **Dashboard > Set up your app**: privacy policy
    `https://brownclaw.web.app/privacy.html`, app access (give a test
    account), ads: none, content rating, target audience 13+, data safety
    (answers in `docs/store-listing.md`).
11. **Upload key.** On your Mac:
    ```bash
    keytool -genkey -v -keystore ~/brownpaw-upload.jks -keyalg RSA \
      -keysize 2048 -validity 10000 -alias upload
    ```
    Keep the file and passwords in your password manager; you need them for
    every Android release. Add secrets:
    - `ANDROID_KEYSTORE_BASE64`: `base64 -i ~/brownpaw-upload.jks | pbcopy`
    - `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`: the passwords
    - `ANDROID_KEY_ALIAS`: `upload`

    To build locally instead, copy `android/key.properties.example` to
    `android/key.properties` (git-ignored) and fill it in.
12. **First upload by hand.** Google only accepts API uploads once an app has
    a release. Push the tag (or Run workflow > android): with the keystore
    secrets set, the job builds the `.aab` and attaches it under the run's
    **Artifacts**. Upload it in Play Console > Testing > Internal testing >
    Create new release, accept **Play App Signing**, and roll it out.
13. **Google sign-in on Android.** Play Console > Test and release > App
    integrity > App signing: copy the SHA-1 and SHA-256 of both the **app
    signing key** and the **upload key** into Firebase console > Project
    settings > Your apps > Android app > Add fingerprint. Without this,
    Google sign-in fails on store builds.
14. **Service account for uploads.** Google Cloud console (project
    brownclaw) > IAM & Admin > Service accounts > Create, name
    "play-upload", no roles. Keys > Add key > JSON. In Play Console > Users
    and permissions > Invite new users, paste the service account's email,
    and under App permissions add Brownpaw with **Release to testing
    tracks**. Add secret:
    - `PLAY_SERVICE_ACCOUNT_JSON`: the whole JSON file's contents

From then on every tag uploads to both stores on its own.

### Before external testers or review

- Deploy hosting so the new privacy policy is live: `firebase deploy --only hosting`.
- Make sure `privacy@brownpaw.app` (used in the privacy policy and listing)
  reaches you, or change it in `web/privacy.html` and `docs/store-listing.md`.
- Reviewers use "Continue without an account", so no demo login is needed.
  Review notes are in `docs/store-listing.md`.

## Troubleshooting

- **Play: "Only releases with status draft may be created on draft app."**
  The first release hasn't been rolled out yet (step 12). Either finish it,
  or set the repository variable `PLAY_RELEASE_STATUS` to `draft`
  (Settings > Secrets and variables > Actions > Variables).
- **iOS: "No profiles for com.brownpaw.app"** or a capability error: the App
  ID needs Push Notifications and Sign In with Apple ticked (step 1). The
  lane fetches a fresh profile each run.
- **iOS: certificate not found in keychain**: re-export the `.p12` (step 7)
  and make sure it includes the private key.
- **Build number already used**: someone uploaded by hand with a higher
  number. Bump with an empty commit and tag again.

## Building by hand

```bash
# Android
flutter build appbundle --release            # needs android/key.properties
# iOS (signs with your Xcode account)
flutter build ipa --release
```
