# Firebase setup for Rideality App

## 1. Create a Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a project named **Rideality**
3. Enable **Authentication** → Sign-in method → **Phone**
4. Enable **Storage** (for profile photos and driver documents)

## 2. Connect Flutter to Firebase

From the project root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This replaces `lib/firebase_options.dart` and downloads:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

After configure, set `isConfigured = true` in `firebase_options.dart` (FlutterFire usually does this automatically).

## 3. Android test numbers (optional)

For development without real SMS:

1. Firebase Console → Authentication → Phone → **Phone numbers for testing**
2. Add e.g. `+1 650 555 1234` with code `123456`

## 4. iOS extra step

Add your reversed client ID from `GoogleService-Info.plist` to URL schemes in Xcode if prompted by Firebase.

## 5. Run the app

```bash
flutter run
```

### Behavior

| Mode | Phone OTP | Image upload |
|------|-----------|--------------|
| Firebase not configured | Demo mode (any 4-digit code works) | Local pick + preview |
| Firebase configured | Real SMS via Firebase Auth | Uploads to Firebase Storage when signed in |

## 6. Storage rules (recommended)

```text
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /drivers/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```
