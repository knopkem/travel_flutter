# Xiaomi Device Troubleshooting Guide

## Issue: Location permission not working on Xiaomi 14T

### Changes Made
1. **Enhanced Permission Handling**: App now detects Xiaomi devices and uses `permission_handler` package for more reliable permission checks
2. **Xiaomi-Specific Location Settings**: Uses `forceLocationManager`, higher accuracy, and longer timeout
3. **Android Manifest Updates**: Added `ACCESS_LOCATION_EXTRA_COMMANDS` permission

### What User Must Do on Xiaomi Device

#### 1. Enable Location Services
- Go to **Settings** → **Location**
- Enable **Location Services**
- Set location mode to **High accuracy** (not Battery saving)

#### 2. Grant LocationPal Permissions
- Go to **Settings** → **Apps** → **Manage apps** → **LocationPal**
- **Permissions**:
  - Location: **Allow all the time** (not just "While using the app")
  - Physical activity: **Allow** (helps with location accuracy)
  
#### 3. Enable Autostart (Critical for Xiaomi!)
- Go to **Settings** → **Apps** → **Manage apps** → **LocationPal**
- Tap **Autostart**
- **Enable Autostart** toggle

Without autostart, Xiaomi devices kill background services aggressively.

#### 4. Disable Battery Optimization
- Go to **Settings** → **Battery & performance** → **Battery saver**
- Ensure **Battery saver** is OFF when using location features
- Or go to **Settings** → **Apps** → **Manage apps** → **LocationPal**
- Tap **Battery saver**
- Select **No restrictions**

#### 5. MIUI Security App
If the device has MIUI Security app:
- Open **Security** app
- Go to **Permissions**
- Find **LocationPal**
- Ensure all location-related permissions are granted

#### 6. Developer Options (Optional but Helpful)
- Enable **Developer Options**
- Go to **Settings** → **Additional settings** → **Developer options**
- Scroll to **Select mock location app**
- Make sure it's set to **None** (not LocationPal)

#### 7. GPS Settings
- Go to **Settings** → **Location**
- Tap the gear icon or **Location services**
- Ensure **Google Location Accuracy** is enabled
- Enable **Wi-Fi scanning** and **Bluetooth scanning**

### Testing Steps
1. **Completely uninstall** the old version of LocationPal
2. Restart the Xiaomi device
3. Install the new version
4. Open the app
5. When prompted for location permission, select **"Allow all the time"**
6. If permission dialog doesn't appear, manually grant permissions via Settings (see #2 above)
7. Tap the GPS button - it should show a foreground notification "Getting your location..."

### Common Xiaomi Issues

**Issue**: Permission dialog never appears
- **Solution**: Go to Settings and manually grant Location permission

**Issue**: GPS works once but stops working
- **Solution**: Check Autostart permission (#3 above)

**Issue**: "Location timeout" error
- **Solution**: 
  - Ensure GPS is enabled
  - Go outside or near a window for clear sky view
  - Disable Battery Saver
  - Check that location mode is "High accuracy"

**Issue**: App keeps asking for permission repeatedly
- **Solution**: This happens when Xiaomi revokes permissions. Enable Autostart and set Battery saver to "No restrictions"

### What Changed in the Code

#### AndroidManifest.xml
```xml
<!-- Added -->
<uses-permission android:name="android.permission.ACCESS_LOCATION_EXTRA_COMMANDS" />
```

#### LocationProvider.dart
- **Xiaomi Detection**: Checks manufacturer name (Xiaomi/Redmi/Poco)
- **Enhanced Permission Check**: Uses `permission_handler` package on Xiaomi devices for more reliable results
- **Xiaomi-Specific Location Settings**:
  - `LocationAccuracy.high` (not medium)
  - `forceLocationManager: true` (bypasses some MIUI restrictions)
  - 90-second timeout (vs 60 seconds on other devices)
  - Foreground notification during location fetch
- **Xiaomi-Specific Help Dialog**: Shows step-by-step instructions for enabling location services

### If Problem Persists

1. Check logcat output: `adb logcat | grep -i location`
2. Verify in Settings → Apps → LocationPal that:
   - Location permission = "Allow all the time"
   - Autostart = Enabled
   - Battery saver = "No restrictions"
3. Try disabling and re-enabling Location Services in system settings
4. Restart device after granting all permissions

### Known Limitations

Xiaomi/MIUI is one of the most restrictive Android manufacturers. Even with all permissions granted, MIUI may still:
- Kill background services after screen-off
- Revoke permissions silently
- Require user to manually whitelist the app in Security app

The changes made improve compatibility, but some restrictions are at the OS level and cannot be fully bypassed.
