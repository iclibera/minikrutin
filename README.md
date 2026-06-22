# MinikRutin

**Bebek Beslenme, Uyku ve Sağlık Takip Uygulaması** — a calm, ad-free baby
journal for new parents. Track feeding, sleep, diapers, medicine & fever,
pumping, growth, vaccines and notes; see a daily dashboard and weekly trends;
and turn the last 7 days into a shareable doctor report (PDF).

Built from the MinikRutin pitch deck. iOS 17+, SwiftUI + SwiftData.

## Features

- **Bugün (Today):** last feeding/diaper, today's sleep & feeding totals, next reminder, recent records.
- **Hızlı kayıt:** one-tap feeding, sleep, diaper, medicine & fever, pumping, note.
- **Haftalık özet:** Swift Charts bar chart + averages; premium trend charts.
- **Doktor raporu:** 7/14/30-day summary exported as a shareable PDF (premium).
- **Gelişim:** growth (weight/height/head), vaccine & checkup log, photo memories (on-device).
- **Hatırlatmalar:** local notifications (vitamin D, medicine, checkups).
- **Aile paylaşımı:** invite caregivers via a code (premium).
- **Bulut yedekleme:** optional email/password account; local-first with Firebase sync.
- **Premium:** monthly/yearly auto-renewable subscription (StoreKit 2) with a 14-day free trial.

## Architecture

- **Local-first:** SwiftData is the on-device source of truth — the whole app works offline / without an account.
- **Cloud (optional):** Firebase **over REST** — Identity Toolkit (email/password auth) + Cloud Firestore (sync) using the project's API key and the user's ID token. No Firebase SDK is linked, keeping builds fast and archives clean.
- **Payments:** StoreKit 2 `SubscriptionStoreView` (Guideline 3.1.2(c)-compliant paywall).
- **Privacy:** minimal permissions (no location/camera/contacts), photos stay on-device, in-app account + data deletion, medical disclaimers throughout.

## Build

```bash
brew install xcodegen
xcodegen generate
open MinikRutin.xcodeproj
```

The Xcode project is generated from `project.yml` (not committed). Firebase
config is in `MinikRutin/Resources/GoogleService-Info.plist`. Firestore rules
live in `firestore.rules` (deploy with `firebase deploy --only firestore:rules`).

## Backend note

Firebase project: `minikrutin-app`. Email/Password sign-in must be enabled once
in the Firebase console (Authentication → Sign-in method) — basic auth on the
free Spark plan cannot be toggled via API. The app is fully functional locally
without it; cloud sync activates as soon as it is enabled.
