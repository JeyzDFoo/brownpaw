# Google Maps API Setup Guide

## Step 1: Get Your API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select your existing project
3. Enable the following APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
4. Go to **Credentials** → **Create Credentials** → **API Key**
5. Copy your API key
6. **Important**: Restrict your API key:
   - For Android: Add package name `com.example.brownpaw` (or your actual package name)
   - For iOS: Add bundle identifier (found in Xcode or ios/Runner.xcodeproj)

## Step 2: Configure Android

Your API key has been added to the template in `android/app/src/main/AndroidManifest.xml`.
Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key.

## Step 3: Configure iOS

Your API key configuration has been added to `ios/Runner/AppDelegate.swift`.
Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key.

## Step 4: Add Location Permissions

The necessary location permissions have already been added to your configuration files.

## Step 5: Test

Run your app:
```bash
flutter run
```

The map should now display on the Guide screen!

## Troubleshooting

- **Map shows gray screen**: Check that your API key is valid and the Maps SDK is enabled
- **"This page can't load Google Maps correctly"**: Your API key may not be properly restricted
- **iOS not showing map**: Make sure you've rebuilt the app after adding the API key

## Security Note

Never commit your API keys to version control. Consider using environment variables or a secrets management solution for production apps.
