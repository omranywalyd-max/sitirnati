# Sitirnati — design decisions

Arabic-first (RTL), dark, glass. This file records what was chosen and why, so
the next change starts from the reasoning instead of the pixels.

## 1. Direction

| Facet | Decision |
|---|---|
| Product | Local water-tanker delivery, no accounts, no backend |
| Audience | Algerian households, one-handed phone use, mixed tech literacy |
| Style | Dark glass over a black→graphite gradient, one cyan accent |
| Density | Airy on browse (5 cards), dense inside an order card |
| Motion | Two curves, three durations, no decorative loops |
| Type | Tajawal (Regular 400 / Medium 500 / Bold 700) — an Arabic-first humanist sans with a tall x-height |

Deliberate anti-patterns avoided: no emoji as icons, no purple Material
defaults, no grey-on-grey secondary text, no hover-only affordance, no
placeholder "lorem" copy anywhere.

## 2. Tokens

All in `lib/theme/app_theme.dart`. Three tiers, in practice:

- **Primitives** — `AppColors.bgTop … bgBottom`, `accent`, `textPrimary/Secondary/Faint`.
- **Semantic** — `surfaceGlass` (cards), `surfaceSheet` (sheets/dialogs),
  `surfaceField`, `fieldBorder`, `glassBorder`, `divider`, `success/warning/danger`.
- **Component** — components read the semantic names only. No component file
  contains a raw hex, a raw duration, or a magic radius.

Spacing is a 4pt rhythm (`AppSpace.xs…huge`) plus `pageBottom = 132` so the
floating bar never covers the last card. Radii: chip 12, field 16, panel 22,
sheet 28. Motion: micro 140 ms, standard 240 ms, entrance 420 ms, curves
`AppMotion.enter` / `AppMotion.exit`.

