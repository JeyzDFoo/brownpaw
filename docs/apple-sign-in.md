# Sign in with Apple: setup

The app offers "Continue with Apple" on iOS, Android and the web
(`UserNotifier.signInWithApple` in `lib/providers/user_provider.dart`).
iPhone, iPad and Mac use Apple's native sheet; Android and the web use
Firebase's Apple flow, which needs a Services ID. The code is done; these
are the console steps.

## 1. Apple Developer (developer.apple.com > Certificates, Identifiers & Profiles)

1. **App ID.** Identifiers > your app's App ID > tick **Sign In with Apple**
   > Save. The App ID is `com.brownpaw.app` (the Xcode project uses it;
   register it first, see `docs/releasing.md` step 1).
2. **Services ID** (for Android and web). Identifiers > + > Services IDs.
   Description "Brownpaw web", identifier e.g. `com.brownpaw.signin`.
   Tick **Sign In with Apple** > Configure:
   - Primary App ID: the App ID above.
   - Domains: `brownclaw.firebaseapp.com` (plus any custom domain the
     web app is served from).
   - Return URL: `https://brownclaw.firebaseapp.com/__/auth/handler`
3. **Key.** Keys > + > name "Brownpaw Sign in with Apple", tick **Sign In
   with Apple** > Configure > choose the App ID > Register. Download the
   `.p8` file (once only) and note the **Key ID**. Your **Team ID** is at
   the top right of the developer site (`265ZKGV6P9`).
4. **Email relay** (for people who hide their email). Services > Sign in
   with Apple for Email Communication > add `noreply@brownclaw.firebaseapp.com`
   as a source, if you'll ever email users.

## 2. Firebase console (project brownclaw)

Authentication > Sign-in method > Add new provider > **Apple** > Enable:

- Services ID: the identifier from step 1.2.
- OAuth code flow configuration: Apple Team ID, Key ID and the contents
  of the `.p8` private key from step 1.3.
- Save.

Authentication > Settings > Authorized domains: make sure the domain the
web app runs on is listed (`brownclaw.web.app`, `brownclaw.firebaseapp.com`,
any custom domain).

## 3. Xcode

`ios/Runner/Runner.entitlements` already has the Sign In with Apple
entitlement. In Xcode > Runner > Signing & Capabilities, check **Sign In
with Apple** is listed and let automatic signing refresh the provisioning
profile. (Error 1000 on a device means the App ID or profile is missing the
capability.)

## 4. Android

Nothing to add in the project. It opens Apple's page in a browser tab and
returns through Firebase, so it works once step 2 is done.

## Account deletion

App Store rule 5.1.1(v): deleting an account must revoke Apple sign-in. On
iPhone/Mac, `deleteAccount` asks Apple once more, then calls
`revokeTokenWithAuthorizationCode` before deleting anything.
