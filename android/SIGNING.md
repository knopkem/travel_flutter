# Android App Signing Setup

## Generate Upload Keystore

Run this command from the `android` directory:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You'll be prompted for:
- Keystore password (remember this!)
- Key password (remember this!)
- Your name, organization, location, etc.

## Configure Signing

1. Copy `key.properties.template` to `key.properties`
2. Edit `key.properties` with your actual passwords:
   ```properties
   storePassword=YOUR_ACTUAL_KEYSTORE_PASSWORD
   keyPassword=YOUR_ACTUAL_KEY_PASSWORD
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

## Build Release

```bash
# Build App Bundle for Play Store
flutter build appbundle --release

# Or build APK
flutter build apk --release
```

## Important Security Notes

⚠️ **NEVER commit these files to git:**
- `upload-keystore.jks`
- `key.properties`

✅ **Backup securely:**
- Store keystore and passwords in a password manager
- Keep encrypted backups in multiple secure locations
- If you lose the upload key, contact Google Play support

## Play App Signing

When uploading to Google Play Console for the first time:
1. Enroll in Play App Signing (Release → Setup → App Integrity)
2. Upload your first AAB
3. Google will manage the app signing key
4. You keep the upload key for future releases
