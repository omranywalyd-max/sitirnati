# Sitirnati — سيترنتي

Two Flutter Android apps for local **water-tanker delivery**, Arabic-first (RTL),
dark glass UI, one Cloud Firestore backend:

| App | Package | Folder | Who signs in |
|---|---|---|---|
| **Sitirnati** (customer) | `com.sitirnati.app` | repo root | nobody — an anonymous Firebase session is created on first launch |
| **Sitirnati Driver** | `com.sitirnati.driver` | `driver_app/` | a real account: email + password, or Google |

The customer picks a driver from a live **price board**, places an order, and
follows it. The driver signs up once (identity, contact, water grade, load size,
price, base point on the map), goes on shift, and works the orders that arrive.
When the driver is close they press «أنا قريب» and the customer's phone raises a
**full-screen alert over whatever is on screen** — locked phone included.

Both APKs share the Firebase project `sitirnati` (Firestore in `europe-west9`).

---

## How the two sides meet

There is no server, no dispatcher and no push sender. The whole protocol is one
document and one rule.

```
customer                    orders/{id}                      driver
   |                            |                              |
   |-- create, driverUid: "" -->|                              |
   |                            |<-- where driverUid == "" ----|   the pool
   |                            |                              |
   |                            |<-- update driverUid: <me>, ---|   the claim
   |                            |    driverName, driverPhone,   |   (first write wins)
   |                            |    terms, status: accepted    |
   |                            |                              |
   |                            |<-- nearAt: <epoch ms> --------|   "أنا قريب"
   |<-- listener sees nearAt ---|                              |
   |    full-screen alert       |                              |
   |                            |<-- status: delivered ---------|   "تم الإيصال"
```

* **The pool.** An order is created with `driverUid == ''` and belongs to nobody.
  Every registered driver reads it; the first one to write their own uid into it
  takes it. The rules make that race safe: a claim is only allowed while
  `driverUid` is still empty, so of two drivers accepting at the same moment
  exactly one write lands and the other gets `permission-denied` (the card
  shows «سبقك سائق»).
* **The price board is not a dispatch.** The customer sees the drivers who are
  on shift and what they charge; the order still goes to the pool, so a driver
  who goes offline right after the tap cannot strand the request.
* **"Reject" is local.** A dismissed order is remembered on the driver's phone
  (`shared_preferences`), never deleted — it stays available to everybody else.
* **"Near" without a server.** `nearAt` is an epoch-ms field on the order. The
  customer app watches it; the moment it turns non-null, a **native Android
  Activity** is started from the background (`DriverArrivalActivity`) so the
  alert covers other apps and the lock screen. That needs
  `SYSTEM_ALERT_WINDOW`, which the app asks for **before** the order is sent, and
  explains in Darja why. Without it the alert degrades to an in-app banner and
  the order still works.

---

## Screens

### Customer — `lib/`

| # | Screen | File | What it does |
|---|---|---|---|
| 1 | اطلب (browse) | `pages/browse_page.dart` | Live board of on-shift drivers, cheapest first: name, water grade, load, price, distance-free summary. «اطلب الآن» opens the order form. |
| 2 | طلبياتي (orders) | `pages/orders_page.dart` | This customer's orders, newest first, with status; call the driver, open the pin, cancel, delete from history. |
| — | Splash | `pages/splash_page.dart` | One 1200 ms brand sequence, then a cross-fade into the shell. |
| — | Order form | `widgets/order_form_sheet.dart` | Name, place, phone, map pin, the overlay-permission explainer, then the write. |
| — | Map picker | `pages/map_picker_page.dart` | OpenStreetMap via `flutter_map`, CARTO `dark_all` tiles (no API key). Every geolocation failure is handled in Arabic. |
| — | Success dialog | `widgets/order_success_dialog.dart` | Animated confirmation: drawn check mark, order summary, «شوف طلبياتي». |
| — | Arrival alert | `android/.../DriverArrivalActivity.kt` | The native full-screen "the driver is near" screen, with «اتصل» and «واخا». |

