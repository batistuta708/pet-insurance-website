# Pet Insurance – Flutter app

Native Android/iOS app for the Pet Insurance service. It talks to the Flask
backend in the parent folder through its JSON API (`/api/v1`).

**Screens:** log in / create account · My Pets (add a pet with a live price quote, remove a pet) ·
Claims (list with status, submit a new claim) · Account (log out, privacy policy, delete account).

```
mobile/
├── lib/
│   ├── main.dart                # App, theme, AuthGate (login vs home)
│   ├── config.dart              # API base URL (override with --dart-define)
│   ├── api/api_client.dart      # All HTTP calls + error handling
│   ├── api/models.dart          # User, Pet, Policy, Claim, Quote
│   ├── state/session.dart       # Who is logged in; token in secure storage
│   ├── screens/                 # login, home (tabs), pets, add pet, claims, new claim, account
│   └── widgets/common.dart      # Error/empty states, error snackbars
├── test/                        # API client + widget tests
└── android/app/src/debug/AndroidManifest.xml   # lets debug builds call http://10.0.2.2
```

## 1. One-time setup

1. Install Flutter (stable): https://docs.flutter.dev/get-started/install — then run `flutter doctor`
   and fix what it reports (Android Studio + an Android emulator is the easiest start).
2. Generate the Android/iOS platform folders (this keeps every file already here):

   ```bash
   cd mobile
   flutter create --org com.yourname --project-name pet_insurance --platforms android,ios .
   flutter pub get
   ```

   Replace `com.yourname` with something unique to you (e.g. `com.batistuta`). The final app ID becomes
   `com.yourname.pet_insurance`, **and it can never change once published on Google Play.**

3. Open `android/app/src/main/AndroidManifest.xml` and:
   - add `<uses-permission android:name="android.permission.INTERNET"/>` just above `<application`
     (release builds need it to reach your server);
   - change `android:label="pet_insurance"` to `android:label="Pet Insurance"`.

## 2. Run it against your local Flask server

Terminal 1, project root:

```bash
python run.py                      # serves http://127.0.0.1:5000
```

Terminal 2:

```bash
cd mobile
flutter run                        # Android emulator: uses http://10.0.2.2:5000/api/v1 by default
```

On a **real phone** on the same Wi-Fi, start Flask with `flask --app run run --host 0.0.0.0` and run
`flutter run --dart-define=API_BASE_URL=http://<your-computer's-LAN-IP>:5000/api/v1`.

Tests: `flutter test` (app) and `pytest` (backend, from the project root).

## 3. Put the backend online (required before Play)

The released app must talk to a public **HTTPS** server. For example, on Render:

- New Web Service from the GitHub repo, start command `gunicorn run:app`
- Environment variables: `SECRET_KEY` (long random string) and `DATABASE_URL` (Render PostgreSQL;
  add `psycopg2-binary` to `requirements.txt`). SQLite on a free host is wiped on every redeploy.
- Check `https://<your-app>/privacy` loads; Play asks for that URL.

## 4. Build for Google Play

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<your-app>/api/v1
```

Before the first release build, create an upload key and configure signing, following
https://docs.flutter.dev/deployment/android#sign-the-app (keep the `.jks` file and its passwords
safe and out of git; they're already in `.gitignore`).
Also replace the default Flutter launcher icon (e.g. with the `flutter_launcher_icons` package).

Then in the Google Play Console (https://play.google.com/console, one-time USD 25 registration):

1. Create app → upload `build/app/outputs/bundle/release/app-release.aab` to **Internal testing** first.
2. Fill in the store listing (description, 512×512 icon, feature graphic, phone screenshots).
3. App content: privacy policy URL, Data safety form (email, pet details and claims are collected,
   sent encrypted, deletable in-app), content rating, target audience, ads = none.
4. **Account deletion:** the app has it under Account → Delete account; Play also asks for a web link
   where users can request deletion — the privacy page's contact email can serve as that for now.
5. New personal developer accounts must run a **closed test with at least 12 testers for 14 days**
   before they can apply for production access.

> ⚠️ Google Play treats insurance as a financial service. If this is a demo/portfolio project, say so
> clearly in the app and store listing (e.g. "Demo app – no real insurance is provided") to avoid a
> rejection for unlicensed financial services.
