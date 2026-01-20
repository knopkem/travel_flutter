# App Store Connect Configuration Guide

## 📱 Complete App Privacy Questionnaire Responses

### Section 1: Data Collection

#### Question: "Does your app collect data from this app?"
**Answer:** YES

---

### Section 2: Data Types Collected

#### ✅ Location - Precise Location

**Question:** "Does this app collect precise location data?"  
**Answer:** YES

**Follow-up Questions:**

1. **Is the precise location data linked to the user's identity?**  
   **Answer:** NO
   
2. **Do you or your third-party partners use precise location data for tracking purposes?**  
   **Answer:** NO
   
3. **For what purposes do you collect precise location data?**  
   **Select:** App Functionality
   
   **Description Field:**
   ```
   LocationPal uses precise location to:
   • Show nearby points of interest and attractions on the map
   • Send shopping reminders when you arrive near stores in your reminder list
   • All location processing happens locally on your device
   • Location data is never transmitted to servers or shared with third parties
   ```

#### ✅ Identifiers - Device ID

**Question:** "Does this app collect device IDs?"  
**Answer:** YES

**Follow-up Questions:**

1. **Is the device ID linked to the user's identity?**  
   **Answer:** NO
   
2. **Do you or your third-party partners use device ID for tracking purposes?**  
   **Answer:** NO
   
3. **For what purposes do you collect device IDs?**  
   **Select:** App Functionality
   
   **Description Field:**
   ```
   Device identifier is used solely to:
   • Store user preferences and app settings locally
   • Manage app state and configuration
   • Not used for tracking, advertising, or analytics
   ```

#### ❌ Other Data Types

For all other data types (name, email, photos, purchases, browsing history, etc.):  
**Answer:** NO

---

### Section 3: Third-Party Data Collection

#### Question: "Do third-party partners have access to data from this app?"

**Answer:** NO (for advertising/tracking)

**Clarification:** While the app uses third-party APIs (Wikipedia, Google Places, OpenStreetMap), none of these services receive personally identifiable information or use the data for tracking/advertising purposes. API requests are made on behalf of the app for functionality only.

---

### Section 4: Usage Tracking

#### Question: "Do you or your third-party partners track users across apps and websites?"

**Answer:** NO

---

## 📝 App Information Fields

### General Information

**App Name:** LocationPal

**Subtitle (30 chars):**  
```
Travel companion & POI discovery
```

**Category:**  
**Primary:** Travel  
**Secondary:** Productivity

**Content Rights:**  
Select: "Does not contain third-party content"  
Note: Wikipedia/OSM content is properly attributed

---

### What's New (Version 1.0)

```
Welcome to LocationPal! 🌍

• Discover nearby attractions, restaurants, and stores
• Create shopping reminders for store chains
• Get notified when near stores on your list
• Browse Wikipedia articles about places
• Interactive map with points of interest

Your privacy matters:
• Location data stays on your device
• No tracking or advertising
• Complete control over your data
```

---

### Description (4000 chars max)

```
LocationPal - Your Intelligent Travel Companion

DISCOVER PLACES AROUND YOU
Explore nearby attractions, restaurants, stores, and points of interest wherever you go. LocationPal uses your location to show you what's interesting nearby, making every trip an adventure.

SMART SHOPPING REMINDERS
Never forget your shopping list again! Tag stores with your shopping items, and LocationPal will remind you when you're near any location of that brand. Perfect for busy lives and spontaneous errands.

KEY FEATURES:
• Real-time discovery of nearby places
• Interactive map with multiple point of interest types
• Shopping reminders with location-based notifications
• Wikipedia integration for detailed place information
• Multiple data sources (OpenStreetMap, Wikidata, Google Places)
• Customizable POI preferences
• Background location reminders (optional)

PRIVACY FIRST:
• Location data processed locally on your device
• No tracking or advertising
• Complete transparency about data usage
• User control over all features
• Open source third-party attributions

HOW IT WORKS:
1. Allow location access to see nearby places
2. Browse attractions, restaurants, and stores on the map
3. Add stores to your reminder list with shopping items
4. Get notified when you're near any location of that brand
5. Explore Wikipedia articles about places you visit

OPTIONAL BACKGROUND LOCATION:
Enable background location for shopping reminders to work even when the app is closed. This feature is completely optional and can be disabled anytime in Settings.

DATA SOURCES:
• Wikipedia - Free knowledge about places
• OpenStreetMap - Community-maintained map data
• Wikidata - Structured data about the world
• Google Places - Comprehensive business information

Whether you're exploring a new city or running errands in your hometown, LocationPal helps you discover places and remember tasks when it matters most.

Your feedback matters! Contact us at knopkem@gmail.com
```

---

### Keywords (100 chars max, comma-separated)

```
travel,poi,places,nearby,map,shopping,reminders,location,attractions,wikipedia,explore,discover
```

---

### Support URL

```
https://YOUR_DOMAIN/docs/
```
*(Or link to GitHub repository)*

---

### Marketing URL (Optional)

```
https://YOUR_DOMAIN/locationpal
```
*(If you have a landing page)*

---

### Privacy Policy URL

```
https://YOUR_DOMAIN/docs/policy.html
```

---

## 🖼️ App Screenshots Requirements

### iPhone (Required - 3 to 10 screenshots)

**6.5" Display (1284 x 2778 px)** - iPhone 14 Pro Max, 13 Pro Max, 12 Pro Max, 11 Pro Max

**Suggested Screenshots:**

1. **Map View** - Show POIs on map with location marker
   - Caption: "Discover nearby places on an interactive map"

2. **POI List** - Show list of nearby attractions/restaurants
   - Caption: "Browse attractions, restaurants, and stores"

