# Sitirnati — سيترنتي

Flutter Android app for local **water-tanker delivery**, Arabic-first (RTL),
dark glass UI. No accounts, no login, no backend: a customer picks a driver
card, fills the order form, pins the drop-off on an in-app map, and the order
is stored locally on the phone under «طلبياتي» (my orders).

## Screens

| # | Screen | File | What it does |
|---|---|---|---|
| 1 | Browse (اطلب) | `lib/pages/browse_page.dart` | Water-type filter + driver cards (name, water type, price, volume). Tapping «اطلب الآن» opens the order form. |
| 2 | Orders (طلبياتي) | `lib/pages/orders_page.dart` | Saved orders, newest first, with a status badge. Empty state + skeleton loading. |
| — | Order form | `lib/widgets/order_form_sheet.dart` | Name, place, phone, map pin. Per-field validation. |
| — | Map picker | `lib/pages/map_picker_page.dart` | OpenStreetMap via `flutter_map`, CARTO `dark_all` tiles (no API key). Geolocation with every failure path handled in Arabic. |
| — | Success dialog | `lib/widgets/order_success_dialog.dart` | Animated confirmation: drawn check mark, order summary, «شوف طلبياتي». |

Shell: `lib/main.dart` → `lib/pages/home_shell.dart` (two tabs + the Liquid
Glass bottom bar).

## Structure

```
lib/
  main.dart                       App entry, system UI, glass engine flags
  models/                         Order, Truck (plain immutable classes)
  data/sample_trucks.dart         5 hardcoded drivers — the only fake data
  services/orders_store.dart      shared_preferences JSON persistence
  theme/app_theme.dart            ALL design tokens + ThemeData + backdrop
  utils/formatters.dart           prices, volumes (litres), dates, phone check
  widgets/
    glass_surface.dart            the single glass primitive (+ MetaChip)
    app_buttons.dart              PrimaryButton / SecondaryButton / GlassIconButton
    glass_morph_menu.dart         the morphing bottom bar wrapper
    truck_card.dart               driver card
    order_form_sheet.dart         order form modal
    order_success_dialog.dart     confirmation dialog
  pages/
    home_shell.dart               tabs, bar index mirroring, order flow
    browse_page.dart              tab 1
    orders_page.dart              tab 2
    map_picker_page.dart          map + geolocation
packages/
  liquid_glass_bottom_navbar_plus/  vendored fork of the Liquid Glass bar
test/                             widget, layout and golden tests
tool/                             contrast gate + golden pixel sampler (Node)
DESIGN.md                         design decisions and measured contrast
```

## Conventions (read before editing)

- **Tokens only.** Every colour, duration, radius and spacing value lives in
  `lib/theme/app_theme.dart`. Component files must not contain raw hex, raw
  `Duration` or magic radii. `AppColors` = primitives, named roles =
  semantic, components consume the semantic names.
- **One glass recipe.** All surfaces use `GlassSurface`
  (`lib/widgets/glass_surface.dart`): clipped `BackdropFilter` (blur +
  saturation) → translucent tint → top sheen → hairline rim. Cards, buttons,
  sheets and the dialog must look like the same material as the bottom bar.
- **Performance.** The home body is wrapped in a `BackdropGroup` and
  `GlassSurface` uses `BackdropFilter.grouped`, so all cards and buttons share
  one backdrop capture. Keep new glass inside that group unless it floats over
  moving content (bar, modal sheets, map page).
- **RTL + the bar.** The bar's selection-pill geometry is LTR-only, so the bar
  is wrapped in `Directionality(ltr)` and its items are ordered
  `[طلبياتي, اطلب]`; the page index is mirrored through `_barIndex` /
  `_pageForBarIndex`. Bar index 1 = the browse tab.
- **Volumes** are stored in cubic metres (`Truck.volumeM3`) because that is how
  drivers quote them, and displayed in litres with the unit word —
  `formatVolume(10)` → `10 000 لتر`. Never print `volumeM3` raw.
- **Motion** uses `AppMotion.micro / standard / entrance` and
  `AppMotion.enter / exit` only, and every animation is short-circuited by
  `MediaQuery.disableAnimationsOf(context)`.
- **Copy** is Algerian Darja, verbs first, no filler, no emoji as icons.
  Errors say what to do, not what failed.
- **No backend.** "Send to driver" means "saved on this phone as مُرسل"; the UI
  copy says so and must stay honest.

## Commands

```bash
flutter pub get
flutter analyze                                        # must be: No issues found!
flutter test                                           # 10 tests
node tool/contrast_check.mjs                           # 38/38 contrast pairs
node tool/sample_golden.mjs test/goldens/browse.png    # real pixels of the bar
flutter test --update-goldens test/visual_test.dart    # refresh goldens
flutter build apk --split-per-abi --release
```

Output: `build/app/outputs/flutter-apk/app-<abi>-release.apk`
(`arm64-v8a`, `armeabi-v7a`, `x86_64`). Install `arm64-v8a` on a modern phone.

Goldens are rendered at 1170×2532 with the real Tajawal loaded (the harness
default font reports false overflows).

## Release signing

`android/app/build.gradle.kts` reads `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
`KEY_PASSWORD` from the environment and signs with `keystore.jks`. The keystore
is **not in this repo** (see `.gitignore`); without the env vars the build falls
back to debug signing so a local build always succeeds. A debug-signed APK is
installable but not publishable.

## Requirements

Flutter 3.47+ / Dart 3.13+, JDK 17, Android SDK 36 (min SDK 24, target 35).
Node.js only for the `tool/` scripts.
