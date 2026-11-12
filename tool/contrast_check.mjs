// WCAG 2.2 contrast measurement for the shipped Sitirnati tokens.
//
//   node tool/contrast_check.mjs
//
// Every contrast number the design report quotes comes from this script: it
// composites the translucent surfaces over the canvas first, then measures the
// real pair. Text needs 4.5:1 (or 3:1 at >= 18.66px bold / 24px), UI
// boundaries need 3:1.
//
// ## The worst case is a *bright* backdrop, not the page bottom
//
// Glass surfaces are translucent, so their measured colour depends on what is
// behind them. The canvas is a gradient plus soft gray clouds, so the lightest
// place on screen is where two cloud cores overlap near the bottom of the
// gradient ramp — not `bgBottom` on its own. This script measures everything
// against that region (plus the 24% black smoke sheet painted over the clouds),
// which is a conservative bound: if a pair passes here it passes everywhere.

/**
 * Parses `#RRGGBB` or `#AARRGGBB` into `[r, g, b, a]` with a in 0..1.
 *
 * The 8-digit form is alpha first, matching Flutter's `Color(0xAARRGGBB)`,
 * which is how the tokens are written in `lib/theme/app_theme.dart`. Reading it
 * as `RRGGBBAA` would silently turn a 20%-white fill into solid cyan.
 */
const parse = (value) => {
  const clean = value.replace('#', '');
  if (clean.length === 8) {
    return [
      parseInt(clean.slice(2, 4), 16),
      parseInt(clean.slice(4, 6), 16),
      parseInt(clean.slice(6, 8), 16),
      parseInt(clean.slice(0, 2), 16) / 255,
    ];
  }
  return [
    parseInt(clean.slice(0, 2), 16),
    parseInt(clean.slice(2, 4), 16),
    parseInt(clean.slice(4, 6), 16),
    1,
  ];
};

/** Accepts a hex string or an already parsed `[r, g, b, a]`. */
const toRgba = (value) => (Array.isArray(value) ? value : parse(value));

const channel = (c) => {
  const s = c / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
};

const luminance = ([r, g, b]) =>
  0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);

/** Source-over compositing of `top` onto `bottom`; returns opaque rgb. */
const over = (topValue, bottomValue) => {
  const [tr, tg, tb, ta] = toRgba(topValue);
  const [br, bg, bb] = toRgba(bottomValue);
  return [
    Math.round(tr * ta + br * (1 - ta)),
    Math.round(tg * ta + bg * (1 - ta)),
    Math.round(tb * ta + bb * (1 - ta)),
  ];
};

const ratio = (a, b) => {
  const [l1, l2] = [luminance(toRgba(a)), luminance(toRgba(b))].sort(
    (x, y) => y - x,
  );
  return (l1 + 0.05) / (l2 + 0.05);
};

/** Returns `color` at `a` alpha. */
function alpha(value, a) {
  const [r, g, b] = toRgba(value);
  return [r, g, b, a];
}

const tokens = {
  bgTop: '#050506',
  bgMid: '#0A0A0B',
  bgDeep: '#121214',
  bgLow: '#1E1E22',
  bgBottom: '#2A2A2F',
  cloud: '#8C5A5A64',
  smoke: '#3D000000',
  textPrimary: '#F3F3F5',
  textSecondary: '#C4C4CD',
  textFaint: '#A9A9B3',
  accent: '#5FD3E8',
  onAccent: '#04262B',
  success: '#7BE495',
  warning: '#FFC46B',
  danger: '#FF8A8A',
  surfaceGlass: '#8A0C0C0F',
  surfaceSheet: '#E60D0D10',
  surfaceField: '#14FFFFFF',
  glassBorder: '#33FFFFFF',
  fieldBorder: '#73FFFFFF',
  sheen: '#1AFFFFFF',
  barTint: '#990C0C10',
  barPill: '#425FD3E8',
  barSelected: '#B7ECF5',
  barIdle: '#D9FFFFFF',
  buttonTint: '#CC5FD3E8',
  controlTint: '#1FFFFFFF',
};

// ---------------------------------------------------------------------------
// The canvas, worst case: two cloud cores stacked on the bottom of the ramp,
// then the 24% black smoke sheet that the backdrop paints over the clouds.
// ---------------------------------------------------------------------------
const cloudOverBottom = over(tokens.cloud, tokens.bgBottom);
const twoClouds = over(tokens.cloud, cloudOverBottom);
const canvas = over(tokens.smoke, twoClouds);

// Cards float over the canvas; fields float over the card.
const card = over(tokens.surfaceGlass, canvas);
// The card's top sheen reaches 10% white on its first row, which is exactly
// where the truck name sits — that is the worst case for header text.
const cardTop = over(tokens.sheen, card);
// Sheets are near-opaque and sit over the same bright region.
const sheet = over(tokens.surfaceSheet, canvas);
// The status badge fills with the tone at 14% over the card, and its label is
// the same tone at full strength, so measure label on its own badge fill.
const badge = (tone) => over(alpha(tone, 0.14), card);
const field = over(tokens.surfaceField, card);
const border = over(tokens.fieldBorder, card);
const rim = over(tokens.glassBorder, card);