3. **Disclosure Screen** - Show permissions disclosure (proves transparency)
   - Caption: "Your privacy matters - complete transparency"

4. **Shopping Reminder** - Show reminder creation screen
   - Caption: "Create shopping lists for your favorite stores"

5. **Settings** - Show privacy settings and controls
   - Caption: "Full control over your data and features"

6. **Wikipedia View** - Show Wikipedia article integration
   - Caption: "Learn about places with Wikipedia integration"

### iPad (Optional but Recommended)

**12.9" Display (2048 x 2732 px)** - iPad Pro

Create similar screenshots optimized for iPad layout.

---

## 👤 Age Rating

### App Store Rating: 4+

**Questionnaire Responses:**

- Cartoon/Fantasy Violence: None
- Realistic Violence: None
- Prolonged Graphic Violence: None
- Sexual Content: None
- Nudity: None
- Profanity: None
- Crude Humor: None
- Horror/Fear: None
- Mature/Suggestive Content: None
- Alcohol/Drugs: None
- Gambling: None
- Medical/Treatment Info: None
- Unrestricted Web Access: No
- Gambling & Contests: No
- Location Services: **YES** ⚠️

**Location Services Note:**  
Select "YES" and explain:
```
The app uses location services to show nearby points of interest and send shopping reminders when users arrive near stores. This is a core feature of the app.
```

---

## 🔐 Export Compliance

### Does your app use encryption?

**Answer:** YES (all apps use HTTPS)

### Is your app exempt from encryption export requirements?

**Answer:** YES

**Reason:** App uses standard encryption for HTTPS connections to Wikipedia and Google Places APIs. Qualifies for encryption export exemption under Category 5, Part 2.

---

## 📋 App Review Information

### Contact Information

**First Name:** [Your First Name]  
**Last Name:** [Your Last Name]  
**Phone:** [Your Phone Number]  
**Email:** knopkem@gmail.com

### App Review Notes (Critical!)

```
BACKGROUND LOCATION JUSTIFICATION:

LocationPal uses background location exclusively for shopping reminder notifications. Here's how it works:

FEATURE DESCRIPTION:
Users can tag stores (e.g., Walmart, Target, Whole Foods) with shopping lists. When they come near any location of that brand, they receive a reminder notification about their shopping items.

WHY BACKGROUND LOCATION IS NECESSARY:
• Reminders must work even when app is closed or not in use
• Users often don't have the app open when running errands
• Geofence monitoring requires background location capability
• This is the core value proposition of the app

USER CONTROL & TRANSPARENCY:
• Users explicitly opt-in to background location during setup
• Feature is fully optional and can be disabled in Settings
• Detailed disclosure screen shown before permission request
• Clear explanations in Settings > Shopping Reminders
• Users can view/edit/delete all reminders anytime

PRIVACY COMMITMENT:
• Location data processed locally on device only
• No transmission to servers or third parties
• No tracking or advertising purposes
• Not used to build user profiles
• Complies with Apple's location best practices

TESTING INSTRUCTIONS:
1. Install app - see disclosure screen explaining permissions
2. Navigate to map and find a commercial POI (store/restaurant)
3. Tap POI and select "Add Reminder"
4. Add shopping items to the list
5. Enable background location when prompted
6. Move away from store and return - notification appears

The app provides genuine utility for users who want location-based shopping reminders without tracking or advertising.

Thank you for your review!
```

### Demo Account

**Username:** (Not required for LocationPal)  
**Password:** (Not required for LocationPal)

**Note:** Demo account is not needed as the app doesn't require login and all features are accessible immediately after granting permissions.

---

## 🎯 Version Release Options

### Release Method

**Recommended:** Manual release

**Reason:** Allows you to verify app is working after approval before making it public.

### Phased Release

**Recommended:** NO (for first version)

**Reason:** Get immediate feedback from all users to identify any issues quickly.

---

## ✅ Pre-Submission Checklist

Before clicking "Submit for Review":

- [ ] All screenshots uploaded (iPhone required, iPad recommended)
- [ ] Privacy Policy URL is live and accessible
- [ ] Support URL is working
- [ ] App Privacy questionnaire completed accurately
- [ ] Age rating answers provided
- [ ] Export compliance completed
- [ ] App Review notes include detailed background location justification
- [ ] Keywords set (max 100 chars)
- [ ] Description compelling and accurate
- [ ] What's New text ready
- [ ] Build uploaded from Xcode
- [ ] PrivacyInfo.xcprivacy included in build
- [ ] Tested on physical device (not simulator)
- [ ] All app metadata in correct language
- [ ] Contact information correct
- [ ] Copyright info provided

---

## 🚀 After Submission

### Typical Timeline

- **Initial Review:** 24-48 hours
- **If Rejected:** Address issues and resubmit within 24 hours
- **Second Review:** Usually faster (12-24 hours)
- **If Approved:** Can release immediately or schedule

### Monitoring Status

Check App Store Connect regularly:
- "Waiting for Review" - In queue
- "In Review" - Actively being reviewed
- "Pending Developer Release" - Approved! Ready to release
- "Rejected" - Check Resolution Center for details

### If Rejected

1. Read rejection reason carefully in Resolution Center
2. Address the specific concern
3. Reply in Resolution Center explaining your fix
4. Resubmit - shows you're responsive

---

## 📞 Support Resources

- **App Review:** https://developer.apple.com/contact/app-store/?topic=review
- **Privacy Help:** https://developer.apple.com/support/app-privacy/
- **Guidelines:** https://developer.apple.com/app-store/review/guidelines/

---

**Last Updated:** 2026-01-20
