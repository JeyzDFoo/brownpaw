# Apple Sign-In Error 1000 - Complete Fix Guide

## Current Status
✅ Entitlements file created: `ios/Runner/Runner.entitlements`
✅ Xcode project configured with entitlements
✅ Development team set: 265ZKGV6P9
✅ Bundle ID: com.example.brownpaw
✅ Testing on real device (Jeyz's iPhone)

## The Problem
Error 1000 occurs because your App ID in Apple Developer Portal **does not have** the "Sign In with Apple" capability enabled.

## Step-by-Step Fix

### 1. Enable Sign In with Apple in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Sign in with your Apple Developer account
3. Navigate to: **Certificates, Identifiers & Profiles** → **Identifiers**
4. Look for your App ID: `com.example.brownpaw`
   
   **If it exists:**
   - Click on it
   - Scroll down to **Capabilities**
   - Check the box for **Sign In with Apple**
   - Click **Save**
   
   **If it doesn't exist:**
   - Click the **+** button to create a new identifier
   - Select **App IDs** → **App**
   - Enter:
     - Description: "Brownpaw"
     - Bundle ID: `com.example.brownpaw` (Explicit)
   - Under **Capabilities**, check **Sign In with Apple**
   - Click **Continue** → **Register**

### 2. Update/Create Provisioning Profile

After enabling the capability:

1. Go to **Certificates, Identifiers & Profiles** → **Profiles**
2. Find your development profile for `com.example.brownpaw`
3. **Delete it** (or edit if possible)
4. Create a new one:
   - Click **+** button
   - Select **iOS App Development**
   - Select your App ID: `com.example.brownpaw`
   - Select your certificate
   - Select your device (Jeyz's iPhone)
   - Name it (e.g., "Brownpaw Development")
   - Click **Generate**
   - **Download** the profile

### 3. Install the New Provisioning Profile

Option A - Automatic (Recommended):
```bash
# In Xcode, go to:
# Preferences → Accounts → [Your Account] → Download Manual Profiles
```

Option B - Manual:
```bash
# Open the downloaded .mobileprovision file
# It will automatically install to:
# ~/Library/MobileDevice/Provisioning Profiles/
```

### 4. Clean and Rebuild

```bash
cd /Users/jeyzdfoo/Desktop/code/brownpaw
flutter clean
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter build ios
# or
flutter run
```

### 5. Verify in Xcode (Optional but Recommended)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. You should see:
   - ✅ Automatically manage signing (checked)
   - ✅ Team: Your team (265ZKGV6P9)
   - ✅ Provisioning Profile: The new profile
   - ✅ **Sign In with Apple** capability listed

## Alternative: Use Service ID for Testing

If you want to test without proper App ID setup (temporary workaround):

**NOT RECOMMENDED** - This is only for testing and won't work in production.

You can temporarily modify the code to catch and handle this specific error gracefully, but the proper fix is enabling the capability in Apple Developer Portal.

## Common Issues

### Issue: "Failed to create provisioning profile"
**Solution:** Make sure you have added your device (Jeyz's iPhone) to your Apple Developer account under **Devices**.

### Issue: Still getting error 1000 after all steps
**Solution:** 
1. Completely delete the app from your iPhone
2. Restart Xcode
3. Clean build folder (Cmd+Shift+K in Xcode)
4. Rebuild and reinstall

### Issue: "No provisioning profiles found"
**Solution:** Open Xcode → Preferences → Accounts → Download Manual Profiles

## Testing Apple Sign-In

Once fixed, test it:
1. Launch the app on your real device
2. Tap "Sign in with Apple"
3. You should see the Apple authentication dialog
4. First time: Apple will ask for permission to share email/name
5. Sign in should complete successfully

## Notes

- Apple Sign-In **requires** a paid Apple Developer account ($99/year)
- It only works on real devices (iOS 13+) or Mac Catalyst
- Simulators need special configuration and may not work reliably
- The capability MUST be enabled in Apple Developer Portal - there's no way around this

---

**Status:** Awaiting Apple Developer Portal configuration
**Next Step:** Enable "Sign In with Apple" capability for App ID `com.example.brownpaw`
