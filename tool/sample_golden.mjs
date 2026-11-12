// Reads a golden PNG and prints real pixel colours for the regions that matter:
// the bottom bar, its selection capsule, a truck card, and the canvas behind.
//
//   node tool/sample_golden.mjs test/goldens/browse.png
//
// Why: the contrast gate models the glass analytically. This script checks the
// model against what the renderer actually produced, so a token is never
// justified by arithmetic alone.

import { readFileSync } from 'node:fs';
import { inflateSync } from 'node:zlib';

/** Decodes an 8-bit truecolour PNG (type 2 or 6, no interlace). */
function decodePng(path) {
  const buf = readFileSync(path);
  if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error('not a png');

  let pos = 8;
  let width = 0;
  let height = 0;
  let colorType = 0;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      const bitDepth = data[8];
      colorType = data[9];
      const interlace = data[12];
      if (bitDepth !== 8) throw new Error(`bit depth ${bitDepth}`);
      if (interlace !== 0) throw new Error('interlaced');
      if (colorType !== 2 && colorType !== 6) {
        throw new Error(`colour type ${colorType}`);
      }
    } else if (type === 'IDAT') {
      idat.push(data);
    } else if (type === 'IEND') {
      break;
    }
    pos += 12 + len;
  }

  const channels = colorType === 6 ? 4 : 3;
  const stride = width * channels;
  const raw = inflateSync(Buffer.concat(idat));
  const out = Buffer.alloc(width * height * 3);

  let prev = Buffer.alloc(stride);
  for (let y = 0; y < height; y += 1) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const cur = Buffer.from(line);
    for (let i = 0; i < stride; i += 1) {
      const a = i >= channels ? cur[i - channels] : 0;
      const b = prev[i];
      const c = i >= channels ? prev[i - channels] : 0;
      let v = cur[i];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c;
        const pa = Math.abs(p - a);
        const pb = Math.abs(p - b);
        const pc = Math.abs(p - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      cur[i] = v & 0xff;
    }
    for (let x = 0; x < width; x += 1) {
      const s = x * channels;
      const d = (y * width + x) * 3;
      out[d] = cur[s];
      out[d + 1] = cur[s + 1];
      out[d + 2] = cur[s + 2];
    }
    prev = cur;
  }
  return { width, height, pixels: out };
}

const path = process.argv[2] ?? 'test/goldens/browse.png';
const { width, height, pixels } = decodePng(path);

/** Mean RGB of a box, in pixels. */
function box(x0, y0, x1, y1) {
  let r = 0;
  let g = 0;
  let b = 0;
  let n = 0;
  for (let y = Math.max(0, Math.round(y0)); y < Math.min(height, Math.round(y1)); y += 1) {
    for (let x = Math.max(0, Math.round(x0)); x < Math.min(width, Math.round(x1)); x += 1) {
      const i = (y * width + x) * 3;
      r += pixels[i];
      g += pixels[i + 1];
      b += pixels[i + 2];
      n += 1;
    }
  }
  return [Math.round(r / n), Math.round(g / n), Math.round(b / n)];
}

const hex = ([r, g, b]) =>
  '#' + [r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('');

const channel = (c) => {
  const s = c / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
};
const lum = ([r, g, b]) =>
  0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
const ratio = (a, b) => {
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
};

console.log(`${path}  ${width}x${height}px\n`);

// The golden is 3x: 390x844 dp -> 1170x2532 px. The bar is 56dp tall with a
// 12dp bottom margin and 16dp side margins.
const s = width / 390;
const barBottom = height - Math.round(12 * s);
const barTop = barBottom - Math.round(56 * s);
const barLeft = Math.round(16 * s);
const barRight = width - Math.round(16 * s);

console.log(`bar box: x ${barLeft}..${barRight}  y ${barTop}..${barBottom}\n`);

// Horizontal scan through the middle of the bar, so the capsule edge and the
// bar's own glass are both sampled.
const midY = Math.round((barTop + barBottom) / 2);
console.log('horizontal scan across the bar (20px steps, 8x8 blocks):');
let line = [];
for (let x = barLeft; x < barRight; x += 20) {
  line.push(`${x}:${hex(box(x, midY - 4, x + 8, midY + 4))}`);
}
console.log('  ' + line.join(' '));

// The capsule geometry comes from the package's own layout model: two equal
// slots, a 10dp horizontal and 6dp vertical inset. The selected item is index 1
// (the bar is laid out LTR with the browse tab last), so its capsule is the
// right-hand one. Probing the top-left corner of each slot samples the fill
// only — the icon and label are centred and never reach there.
const slotWidth = (390 - 32) / 2;
const pillLeft = 10.0;
const pillTop = 6.0;

function slotProbe(index) {
  const x = barLeft + (index * slotWidth + pillLeft) * s + 12;
  const y = barTop + pillTop * s + 12;
  return box(x, y, x + 22 * s, y + 10 * s);
}

const capsule = slotProbe(1);
const idleSlot = slotProbe(0);
console.log(`\ncapsule fill (selected slot)   ${hex(capsule)}`);
console.log(`bar glass (idle slot)          ${hex(idleSlot)}`);
// Deliberately no ratio between the two: each slot samples different content
// behind the bar, so the difference includes the backdrop, not just the
// capsule. The capsule's own contrast is measured analytically in
// `tool/contrast_check.mjs`, where the backdrop is held constant (1.82:1).

// The canvas just above the bar, i.e. what the bar is sampling.
const behind = box(barLeft, barTop - 40 * s, barRight, barTop - 8 * s);
console.log(`\ncanvas just above the bar      ${hex(behind)}`);
console.log(
  `  capsule vs canvas behind     ${ratio(capsule, behind).toFixed(2)}:1`,
);

// A truck card: sample a few rows inside the first card body.
const cardProbe = box(40 * s, 300 * s, 350 * s, 330 * s);
console.log(`\nfirst card body                ${hex(cardProbe)}`);

// Darkest and brightest pixel anywhere, so the analytic model can be compared
// against the real range of the render.
let lo = [255, 255, 255];
let hi = [0, 0, 0];
for (let i = 0; i < pixels.length; i += 3) {
  const p = [pixels[i], pixels[i + 1], pixels[i + 2]];
  if (lum(p) < lum(lo)) lo = p;
  if (lum(p) > lum(hi)) hi = p;
}
console.log(`\nrange: darkest ${hex(lo)}  brightest ${hex(hi)}`);