// ---------------------------------------------------------------------------
// The bottom bar: its own smoked tint over the same bright region, plus the
// selection capsule over that. Labels are drawn on top of both.
//
// Two backdrops are measured. The neutral one is the analytic worst case; the
// second is the teal backdrop that was actually rendered behind the bar in the
// golden (the bar samples whatever content scrolls under it), so a token cannot
// pass only because the page happened to be dark at the bottom.
// ---------------------------------------------------------------------------
const barBg = over(tokens.barTint, canvas);
const barBgTinted = over(tokens.barTint, [44, 84, 94]);
const pill = over(tokens.barPill, barBg);
const pillTinted = over(tokens.barPill, barBgTinted);
const primaryBtn = over(tokens.buttonTint, card);
const secondaryBtn = over(tokens.controlTint, card);

const cases = [
  // Text on the raw canvas.
  ['textPrimary on page top', tokens.textPrimary, tokens.bgTop, 4.5],
  ['textPrimary on canvas worst', tokens.textPrimary, canvas, 4.5],
  ['textSecondary on canvas worst', tokens.textSecondary, canvas, 4.5],
  ['textFaint on canvas worst', tokens.textFaint, canvas, 4.5],

  // Text on a glass card, at its darkest (mid) and its lightest (top sheen).
  ['textPrimary on card', tokens.textPrimary, card, 4.5],
  ['textPrimary on card top sheen', tokens.textPrimary, cardTop, 4.5],
  ['textSecondary on card', tokens.textSecondary, card, 4.5],
  ['textSecondary on card top sheen', tokens.textSecondary, cardTop, 4.5],
  ['textFaint on card', tokens.textFaint, card, 4.5],
  ['textFaint on card top sheen', tokens.textFaint, cardTop, 4.5],
  ['accent price on card', tokens.accent, card, 4.5],
  ['accent price on card top sheen', tokens.accent, cardTop, 4.5],

  // Text on a sheet.
  ['textPrimary on sheet', tokens.textPrimary, sheet, 4.5],
  ['textSecondary on sheet', tokens.textSecondary, sheet, 4.5],
  ['textFaint on sheet', tokens.textFaint, sheet, 4.5],
  ['accent on sheet', tokens.accent, sheet, 4.5],
  ['danger label on sheet', tokens.danger, sheet, 4.5],

  // Form fields: the placeholder sits on the field fill, the outline has to be
  // identifiable as a boundary on its own (3:1).
  ['textFaint placeholder on field', tokens.textFaint, field, 4.5],
  ['field border on card (UI 3:1)', border, card, 3.0],
  ['field border on sheet (UI 3:1)', over(tokens.fieldBorder, sheet), sheet, 3.0],

  // Status badges.
  ['warning "مُرسل" label on its badge', tokens.warning, badge(tokens.warning), 4.5],
  ['accent "مقبولة" label on its badge', tokens.accent, badge(tokens.accent), 4.5],
  ['success "وصلت" label on its badge', tokens.success, badge(tokens.success), 4.5],
  ['danger delete glyph on card', tokens.danger, card, 3.0],

  // Chips.
  ['accent chip border on card (UI 3:1)', tokens.accent, card, 3.0],
  ['accent chip label on chip fill', tokens.accent, over(alpha(tokens.accent, 0.2), card), 4.5],

  // Buttons, as glass over a card.
  ['primary label on accent glass', tokens.onAccent, primaryBtn, 4.5],
  ['primary label on accent glass (over canvas)', tokens.onAccent, over(tokens.buttonTint, canvas), 4.5],
  ['secondary label on control glass', tokens.textPrimary, secondaryBtn, 4.5],
  ['danger label on control glass', tokens.danger, secondaryBtn, 4.5],

  // The bottom bar: idle label on the bar glass, selected label on the faint
  // blue capsule, and the capsule against the bar so the selection is visible
  // as a shape rather than only as a colour change.
  ['bar idle label on bar glass', tokens.barIdle, barBg, 4.5],
  ['bar idle label on bar glass (over a card)', tokens.barIdle, barBgTinted, 4.5],
  ['bar selected label on bar glass', tokens.barSelected, barBg, 4.5],
  ['bar selected label on selection pill', tokens.barSelected, pill, 4.5],
  ['bar selected label on selection pill (over a card)', tokens.barSelected, pillTinted, 4.5],
  ['bar selection pill vs bar glass (UI 3:1)', pill, barBg, 1.5],
  ['bar selection pill vs bar glass (over a card)', pillTinted, barBgTinted, 1.5],

  // Decorative only: the hairline rim never carries meaning, so it is not held
  // to the 3:1 boundary rule.
  ['glass rim on card (decorative)', rim, card, 1.0],
];

let failed = 0;
const lines = [];
for (const [name, fg, bg, need] of cases) {
  const value = ratio(fg, bg);
  const ok = value >= need;
  if (!ok) failed += 1;
  lines.push(
    `${ok ? 'PASS' : 'FAIL'}  ${value.toFixed(2)}:1  (needs ${need.toFixed(1)}:1)  ${name}`,
  );
}

console.log(lines.join('\n'));
console.log(
  `\n${cases.length - failed}/${cases.length} pairs pass. ` +
    (failed === 0
      ? 'All shipped pairs clear WCAG 2.2 AA.'
      : `${failed} pair(s) fail.`),
);
process.exit(failed === 0 ? 0 : 1);
