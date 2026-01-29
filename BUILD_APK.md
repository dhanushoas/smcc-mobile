# SMCC Mobile - APK Build Instructions

## Prerequisites
- Flutter SDK installed (https://flutter.dev/docs/get-started/install)
- Android Studio or Android SDK
- Java JDK 11 or higher

## Build Steps

### 1. Install Flutter Dependencies
```bash
cd /path/to/smcc-mobile
flutter pub get
```

### 2. Build APK (Release Mode)
```bash
flutter build apk --release
```

### 3. Build APK (Split per ABI - Smaller file size)
```bash
flutter build apk --split-per-abi --release
```

### 4. Find Your APK
The APK will be located at:
- **Universal APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Split APKs**: 
  - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (32-bit ARM)
  - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (64-bit ARM - Most modern devices)
  - `build/app/outputs/flutter-apk/app-x86_64-release.apk` (x86 devices)

## Quick Build Script

Run this script to build the APK:

```bash
#!/bin/bash
cd "$(dirname "$0")"
echo "🔧 Getting dependencies..."
flutter pub get

echo "📦 Building APK..."
flutter build apk --release

echo "✅ APK built successfully!"
echo "📍 Location: build/app/outputs/flutter-apk/app-release.apk"
```

## Alternative: Build AAB (For Google Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

## Troubleshooting

### If you get signing errors:
The app is already configured with a debug keystore. For production, you should:

1. Generate a release keystore:
```bash
keytool -genkey -v -keystore ~/smcc-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smcc
```

2. Create `android/key.properties`:
```properties
storePassword=your_password
keyPassword=your_password
keyAlias=smcc
storeFile=/path/to/smcc-release-key.jks
```

3. Update `android/app/build.gradle` to use the keystore (already configured in this project)

## Testing the APK

1. Transfer the APK to your Android device
2. Enable "Install from Unknown Sources" in device settings
3. Open the APK file and install

## App Details
- **Package Name**: com.smcc.cricket
- **App Name**: SMCC Cricket
- **Min SDK**: 21 (Android 5.0)
- **Target SDK**: 34 (Android 14)

---

**Note**: The current build is configured for development. For production release, update the version number in `pubspec.yaml` and use a proper release keystore.
