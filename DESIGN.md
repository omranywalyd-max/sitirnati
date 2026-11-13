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
clip → [BackdropFilter(blur σ + saturation 1.35)] → translucent tint
     → top sheen 0x1AFFFFFF→0x00FFFFFF → hairline rim painted last
```

This mirrors the nav package's own `FallbackGlassLayer`, so the bar and
everything else are visibly the same material.

### Where the blur went, and why

The blur is a bracket in that pipeline because it is **off by default**
(`AppGlass.cardBlur = 0`, `AppGlass.buttonBlur = 0`). A card sits on the canvas,
and the canvas is already soft — a baked, blurred cloud field (see below). The
backdrop behind a card is therefore *already* a smooth gradient, so a live
`BackdropFilter` over it produced a pixel-identical result while costing a
backdrop capture, a separable Gaussian and a saturation matrix **per card, per
frame, during every scroll and every tab switch**. That was the jank.

With `blur: 0` the `BackdropFilter` is not built at all — the panel is a tint, a
sheen and a rim, which is exactly what the eye reads at these alphas. The frost
is kept where content genuinely moves behind the glass: the bottom bar, the
sheets, the success dialog and the floating map panels (`AppGlass.sheetBlur =
14`).

There is no `BackdropGroup` in the shell any more: nothing in the body uses
`BackdropFilter.grouped`, so a shared capture would be a full-screen layer per
frame for zero pixels of difference. Blur is also skipped entirely when
`MediaQuery.disableAnimationsOf(context)` is true.

Other per-frame costs removed:

- The contact shadow went from `blurRadius 26 / offset 12` to `18 / 8` — one
  blurred rounded rect per card is a real cost when it is re-rasterised.
- `InkSparkle` → `InkRipple`: Sparkle is a fragment shader that compiles on the
  first tap (a visible stutter) and costs more on every card it lands on.

`LiquidGlassEngine.liteGlassOnSkia/OnImpeller = true`: this device family
returns opaque pixels from the Impeller glass shader, and lite glass (frost,
tint, painted rim, no shader pass) is both transparent and the cheapest path.
Lite glass also forces `LiquidGlassMorphMotion.plain` — a single spring morph,
which is the only honest render for a shader-free surface. The morph's ticker
stops when its springs settle, so the header menu costs nothing while idle.

### The canvas is painted once

`GradientBackdrop` used to draw twelve radial blobs every frame inside a
full-screen `ImageFiltered` with a 70-sigma blur — a screen-sized Gaussian
re-rasterised on every frame. It is now baked **once** into a small
`ui.Image` at 0.34× the window size (`_CloudBake`) using the same blob
geometry, the same gradient stops and the same 70-sigma group blur, then blitted
as one textured rectangle. The bake is cached per window size, sits inside a
`RepaintBoundary`, and its widget subtree is `const`, so scrolling content never
invalidates it. `_LiveClouds` (the original implementation) is kept as the
fallback if an engine cannot bake.

The bake is verified, not assumed: `tool/sample_golden.mjs` reads the same
pixels before and after, and the canvas above the bar moved from `#24272a` to
`#25282a` and a card body from `#212124` to `#212224` — a 1–2/255 difference
from bilinear upscaling, i.e. the look is unchanged.

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

## 6. The splash

`lib/pages/splash_page.dart`. It is not a loading screen — there is nothing to
load. It covers the engine's first frame so the app opens on something composed
instead of on a half-painted list, and it always ends on its own.

One 1200 ms controller drives the whole sequence, so the parts read as a single
gesture rather than four unrelated fades:

| Part | Interval | Motion |
|---|---|---|
| Glass tile + water glyph | 0–0.40 | scale 0.84→1 on `easeOutBack`, opacity 0→1 |
| Halo ring | 0.08–0.62 | expands 0.72→1 while fading 0.55→0 |
| «سيترنتي» | 0.18–0.58 | fades in rising 0.22→0 of its own height |
| «ماء يوصلك لباب الدار» | 0.30–0.70 | same rise, one beat later |
| Hairline progress | 0.05–0.95 | fills start→end, accent gradient |

