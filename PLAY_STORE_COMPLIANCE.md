# Google Play Store Compliance Summary

## ✅ Android Manifest Status

Your [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) is **mostly compliant** but needs Play Store justifications for sensitive permissions:

### ✅ Properly Declared Permissions

| Permission | Status | Notes |
|-----------|--------|-------|
| `INTERNET` | ✅ Required | Standard permission |
| `ACCESS_FINE_LOCATION` | ✅ Required | Core feature - POI discovery |
| `ACCESS_COARSE_LOCATION` | ✅ Required | Fallback location |
| `POST_NOTIFICATIONS` | ✅ Required | Android 13+ notification permission |
| `RECEIVE_BOOT_COMPLETED` | ✅ Required | Restart geofence monitoring |
| `WAKE_LOCK` | ✅ Required | Keep service alive |
| `FOREGROUND_SERVICE` | ✅ Required | Background monitoring |
| `FOREGROUND_SERVICE_LOCATION` | ✅ Required | Location service type |

### ⚠️ Sensitive Permissions Requiring Play Store Justification

These permissions are **RESTRICTED** and require detailed justification in Play Store Console:

1. **`ACCESS_BACKGROUND_LOCATION`** (⚠️ CRITICAL)
   - **Required?**: Yes, for geofence-based shopping reminders
   - **Play Store Requirement**: Must complete declaration form
   - **What to write**: 
     > "LocationPal uses background location to send shopping reminders when users arrive near stores they've tagged. Users opt-in to this feature and can disable it anytime in Settings. Location data stays on device and is not shared with third parties."

2. **`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`** (⚠️ RESTRICTED)
   - **Required?**: Yes, for reliable geofence monitoring
   - **Play Store Requirement**: Must justify why battery optimization exemption is essential
   - **What to write**:
     > "Required to ensure location-based shopping reminders work reliably when app is in background. Android's battery optimization can prevent timely reminders, which defeats the core purpose of the app."

## ✅ In-App Compliance Implementation

### 1. ✅ First-Launch Disclosure Screen
**File**: [lib/screens/permissions_disclosure_screen.dart](lib/screens/permissions_disclosure_screen.dart)

Shows users:
- Why location permissions are needed (with specific use cases)
- Why notifications are needed
- Clear explanation of background location usage
- Links to Privacy Policy and Terms of Service
- Opt-in button (not dismissable - required for compliance)

### 2. ✅ Settings Screen Privacy Section
**File**: [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart)

Added "Privacy & Legal" section with:
- Link to Privacy Policy
- Link to Terms of Service
- Data collection transparency (location, notifications, device info)
- Toggle to disable background location
- Warning if privacy policy URL not configured

### 3. ✅ OnboardingService
**File**: [lib/utils/onboarding_service.dart](lib/utils/onboarding_service.dart)

Tracks whether disclosure was shown to prevent repeated displays.

### 4. ✅ Main App Integration
**File**: [lib/main.dart](lib/main.dart)

Shows disclosure screen on first launch before user can access the app.

## 🔴 TODO Before Play Store Submission

### Critical (Must Complete):

1. **Host Privacy Policy & Terms of Service**
   - Create a privacy policy (use a generator if needed: https://app-privacy-policy-generator.firebaseapp.com/)
   - Host it on a public URL (e.g., GitHub Pages, your website)
   - Update URLs in [lib/utils/onboarding_service.dart](lib/utils/onboarding_service.dart):
     ```dart
     static const String privacyPolicyUrl = 'https://YOURDOMAIN.com/privacy-policy';
     static const String termsOfServiceUrl = 'https://YOURDOMAIN.com/terms-of-service';
     ```

2. **Complete Play Store Data Safety Section**
   - Location data: Collected, stays on device, not shared
   - Device ID: Collected for app functionality
   - No personal info collected
   - No data shared with third parties

3. **Fill Sensitive Permissions Declaration Form**
   - Google Play Console will show a form for `ACCESS_BACKGROUND_LOCATION`
   - Provide clear justification (see above)
   - Upload screenshots showing the disclosure screen

4. **Test Permission Flows**
   - Install fresh app on Android 13+ device
   - Verify disclosure screen shows on first launch
   - Verify permission requests appear with proper context
   - Verify background location permission shows system dialog explaining impact

### Recommended (Before Launch):

5. **Add Privacy Policy to Play Store Listing**
   - Link in "Privacy Policy" field in Play Store Console
   - Same URL as in-app link

6. **Screenshot the Disclosure Screen**
   - Include in Play Store listing to show transparency
   - Helps with review process

7. **Update App Description**
   - Clearly mention location-based reminder feature
   - Emphasize data stays on device

8. **Test on Various Android Versions**
   - Android 10+ (background location permission added)
   - Android 11+ (one-time permission option)
   - Android 13+ (notification permission required)

## 📋 Play Store Review Checklist

Before submitting:

- [ ] Privacy Policy URL is live and accessible
- [ ] Terms of Service URL is live and accessible
- [ ] Updated URLs in `onboarding_service.dart`
- [ ] Tested first-launch disclosure flow
- [ ] Tested permission requests (location, notification, background)
- [ ] Verified Settings > Privacy & Legal links work
- [ ] Completed Data Safety section in Play Console
- [ ] Filled sensitive permissions declaration form
- [ ] Uploaded screenshots showing disclosure
- [ ] App description mentions location-based features
- [ ] Target audience NOT set to "Children"
- [ ] No misleading claims about privacy

## 🚨 Common Rejection Reasons - Avoided

✅ **Collecting location without disclosure** - Fixed with disclosure screen  
✅ **Missing privacy policy** - Added to settings and disclosure  
✅ **Background location without justification** - Clear explanation in disclosure  
✅ **No way to disable location** - Added toggle in settings  
✅ **Misleading permission requests** - Clear context provided  
✅ **Missing notification permission (Android 13+)** - Properly requested  
✅ **Battery optimization without justification** - Explained in settings with user consent

## 📞 Support & Resources

- **Privacy Policy Generator**: https://app-privacy-policy-generator.firebaseapp.com/
- **Play Store Policies**: https://support.google.com/googleplay/android-developer/answer/9888170
- **Location Permissions Guide**: https://developer.android.com/training/location/permissions
- **Data Safety Form**: https://support.google.com/googleplay/android-developer/answer/10787469

## ⚡ Quick Start Commands

Test the disclosure screen:
```bash
# Clear app data to trigger first-launch again
flutter run --release
# Or use debug menu in Settings to reset disclosure
```

Build release APK:
```bash
flutter build apk --release
```

Build App Bundle for Play Store:
```bash
flutter build appbundle --release
```

---

**Last Updated**: 2026-01-20  
**Status**: Ready for privacy policy URLs, then Play Store submission
