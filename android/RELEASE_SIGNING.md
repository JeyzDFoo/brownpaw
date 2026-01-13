# Android Release Signing Setup

## Quick Setup Guide

### 1. Generate a Keystore

Run this command to create your release keystore:

```bash
keytool -genkey -v -keystore ~/brownpaw-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias brownpaw-release
```

You'll be prompted for:
- Keystore password (save this securely!)
- Key password (save this securely!)
- Your name, organization, city, state, country

**IMPORTANT:** Store these passwords securely (password manager). You'll need them for every release.

### 2. Configure key.properties

Create `android/key.properties` (already in .gitignore):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=brownpaw-release
storeFile=/Users/yourusername/brownpaw-release.jks
```

Replace with your actual values from step 1.

### 3. Build Release

```bash
flutter build appbundle --release
```

The signed AAB will be at: `build/app/outputs/bundle/release/app-release.aab`

## Security Notes

✅ `key.properties` is already in `.gitignore`  
✅ Never commit keystores to version control  
✅ Backup your keystore securely (losing it means you can't update your app)  
✅ Store passwords in a password manager

## Build Configuration

The signing is configured in `android/app/build.gradle.kts`:
- Release builds use your keystore (when `key.properties` exists)
- Debug builds use Flutter's debug keystore (for development)
- ProGuard rules are configured for code obfuscation

## Troubleshooting

**"key.properties not found"**: Copy `key.properties.example` to `key.properties` and fill in your values.

**Build errors**: Ensure the storeFile path is absolute and the keystore file exists.
