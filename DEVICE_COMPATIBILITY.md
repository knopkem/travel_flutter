# Device Compatibility Guide

## Background Location Issues on Various Android Manufacturers

### Affected Devices
The app now automatically detects and provides guidance for devices from manufacturers known to have aggressive battery optimization:

- **Xiaomi** / Redmi / Poco (MIUI / HyperOS)
- **Huawei** / Honor (EMUI / Magic UI)
- **OnePlus** (OxygenOS / ColorOS)
- **Oppo** / Realme (ColorOS)
- **Vivo** (Funtouch OS)
- **Samsung** (One UI)
- **Sony** (Xperia)
- **Asus** (ZenUI)
- **Nokia** (Android One)
- And others

### Changes Made
1. **Automatic Device Detection**: App detects problematic manufacturers on startup
2. **Generic Optimization Handler**: Uses community-maintained dontkillmyapp.com guides
3. **Smart Permission Handling**: More reliable permission checks on restrictive devices
4. **Manufacturer-Specific Location Settings**: Higher accuracy, longer timeout for problematic devices
5. **Setup Prompts**: Shows manufacturer-specific guides when creating first shopping reminder

### What User Must Do (All Affected Devices)

#### 1. Enable Location Services
- Go to **Settings** → **Location**
- Enable **Location Services**
- Set location mode to **High accuracy** (not Battery saving)

#### 2. Grant LocationPal Permissions
- Go to **Settings** → **Apps** → **Manage apps** → **LocationPal**
- **Permissions**:
  - Location: **Allow all the time** (not just "While using the app")
  - Physical activity: **Allow** (helps with location accuracy)
  
#### 3. Enable Autostart (Critical!)
- Go to **Settings** → **Apps** → **Manage apps** → **LocationPal**
- Tap **Autostart** (Xiaomi/Oppo/Vivo) or **Battery** → **App launch** (Huawei)
- **Enable Autostart** toggle

Without autostart, these devices kill background services aggressively.

#### 4. Disable Battery Optimization
- Go to **Settings** → **Battery & performance** → **Battery saver**
- Ensure **Battery saver** is OFF when using location features
- Or go to **Settings** → **Apps** → **Manage apps** → **LocationPal**
- Tap **Battery saver**
- Select **No restrictions**

#### 5. Manufacturer Security App
- **Xiaomi**: MIUI Security app
- **Huawei**: Phone Manager app
- **Oppo/Realme**: Phone Manager
- **Vivo**: iManager

Open the security/manager app and ensure LocationPal has all location-related permissions granted.

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
2. Restart the device
3. Install the new version
4. Open the app - it will detect your device manufacturer
5. When prompted for location permission, select **"Allow all the time"**
6. If creating first shopping reminder, app will show manufacturer-specific setup guide
7. Follow the guide or tap "View Detailed Guide" for step-by-step instructions from dontkillmyapp.com
8. Tap GPS button - should show notification "Getting your location..."

### Common Issues (All Manufacturers)

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
- **Solution**: This happens when the device revokes permissions. Enable Autostart and set Battery saver to "No restrictions"

### What Changed in the Code

#### Device Optimization Helper (lib/utils/device_optimization_helper.dart)
**New centralized helper class for all problematic manufacturers:**
- Detects 18+ manufacturers known for aggressive battery optimization
- Links to dontkillmyapp.com manufacturer-specific guides
- Shows setup dialogs with manufacturer name and instructions
- Prompts before creating first shopping reminder
- Uses community-maintained compatibility information

#### AndroidManifest.xml
```xml
<!-- Added -->
<uses-permission android:name="android.permission.ACCESS_LOCATION_EXTRA_COMMANDS" />
```

#### LocationProvider.dart
- **Generic Device Detection**: Replaced Xiaomi-specific code with `DeviceOptimizationHelper.isProblematicDevice()`
- **Manufacturer-Agnostic Permission Check**: Works for all problematic devices
- **Smart Location Settings**: Problematic devices get:
  - `LocationAccuracy.high` (not medium)
  - `forceLocationManager: true` (bypasses some ROM restrictions)
  - 90-second timeout (vs 60 seconds)
  - Foreground notification during location fetch
- **Manufacturer-Specific Help**: Shows appropriate setup guide via `DeviceOptimizationHelper.showOptimizationGuide()`

#### POI Detail Screen
- **Pre-Reminder Check**: Before creating first shopping reminder, checks if device needs special setup
- **Interactive Setup Guide**: Shows manufacturer-specific instructions with link to detailed guide

### Supported Manufacturers in Detection

The app now automatically handles these manufacturers:
- Xiaomi, Redmi, Poco
- Huawei, Honor  
- OnePlus
- Oppo, Realme
- Vivo
- Samsung
- Sony
- Asus
- Meizu
- Letv
- Nokia (HMD Global)
- Lenovo
- ZTE
- Wiko

### If Problem Persists

1. Check logcat output: `adb logcat | grep -i location`
2. Verify in Settings → Apps → LocationPal that:
   - Location permission = "Allow all the time"
   - Autostart = Enabled
   - Battery saver = "No restrictions"
3. Try disabling and re-enabling Location Services in system settings
4. Restart device after granting all permissions

### Known Limitations

Many Android manufacturers implement aggressive battery optimization at the OS level. Even with all permissions granted, these systems may:
- Kill background services after screen-off
- Revoke permissions silently
- Require manual whitelisting in manufacturer-specific security apps
- Ignore standard Android permission APIs

The changes improve compatibility significantly, but some restrictions cannot be fully bypassed. Users must manually configure manufacturer-specific settings.

### Resources

- **dontkillmyapp.com** - Community-maintained guides for all manufacturers
- The app automatically links to the correct guide for your device
- Detailed step-by-step instructions with screenshots