### Driver — `driver_app/lib/`

| # | Screen | File | What it does |
|---|---|---|---|
| 1 | Splash → gate | `main.dart`, `pages/splash_page.dart` | Waits for the persisted session, then shows the sign-in or the home screen. |
| 2 | Sign in / sign up | `pages/auth_page.dart`, `pages/sign_up_page.dart` | Email + password or Google; sign-up collects first name, last name, email, phone, password ×2, the base point from the map, water grade, load and price. |
| 3 | الطلبات (incoming) | `pages/incoming_page.dart` | The نشط / غير نشط switch, the morph menu (edit account, admin contact, sign out), and the pool cards: customer, place, distance from the driver's base, accept / reject / show on Google Maps. |
| 4 | طلبياتي (mine) | `pages/my_orders_page.dart` | Segments جارية / منتهية; call the customer, open their pin, «أنا قريب — بلّغ الزبون», «تم إيصال الطلب» → confirm → the order moves to منتهية. |
| — | Edit account | `pages/edit_profile_page.dart` | Same form as sign-up, pre-filled. |

Both shells use the vendored Liquid Glass bar (`packages/liquid_glass_bottom_navbar_plus/`)
with two tabs; the bar lays its items out LTR while Arabic reads RTL, so the item
list is ordered right-to-left and the page index is mirrored (`_barIndex`).

---

## Structure

```
lib/                              customer app
  main.dart                       entry, system UI, glass flags, splash → shell
  firebase_options.dart           public client config of project `sitirnati`
  models/order.dart               the shared order document (both apps' schema)
  models/driver_offer.dart        read-only projection of a driver profile
  services/auth_service.dart      the anonymous customer session
  services/orders_store.dart      Firestore reads/writes + on-device cache
  services/drivers_store.dart     the price board stream
  services/overlay_service.dart   the SYSTEM_ALERT_WINDOW channel
  theme/app_theme.dart            ALL design tokens + ThemeData + backdrop
  utils/formatters.dart           prices, volumes, dates, phone check
  widgets/                        glass primitive, buttons, cards, sheets, dialogs
  pages/                          shell, browse, orders, map picker, splash
  android/.../MainActivity.kt     the overlay MethodChannel
  android/.../DriverArrivalActivity.kt
                                  the full-screen arrival alert
driver_app/                       driver app — a separate Flutter project
  lib/services/driver_auth.dart   email/password + Google
  lib/services/driver_store.dart  profile writes, pool/mine streams, claim, near, deliver
  lib/models/driver_profile.dart  `drivers/{uid}`
  lib/models/order.dart           the same order schema, driver side
  lib/widgets/order_card.dart     the work card (accept, call, map, near, deliver)
  lib/pages/                      auth, sign up, incoming, my orders, edit, map picker
packages/
  liquid_glass_bottom_navbar_plus/  vendored fork of the Liquid Glass bar
tool/
  rules_e2e.mjs                   end-to-end check of the security rules (Node 18+)
  contrast_check.mjs              the contrast gate
  sample_golden.mjs               pixel sampler for the goldens
test/                             widget, layout and golden tests (customer app)
firestore.rules                   the whole authorization model
firebase.json / .firebaserc       deploy config for `firebase deploy --only firestore:rules`
DESIGN.md                         design decisions and measured contrast
```

---

## Backend

Firebase project `sitirnati`, two collections, no Cloud Functions.

### `drivers/{uid}` — the driver's record, and the customer's price board

| Field | Type | Meaning |
|---|---|---|
| `firstName`, `lastName` | string 1–40 | shown to the customer |
| `email` | string ≤ 120 | the account's address, never displayed |
| `phone` | string `0[567]\d{8}` | the number the customer calls |
| `lat`, `lng` | number | the driver's base point |
| `waterType` | string | `صالح للشرب` or `غير صالح للشرب` |
| `volumeM3` | int 1–100 | load in cubic metres (shown in litres) |
| `price` | int 0–1 000 000 | price per load, dinars |
| `active` | bool | on shift — the customer board filters on this |
| `createdAt`, `updatedAt` | int | epoch milliseconds |

