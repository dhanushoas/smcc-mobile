#!/bin/bash

# SMCC Mobile APK Build Script
# This script builds the Android APK for the SMCC Cricket app

set -e

echo "🏏 SMCC Cricket - APK Build Script"
echo "=================================="
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null
then
    echo "❌ Flutter is not installed!"
    echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

echo "📦 Step 1: Getting dependencies..."
flutter pub get
echo ""

echo "🧹 Step 2: Cleaning previous builds..."
flutter clean
echo ""

echo "📦 Step 3: Getting dependencies again..."
flutter pub get
echo ""

echo "🔨 Step 4: Building APK (Release mode)..."
flutter build apk --release
echo ""

echo "✅ Build completed successfully!"
echo ""
echo "📍 APK Location:"
echo "   build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📊 APK Size:"
ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print "   " $5}'
echo ""
echo "🚀 You can now install this APK on Android devices!"
echo ""
echo "💡 Tip: For smaller APKs, use:"
echo "   flutter build apk --split-per-abi --release"