Bar-specific tokens (`AppGlass`): `barTint` (the bar's smoked glass),
`barPill` (the selection capsule), `barSelected`, `barIdle`.

## 3. Contrast — measured, not eyeballed

`node tool/contrast_check.mjs` composites the translucent surfaces over the
canvas (source-over) and measures the real pair. It reads the 8-digit tokens as
`AARRGGBB`, matching `Color(0xAARRGGBB)`. Text is measured against the
*brightest* backdrop it can land on — two `0x8C5A5A64` clouds over `bgBottom`,
then the smoke sheet — not against the average.

Last run: **38/38 pairs pass**. The pairs that decide the design:

| Pair | Ratio | Needs |
|---|---|---|
| textFaint on canvas worst case | 4.62:1 | 4.5:1 |
| textFaint on card top sheen | 4.93:1 | 4.5:1 |
| field border on card | 4.36:1 | 3:1 |
| bar selected label on selection pill | 6.94:1 | 4.5:1 |
| bar idle label on bar glass | 16.22:1 | 4.5:1 |
| bar selection pill vs bar glass | 1.82:1 | 1.5:1 (self-imposed) |

The worst real pair is the field border at 4.36:1, still above the 3:1 WCAG 2.2
asks of a control boundary. The pill is not a text pair: it is a *shape*, so the
3:1 UI rule would not apply to a decorative highlight — it is held to a
self-imposed 1.5:1 so it reads as a distinct surface rather than a smudge. The
glass rim is decorative and is not held to 3:1 at all.

## 4. The glass

One recipe, `lib/widgets/glass_surface.dart`, used by cards, buttons, sheets,
the dialog and (by construction) the nav bar:

```
clip → BackdropFilter(blur σ + saturation 1.35) → translucent tint
     → top sheen 0x1AFFFFFF→0x00FFFFFF → hairline rim painted last
```

This mirrors the nav package's own `FallbackGlassLayer`, so the bar and
everything else are visibly the same material.

Cost control: the home body is wrapped in a `BackdropGroup` and every
`GlassSurface` inside it uses `BackdropFilter.grouped` — one backdrop capture
for all cards and buttons instead of one per widget. The bar, the modal sheets
and the map page sit outside the group (they float over content that moves
under them, and they are not on the same repaint path). Blur is skipped
entirely when `MediaQuery.disableAnimationsOf(context)` is true.

`LiquidGlassEngine.liteGlassOnSkia/OnImpeller = true`: this device family
returns opaque pixels from the Impeller glass shader, and lite glass (frost,
tint, painted rim, no shader pass) is both transparent and the cheapest path.
Lite glass also forces `LiquidGlassMorphMotion.plain` — a single spring morph,
which is the only honest render for a shader-free surface.

## 5. RTL and the bar

The bottom bar's selection-pill geometry is LTR-only, so the bar is wrapped in
`Directionality(textDirection: TextDirection.ltr)` and its item list is ordered
`[طلبياتي, اطلب]` — the first tab then renders on the *right*, where an Arabic
reader looks first. The page index is mirrored through `_barIndex` /
`_pageForBarIndex` so `IndexedStack` keeps a natural 0=browse, 1=orders. The
selected item is therefore bar index **1**.

Two overrides on the package:

- `glassColor = AppGlass.barTint` (`0x990C0C10`, 60% smoked) instead of the
  package's `0x30FFFFFF`. Measured from the golden: with a 19%-white tint the
  bar picked up the colour of whatever sat behind it (it went teal `#54747c`
  over an accent card), which made a faint capsule invisible at 1.24:1. A dark
  tint gives one stable material across bar/cards/buttons and a stable base for
  the 10.5px labels.
- `pillColor = AppGlass.barPill` (`0x425FD3E8`, 26% accent) instead of white.
  The selection is a *faint blue* wash, with `barSelected` (`0xFFB7ECF5`) for
  its icon and label.

Reading the golden with `tool/sample_golden.mjs` gives capsule `#2c4851` and the
idle slot `#284e57`. Those two are **not** comparable: each slot blurs different
content behind the bar, so the difference includes the backdrop, not just the
capsule. The capsule's own contrast is the analytic 1.82:1 above, where the
backdrop is held constant.

## 6. States covered

| Screen | Loading | Empty | Error | Success |
|---|---|---|---|---|
| Browse | cards reveal with an `Interval` stagger | filter with no match → reset action | — | — |
| Orders | skeleton rows (no layout shift) | icon + sentence + "اطلب ماء الآن" | — | the order is at the top of the list |
| Form | — | — | per-field message under the field; map missing → snackbar | sheet closes → success dialog |
| Map | "نقلب على موقعك" label on the button | "ما حددتش الموقع بعد" + instruction | every geolocation failure path (service off, denied, denied forever, timeout) has its own Arabic sentence | pin animates in |
| Success dialog | — | — | — | drawn check mark + order summary + "شوف طلبياتي" |

Disabled states are real: the confirm button on the map is disabled until a
point exists, and the primary button blocks taps while busy.

### The success dialog

`showOrderSuccessDialog` (`lib/widgets/order_success_dialog.dart`) is a
`showGeneralDialog`, not a Material `AlertDialog`: it renders a `GlassSurface`
so the confirmation is the same material as the card that opened it, in the
app's own accent, with a non-dismissible barrier (`0xB8000000`).

- **Route entrance** — fade + slide 4.5% + scale 0.93→1 on `AppMotion.enter`.
- **Mark** — one 760 ms controller drives three staged animations: the disc
  scales `Interval(0, 0.45, easeOutBack)`, a radial halo blooms
  `Interval(0.1, 0.8)`, and the check stroke is drawn by a `CustomPainter`
  using `PathMetric.extractPath` on `Interval(0.3, 1, easeOutCubic)`. One
  gesture, not three unrelated fades.
- **Ordering** — the order is written to storage *before* the dialog opens, so
  dismissing it loses nothing; it returns `true` only for "شوف طلبياتي".
- **Reduced motion** — `disableAnimationsOf` makes the route instant and jumps
  the controller to its finished frame.

## 7. Accessibility

- Text floor is 4.5:1 everywhere (measured above); UI boundaries ≥ 3:1.
- Every interactive target is ≥ 48dp (`test/layout_test.dart` asserts the
  primary button height).
- Every icon-only control has a `tooltip` that doubles as its semantic label.
- Status is never colour alone: each badge carries an icon **and** an Arabic
  word, and the selected filter chip carries a check mark.
- Cards expose one composed semantic label (driver, water, volume, price,
  action) instead of four fragments — and the volume is spoken as
  «10 000 لتر», not «10».
- The dialog is a named route (`namesRoute: true`, label «تم تسجيل الطلبية») so
  a screen reader announces where focus landed.
- `MediaQuery.withClampedTextScaling(0.9, 1.6)` keeps a 2x system setting from
  destroying the layout while still honouring large text.
- `MediaQuery.disableAnimationsOf` short-circuits the card reveal and the
  dialog, so "remove animations" is respected rather than merely slowed.

## 8. Copy rules used

Algerian Darja, verbs first, no filler. "اطلب الآن", not "إرسال". Errors say
what to do, not what failed: «خدمة الموقع مطفية. شغّلها من إعدادات الهاتف، ولا
حدد مكانك بصباعك.» The submit footnote is honest about the absence of a
backend: «الطلبية تتسجل في «طلبياتي» على هذا الهاتف بحالة مُرسل.»

Numbers are written the way a customer says them: a volume is `10 000 لتر`
(number first, then the unit word), not `10 م³`. The tank size is stored in
cubic metres because that is how drivers quote it; the conversion happens once,
in `formatVolume` (`lib/utils/formatters.dart`), and every screen — card chip,
form summary, dialog, semantic label — shows the same string.

## 9. Verification

```powershell
node tool/contrast_check.mjs                     # 38/38 pairs
flutter analyze                                  # No issues found!
flutter test                                     # 10/10 tests
flutter test --update-goldens test/visual_test.dart   # refresh test/goldens
flutter build apk --split-per-abi --release
```

Goldens (`browse.png`, `orders_empty.png`, `order_form.png`,
`order_success.png`) are rendered at 1170×2532 with the real Tajawal loaded, so
they show the shipped type metrics rather than the harness default font.
`node tool/sample_golden.mjs test/goldens/browse.png` prints the real pixel
colours of the bar, capsule, canvas and card.
