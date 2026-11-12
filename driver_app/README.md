# Sitirnati Driver — سيترنتي للسواقين

The driver half of Sitirnati: a separate Flutter Android app
(`com.sitirnati.driver`) that shares the Firebase project `sitirnati` with the
customer app in the repository root. The customer app is at `../`; the protocol
the two apps speak is documented in the root `README.md`.

## Run

```bash
flutter pub get
flutter analyze                 # must be: No issues found!
flutter build apk --split-per-abi --release
```

Output: `build/app/outputs/flutter-apk/app-<abi>-release.apk`.

## What a driver does

1. **Sign in or create an account.** Email + password, or the Google button.
   Sign-up asks for first name, last name, email, phone, password twice, the base
   point (map picker), the water grade carried (`صالح للشرب` /
   `غير صالح للشرب`), the load in litres and the price per load. The session is
   persisted by Firebase Auth, so reopening the app lands on the home screen.
2. **Go on shift.** The نشط switch writes `active` on `drivers/{uid}`; the
   customer app's board filters on that flag and the card disappears within a
   second of switching off.
3. **Work the pool.** Tab «الطلبات» lists every order with `driverUid == ''`:
   customer name, place, straight-line distance from the base point, terms, and
   accept / reject / show-on-Google-Maps. Accepting is the claim — the rules only
   let one driver win that race.
4. **Finish the job.** Tab «طلبياتي», segment جارية: call the customer, open
   their pin, «أنا قريب — بلّغ الزبون» (writes `nearAt`, which raises the
   customer's full-screen alert), then «تم إيصال الطلب» → confirm → the order
   moves to منتهية.

## Layout

```
lib/
  main.dart                     splash → session gate → profile gate → shell
  firebase_options.dart         public client config of project `sitirnati`
  models/driver_profile.dart    `drivers/{uid}` + the two water grades
  models/order.dart             the shared order schema (epoch-ms timestamps)
  services/driver_auth.dart     email/password + Google, session restore
  services/driver_store.dart    every read and write: profile, pool, claim, near, deliver,
                                plus the local "reject" memory
  pages/                        auth, sign up, incoming, my orders, edit profile, map picker, splash
  widgets/                      order card, profile form, status toggle, glass, buttons
  theme/app_theme.dart          ALL design tokens
  utils/                        formatters (price, litres, distance), geo, launchers
```

## Notes

- **No server.** The app talks to Firestore directly; `firestore.rules` in the
  repository root is the entire authorization model, and it is what stops one
  driver from touching another's order.
- **Distance** is crow-flies (`Geolocator.distanceBetween`), not a routed
  distance: no API key, no billing, and for "is this job worth taking?" it is the
  number a driver actually uses.
- **Location permission is optional.** The base point can always be pinned by
  hand on the map.
- **A rejected order is remembered on this phone only.** It stays available to
  every other driver.
- **The map** is OpenStreetMap via `flutter_map` with CARTO `dark_all` tiles — no
  API key anywhere in the project.
