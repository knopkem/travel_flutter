# Firebase Integration Setup

The app now uses Firebase Cloud Functions with Google Places API as the default POI provider, with automatic fallback to open-source providers.

## ✅ Completed Flutter Changes

1. **Added Firebase dependencies** to `pubspec.yaml`
2. **Created FirebaseService** (`lib/services/firebase_service.dart`) - handles anonymous authentication
3. **Created FirebasePlacesRepository** (`lib/repositories/firebase_places_repository.dart`) - calls Cloud Functions with fallback
4. **Updated main.dart** to initialize Firebase and use FirebasePlacesRepository as primary POI source
5. **Created firebase_options.dart** placeholder

## 🔧 Next Steps

### 1. Configure Firebase Project

Run this command to connect your Flutter app to your Firebase project:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (will update firebase_options.dart with your project details)
flutterfire configure
```

This will:
- List your Firebase projects
- Let you select which project to use
- Generate proper `firebase_options.dart` with your project credentials
- Configure iOS and Android apps in Firebase Console

### 2. Deploy Cloud Functions

The backend Cloud Functions need to be deployed to handle Google Places API requests.

Create `functions/src/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

const MONTHLY_QUOTA = 40000; // $200 free tier
const GOOGLE_PLACES_API_KEY = process.env.GOOGLE_PLACES_API_KEY;

exports.searchPlaces = functions.https.onCall(async (data, context) => {
  // 1. Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { latitude, longitude, radius, types } = data;
  const uid = context.auth.uid;
  const db = admin.firestore();
  const today = new Date();
  const month = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;

  // 2. Check monthly quota
  const quotaDoc = await db.collection('api_quotas').doc(month).get();
  const currentUsage = quotaDoc.data()?.usage || 0;

  if (currentUsage >= MONTHLY_QUOTA) {
    return {
      success: false,
      quotaExceeded: true,
      message: 'Monthly quota exceeded',
    };
  }

  // 3. Check per-user daily limit (50 requests/day)
  const userDailyDoc = db.collection('user_limits').doc(`${uid}_${month}_${today.getDate()}`);
  const userDay = await userDailyDoc.get();
  const userCount = (userDay.data()?.count || 0) + 1;

  if (userCount > 50) {
    throw new functions.https.HttpsError('resource-exhausted', 'Daily limit exceeded');
  }

  try {
    // 4. Call Google Places API (New API v1)
    const response = await axios.post(
      'https://places.googleapis.com/v1/places:searchNearby',
      {
        locationRestriction: {
          circle: {
            center: {
              latitude,
              longitude,
            },
            radius,
          },
        },
        includedTypes: types || [],
        maxResultCount: 20,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': GOOGLE_PLACES_API_KEY,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.types,places.priceLevel,places.photos,places.currentOpeningHours,places.internationalPhoneNumber,places.websiteUri',
        },
      }
    );

    // 5. Update counters
    await quotaDoc.ref.set({ usage: currentUsage + 1 }, { merge: true });
    await userDailyDoc.set({ count: userCount }, { merge: true });

    return {
      success: true,
      quotaExceeded: false,
      places: response.data.places || [],
    };
  } catch (error) {
    console.error('Places API error:', error);
    throw new functions.https.HttpsError('internal', 'API call failed');
  }
});

exports.getQuotaStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const today = new Date();
  const month = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
  const db = admin.firestore();
  
  const quotaDoc = await db.collection('api_quotas').doc(month).get();
  const used = quotaDoc.data()?.usage || 0;
  
  return {
    used,
    limit: MONTHLY_QUOTA,
    remaining: MONTHLY_QUOTA - used,
  };
});
```

Deploy functions:

```bash
cd functions
npm install firebase-functions firebase-admin axios
firebase deploy --only functions
```

Set your Google Places API key:

```bash
firebase functions:config:set places.api_key="YOUR_GOOGLE_PLACES_API_KEY"
firebase deploy --only functions
```

### 3. Configure Firestore Security Rules

In Firebase Console > Firestore > Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their own rate limit data
    match /user_limits/{document} {
      allow read, write: if request.auth != null 
        && document.startsWith(request.auth.uid);
    }
    
    // Allow authenticated users to read quota data
    match /api_quotas/{month} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

## 🎯 How It Works

1. **App starts** → Firebase initializes → Anonymous auth signs in
2. **User searches for POIs** → App calls `FirebasePlacesRepository`
3. **Repository tries Firebase Cloud Function first**:
   - ✅ If successful → returns Google Places results
   - ⚠️ If quota exceeded → falls back to open source providers
   - ❌ If error → falls back to open source providers
4. **Cloud Function**:
   - Checks monthly quota (40,000 requests)
   - Checks per-user daily limit (50 requests)
   - Calls Google Places API securely (API key never exposed to client)
   - Tracks usage in Firestore
5. **Fallback** → Uses existing `GooglePlacesRepository` with OSM/Wikipedia

## 🔒 Security

- API key stored only in Cloud Functions (never in app)
- Firebase Anonymous Auth identifies users
- Rate limits prevent abuse (50 req/day per user)
- Monthly quota prevents cost overruns ($200/month)
- App Check can be added for additional security

## 📊 Monitoring

Check quota usage in Firebase Console > Firestore > `api_quotas` collection.

Or add to your app:

```dart
final quota = await PlacesService.getQuotaStatus();
print('Used: ${quota['used']} / ${quota['limit']}');
```