### `orders/{id}` — one document, three writers

| Field | Type | Written by |
|---|---|---|
| `customerUid` | string = `request.auth.uid` | customer, once |
| `customerName`, `phone`, `placeName`, `lat`, `lng` | — | customer, once |
| `waterType`, `volumeM3`, `price` | — | customer at creation, driver at the claim (the deal that closes) |
| `driverUid`, `driverName`, `driverPhone` | string, empty until claimed | driver, once |
| `status` | `sent` → `accepted` → `delivered` (or `cancelled`) | driver; `cancelled` also by the customer |
| `createdAt`, `updatedAt` | int | epoch milliseconds |
| `nearAt` | int or null | driver, on «أنا قريب» |

Timestamps are **epoch milliseconds**, not `Timestamp`: both apps parse them
without a platform conversion, and a plain int sorts the same way in Firestore
and in Dart.

### The rules

`firestore.rules` is the entire authorization model, and it is the only thing
that makes the pool safe:

* `drivers/{uid}` — read by any signed-in user (the customer has no identity of
  their own to be matched against, and every field is an offer the driver chose
  to publish); written only by its owner, in one validated shape
  (`hasOnly` + bounds, so a document cannot be used as free storage); never
  deleted by a client.
* `orders/{id}` — create only by the customer who owns it, with the driver
  fields empty; read by the customer, by the claiming driver, and by any
  **registered** driver while `driverUid` is empty ("registered" = their
  `drivers/{uid}` document exists); update only along the three legal edges —
  claim (uid empty → mine), progress (mine, forward, or standing still for
  `nearAt`), cancel (customer's own); delete only by the customer.
* Everything else is denied by a catch-all.

**Verified, not assumed.** `tool/rules_e2e.mjs` signs in as a customer and as two
drivers against the live project and walks the whole lifecycle, including the
attacks the rules exist to stop:

```bash
node tool/rules_e2e.mjs        # 32/32 checks passed
```

It covers: a customer cannot pre-fill `driverUid`, write a malformed phone or a
negative price, read another customer's order or the pool, cancel somebody
else's order or revive a cancelled one; a driver cannot write someone else's
profile, publish a negative price, steal a claimed order, cancel a customer's
order, rewind a status, rewrite the terms after claiming, or delete an order;
and the legal paths — create → pool read → claim → `nearAt` → delivered → delete,
plus cancel → delete — all succeed.

### Offline behaviour

Both apps keep what they last saw on the device (`shared_preferences`) and paint
it before the network answers; Firestore's own queue holds writes made offline.
No query sorts on the server (`where` + `orderBy` would need a composite index),
so both apps sort in Dart and the project stays index-free.

---

## Conventions (read before editing)

- **Tokens by intent.** Every colour, duration, radius and spacing value lives in
  the app's `lib/theme/app_theme.dart` (each app has its own copy). `AppColors` =
  primitives, named roles = semantic, components consume the semantic names.
  A value used in more than one place **must** be a token. The exception that
  still exists in the code: an alpha tint used exactly once inside a single
  widget's glass recipe is written inline (`Color(0x0D5FD3E8)`); those are the
  56 remaining raw hexes and promoting them is the open hardening task — the
  colour values themselves are all in `app_theme.dart`, so nothing is a magic
  brand colour.
- **One glass recipe.** All surfaces use `GlassSurface`
  (`lib/widgets/glass_surface.dart`): translucent tint → top sheen → hairline
  rim, with an optional clipped `BackdropFilter` (blur + saturation) in front.
  Cards, buttons, sheets and the dialog must look like the same material as the
  bottom bar.
- **Performance — the blur is a budget, not a default.** `AppGlass.cardBlur` and
  `buttonBlur` are `0`: cards sit on an already-soft canvas, so a live backdrop
  blur over it is invisible but is paid for per card, per frame. Only surfaces
  that really float over moving content (the bar, sheets, the dialog, map
  panels — `AppGlass.sheetBlur`) keep a real frost. Don't raise `cardBlur`
  without profiling a release build first.
- **The canvas is painted once.** `GradientBackdrop` bakes its blurred cloud
  field into a small `ui.Image` and blits it. Keep it `const` and inside its
  `RepaintBoundary` so scrolling content never invalidates it.
- **RTL + the bar.** The bar's selection-pill geometry is LTR-only, so it is
  wrapped in `Directionality(ltr)`, its items are ordered right-to-left, and the
  page index is mirrored through `_barIndex` / `_pageForBarIndex`.
- **Volumes** are stored in cubic metres (`volumeM3`) because that is how drivers
  quote them, and displayed in litres with the unit word — `formatVolume(10)` →
  `10 000 لتر`. Never print `volumeM3` raw.
- **Motion** uses `AppMotion.micro / standard / entrance` and
  `AppMotion.enter / exit` only, and every animation is short-circuited by
  `MediaQuery.disableAnimationsOf(context)`.
- **Copy** is Algerian Darja, verbs first, no filler, no emoji as icons. Errors
  say what to do, not what failed.
- **`cloud_firestore` exports a class named `Order`.** Any file that imports
  both it and `models/order.dart` needs `hide Order`.
- **No secrets in the repo, no server in the repo.** The client API key in
  `google-services.json` / `firebase_options.dart` is public by design; the
  authorization model lives entirely in `firestore.rules` and must be deployed
  whenever it changes.
- **Google sign-in lives in `google-services.json`, not in Dart.** The driver
  app calls `GoogleSignIn.instance.initialize()` with no arguments; the Android
  plugin then reads the auto-generated `default_web_client_id` string resource
  that the `google-services` Gradle plugin bakes in from the **`oauth_client`
  entries** of that file. A file with `oauth_client: []` compiles, installs, and
  fails only at the moment a driver taps «دخول بـ Google»
  (`clientConfigurationError`). If that happens, re-download
  `google-services.json` from *Project settings → Your apps* — the console adds
  the OAuth clients once the app has a SHA-1 fingerprint registered (the debug
  keystore's is `D0:18:A9:5A:…:1C:55`; the release keystore needs its own).
  Both copies in this repo (`android/app/` and `driver_app/android/app/`) are
  byte-identical and must stay that way.

---

## Commands

```bash
# customer app (repo root)
flutter pub get
flutter analyze                                   # must be: No issues found!
node tool/contrast_check.mjs                      # the contrast gate
flutter build apk --split-per-abi --release

# driver app
cd driver_app
flutter pub get
flutter analyze                                   # must be: No issues found!
flutter build apk --split-per-abi --release
```

Output, for each app: `build/app/outputs/flutter-apk/app-<abi>-release.apk`
(`arm64-v8a`, `armeabi-v7a`, `x86_64`). Install `arm64-v8a` on a modern phone.

Deploying a rules change (needs the Firebase CLI, logged in):

```bash
firebase deploy --only firestore:rules
```

## Release signing

Both `android/app/build.gradle.kts` read `KEYSTORE_PASSWORD`, `KEY_ALIAS` and
`KEY_PASSWORD` from the environment and sign with the shared `keystore.jks` at
the repo root. The keystore is **not in this repo** (see `.gitignore`); without
the env vars the build falls back to debug signing so a local build always
succeeds. A debug-signed APK is installable but not publishable.

## Requirements

Flutter 3.47+ / Dart 3.13+, JDK 17, Android SDK 36 (min SDK 24, target 35).
Node.js 18+ only for the `tool/` scripts.
