# SM Baza Prawa

<p align="center">
  <img src="logo.jpg" alt="SM Baza Prawa" width="160" />
</p>

iOS app for searching Polish and EU legal acts, court judgments, and legislative processes — in one place.

> Akty polskie i unijne, orzeczenia sądowe oraz procesy legislacyjne w jednym miejscu.

## Features

- Search Polish acts, EU law, and judgments (common courts, Supreme Court, administrative courts)
- Legislative process tracking (Sejm, government)
- Global (“everywhere”) search across sources
- Favourites and saved acts
- Personalized alerts with push notifications (Premium)
- Sign in with Apple and subscription management via StoreKit

## Requirements

- Xcode (recent stable)
- iOS 18.0+
- Apple Developer account (for device runs, push, and In-App Purchases)
- Firebase project (Auth, Firestore, Storage, FCM, App Check)
- PostHog project (analytics; set your project API key in the app)

## Project layout

```
Baza Prawna/          # SwiftUI iOS app (Xcode project)
smbp-backend/         # Python Cloud Run job for alert scheduling / FCM
```

## Getting started (iOS)

1. Open `Baza Prawna/Baza Prawna.xcodeproj` in Xcode.
2. Add your `GoogleService-Info.plist` (not committed) and configure signing.
3. Set a PostHog project API key in `Baza_PrawnaApp.swift` (replace any placeholder).
4. Configure StoreKit / the included `.storekit` file for local subscription testing.
5. Build and run on a simulator or device.

## Backend (alerts)

`smbp-backend` is a Python job (Firebase Admin + Firestore) deployed as a Cloud Run job. It checks premium users’ alerts and sends FCM notifications.

Secrets such as `firebase-service-account.json` and `env-vars.txt` are gitignored — never commit them.

```bash
cd smbp-backend
pip install -r requirements.txt
# Configure credentials via env / service account, then run the scheduler as documented in your deploy scripts
```

## Privacy & contact

- Privacy policy: [baza-prawna.pl/polityka-prywatnosci.html](https://baza-prawna.pl/polityka-prywatnosci.html)
- Email: [bazaprawna.pl@gmail.com](mailto:bazaprawna.pl@gmail.com)

## License

This project is licensed under the [MIT License](LICENSE).