The mark is the same accent (`#5FD3E8`) as the rest of the app, on the same
`GradientBackdrop`, so the first frame and the first screen are one product.

- **Reduced motion** — `disableAnimationsOf` jumps the controller to its
  finished frame and holds it 500 ms, so the brand does not flash past in one
  frame. The status listener is detached first so the jump does not also fire
  `onDone` early.
- **No white flash** — the Android window background is black in both
  `drawable-v21/launch_background.xml` and `values-night/styles.xml`, so the gap
  between process start and first Flutter frame is black, not white.
- **Hand-off** — `_Boot` cross-fades splash → `HomeShell` on `AppMotion.entrance`
  and builds the shell only after the splash is done, so the shell's first
  layout (cards, bar, glass) does not compete with the splash for the same
  frames.
- **Tests** — `SitirnatiApp(showSplash: false)` is used by every functional test
  and by the four screen goldens; a fifth golden (`goldens/splash.png`) captures
  the splash at 1000 ms.

## 7. States covered

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

## 8. Accessibility

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

## 9. Copy rules used

Algerian Darja, verbs first, no filler. "اطلب الآن", not "إرسال". Errors say
what to do, not what failed: «خدمة الموقع مطفية. شغّلها من إعدادات الهاتف، ولا
حدد مكانك بصباعك.» The submit footnote now describes the pool truthfully instead
of a local-only write: «الطلب يوصل للسواقين المتوفرين كاملين، و أول واحد يقبلو
ياخذو و يعيّطلك. تتبع الحالة في «طلبياتي».»

The one piece of copy that has to persuade rather than inform is the
overlay-permission dialog: it names the permission, says why («باش ما يفوتكش —
حتى إذا كان الهاتف مقفول»), says what happens without it («التنبيه يبان غير كي
تكون فاتح سيترنتي»), and offers two exits that both still place the order —
«كمّل بلا التنبيه» and «افتح الإعدادات». No permission is ever a dead end.

Numbers are written the way a customer says them: a volume is `10 000 لتر`
(number first, then the unit word), not `10 م³`. The tank size is stored in
cubic metres because that is how drivers quote it; the conversion happens once,
in `formatVolume` (`lib/utils/formatters.dart`), and every screen — card chip,
form summary, dialog, semantic label — shows the same string.

## 10. Verification

What is actually run today, and what each one proves:

```powershell
node tool/contrast_check.mjs       # 38/38 pairs, measured on the token values
flutter analyze                    # No issues found! (both apps)
node tool/rules_e2e.mjs            # 32/32 checks against the live backend
flutter build apk --split-per-abi --release
```

`contrast_check.mjs` is the gate that keeps "dark and muted" from becoming
"dark and unreadable": it reads the tokens out of `app_theme.dart`, composites
each pair the way the glass actually stacks, and prints the ratio per pair. The
numbers in §3 come from that run, not from an eyedropper.

**The widget and golden suite is stale and known to be stale.** `test/goldens/`
still holds the boards from before the driver cards replaced the truck cards, so
`flutter test` fails on the image comparison — that is a snapshot of a UI that no
longer exists, not a regression. The suite is customer-app only (there is no
driver-app test project). Re-baseline it before trusting it:

```powershell
flutter test --update-goldens test/visual_test.dart
node tool/sample_golden.mjs test/goldens/browse.png
```

`sample_golden.mjs` prints the real pixel colours of the bar, capsule, canvas and
card. It is also the check that the baked canvas still reproduces the live blur:
after the bake landed, the canvas above the bar read `#25282a` (was `#24272a`) and
a card body `#212224` (was `#212124`) — a 1–2/255 bilinear difference, not a
visual change. A near-black reading would mean the bake failed and `_LiveClouds`
is running instead.
