#!/bin/bash

# iOS App Store Compliance Setup Script
# This script helps configure your iOS project for App Store submission

echo "🍎 LocationPal - iOS App Store Compliance Setup"
echo "================================================"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Must be run from the Flutter project root"
    exit 1
fi

echo "✅ Flutter project detected"
echo ""

# Check if PrivacyInfo.xcprivacy exists
if [ -f "ios/Runner/PrivacyInfo.xcprivacy" ]; then
    echo "✅ PrivacyInfo.xcprivacy file exists"
else
    echo "❌ PrivacyInfo.xcprivacy file missing!"
    echo "   This file should have been created at: ios/Runner/PrivacyInfo.xcprivacy"
    exit 1
fi

echo ""
echo "📋 Next Steps for App Store Submission:"
echo ""
echo "1. Open Xcode Project:"
echo "   cd ios && open Runner.xcworkspace"
echo ""
echo "2. Add PrivacyInfo.xcprivacy to Xcode:"
echo "   a) In Xcode, right-click 'Runner' folder in Project Navigator"
echo "   b) Select 'Add Files to Runner...'"
echo "   c) Navigate to and select: Runner/PrivacyInfo.xcprivacy"
echo "   d) Ensure 'Copy items if needed' is checked"
echo "   e) Ensure 'Runner' target is selected"
echo "   f) Click 'Add'"
echo ""
echo "3. Verify Bundle Resources:"
echo "   a) Select 'Runner' project in Xcode"
echo "   b) Go to 'Runner' target > 'Build Phases'"
echo "   c) Expand 'Copy Bundle Resources'"
echo "   d) Verify 'PrivacyInfo.xcprivacy' is listed"
echo "   e) If not, click '+' and add it"
echo ""
echo "4. Update App URLs:"
echo "   a) Host docs/ folder at a public URL (GitHub Pages, your domain, etc.)"
echo "   b) Update lib/utils/onboarding_service.dart with your URLs:"
echo "      static const String privacyPolicyUrl = 'https://YOUR_URL/docs/policy.html';"
echo "      static const String termsOfServiceUrl = 'https://YOUR_URL/docs/terms.html';"
echo ""
echo "5. Test on Physical Device:"
echo "   flutter run --release -d <your-ios-device>"
echo "   - Verify disclosure screen shows on first launch"
echo "   - Test location permission prompts"
echo "   - Check Settings > Privacy & Legal links work"
echo ""
echo "6. Archive and Submit:"
echo "   a) In Xcode: Product > Archive"
echo "   b) Upload to App Store Connect"
echo "   c) Complete App Privacy questionnaire (see APP_STORE_COMPLIANCE.md)"
echo "   d) Add detailed App Review notes about background location"
echo ""
echo "📖 For detailed guidance, see: APP_STORE_COMPLIANCE.md"
echo ""
echo "⚠️  CRITICAL REMINDERS:"
echo "   • PrivacyInfo.xcprivacy MUST be in Xcode project (not just filesystem)"
echo "   • Privacy Policy URL must be publicly accessible"
echo "   • Test on real iOS device (simulator not sufficient)"
echo "   • Complete App Privacy section in App Store Connect accurately"
echo ""
echo "✨ Good luck with your submission!"
