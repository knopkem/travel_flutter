# Location Diagnostics Guide

## For Testing GPS Issues on Problematic Devices

### How to Run Diagnostics

1. **Open the app** in debug mode (development build)
2. **Navigate to**: Main Menu → Settings → Privacy & About
3. **Scroll down** to find "Run Location Diagnostics" (orange bug icon)
4. **Tap** to start the diagnostic tests
5. **Wait** up to 45 seconds while tests run
6. **Review** the results in the JSON output

### What the Diagnostics Test

#### Device Information
- `manufacturer`: Device maker (Xiaomi, Huawei, etc.)
- `model`: Specific device model
- `sdk`: Android SDK version
- `release`: Android version number
- `isProblematicDevice`: Whether device is on the problematic list

#### Location Service Status
- `locationServiceEnabled`: Whether GPS/location is enabled in system settings

#### Permission Status
- `geolocatorPermission`: Permission status from Geolocator package
- `permissionHandlerStatus`: Permission status from permission_handler package

#### Location Tests

**Test 1: Last Known Position**
- Fastest method, uses cached location
- `status`: success/null/error
- If success, shows lat/lng/accuracy/timestamp

**Test 2: Standard getCurrentPosition**
- Uses default Android location method
- High accuracy, 15-second timeout
- Shows if standard Android GPS works

**Test 3: Force Location Manager**
- Uses `forceLocationManager: true`
- Critical for MIUI/EMUI devices
- Shows if forcing location manager helps

**Test 4: Best Accuracy**
- Uses maximum accuracy setting
- Tests GPS precision capability

### Interpreting Results

#### If ALL tests show "success"
✅ GPS is working properly
- Issue is likely in app logic or UI
- Check that map screen is showing location updates

#### If Test 1 works but others "timeout"
⚠️ GPS not getting fresh signal
- **Cause**: Device is indoors or GPS signal blocked
- **Solution**: Move outside, wait for GPS lock
- **Xiaomi specific**: Check "High accuracy" mode enabled

#### If Test 3 works but Test 2 fails
⚠️ Standard GPS blocked by manufacturer ROM
- **Cause**: MIUI/EMUI restricting standard location access
- **Solution**: App is correctly using forceLocationManager
- **Check**: Battery optimization disabled, autostart enabled

#### If ALL tests show "error"
❌ GPS completely blocked
- **Check permissions**:
  - Location: "Allow all the time"
  - "Use precise location" enabled
- **Check settings**:
  - Location Services ON
  - Location Mode: "High accuracy"
  - Battery optimization: OFF
  - Autostart: ON (Xiaomi/Huawei/Oppo)

#### If "permissionHandlerStatus" is "denied"
❌ Permission not granted properly
- **Fix**: Go to Settings → Apps → LocationPal → Permissions
- Grant "Location" → "Allow all the time"

#### If "locationServiceEnabled" is false
❌ GPS disabled in system settings
- **Fix**: Settings → Location → Enable

### Common Error Messages

**"PlatformException(ERROR_LOCATION_SERVICES_DISABLED)"**
- Location services turned off in system settings
- Enable in Settings → Location

**"TimeoutException"**
- GPS couldn't get signal in time
- Move outside with clear view of sky
- On Xiaomi: Ensure "High accuracy" mode

**"PermissionDeniedException"**
- Permission not granted or revoked
- Check app permissions in system settings

**"LocationServiceDisabledException"**
- GPS hardware disabled or unavailable
- Restart device and try again

### Sharing Diagnostics

When reporting GPS issues:
1. Run the diagnostics
2. Copy the full JSON output
3. Include in bug report with:
   - Device manufacturer and model
   - Android version
   - Which location tests passed/failed
   - Any error messages

### For Developers

The diagnostics are only visible in debug builds (`kDebugMode`).

To add more tests, edit:
```dart
lib/utils/device_optimization_helper.dart
static Future<Map<String, dynamic>> runLocationDiagnostics()
```

Debug logs are also printed to console with prefix:
```
LocationProvider: [message]
```

Use `adb logcat | grep "LocationProvider"` to see real-time logs.
