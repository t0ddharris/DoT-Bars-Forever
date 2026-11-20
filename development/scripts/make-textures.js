// Generates DoT Bars Forever's original bar textures and an HTML preview built from them.
// Usage: node development/scripts/make-textures.js [outDir]
// Textures are white-to-grey luminance ramps (opaque), so the bar color tints them.
// Format: 256x32, 32-bit uncompressed TGA, bottom-left origin (power-of-two for the client).
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const W = 256, H = 32;
const out = process.argv[2] || path.join(__dirname, '..', 'texture-work');
fs.mkdirSync(out, { recursive: true });

const smoothstep = t => t * t * (3 - 2 * t);
const clamp = v => Math.max(0, Math.min(1, v));

// Each profile maps vertical position t (0 = top edge, 1 = bottom edge) to brightness.
const designs = {
  Smooth: t => 1.0 - 0.24 * smoothstep(t),
  Glass: t => {
    let v = 0.74 - 0.06 * t;                                      // slightly deeper body
    // Upper band: clearly lighter, ending in a short soft edge just under the middle.
    const band = 1 - smoothstep(Math.max(0, Math.min(1, (t - 0.40) / 0.12)));
    v += band * (0.14 + 0.08 * (1 - t / 0.52));
    if (t < 1.5 / H) v = 0.98;                                    // hairline top edge
    if (t > 1 - 1.5 / H) v -= 0.06;                               // faint bottom edge
    return v;
  },
  // A wide, soft sheen high on the bar: no line, no hard edge.
  Gloss: t => 0.82 - 0.06 * t + 0.15 * Math.exp(-Math.pow((t - 0.26) / 0.20, 2)),
};

function tga(fn) {
  const header = Buffer.alloc(18);
  header[2] = 2;                    // uncompressed true-color
  header.writeUInt16LE(W, 12);
  header.writeUInt16LE(H, 14);
  header[16] = 32;                  // bits per pixel
  header[17] = 8;                   // 8 alpha bits, bottom-left origin
  const px = Buffer.alloc(W * H * 4);
  for (let row = 0; row < H; row++) {
    const y = H - 1 - row;          // stored bottom row first
    const v = Math.round(255 * clamp(fn((y + 0.5) / H)));
    for (let x = 0; x < W; x++) {
      const o = (row * W + x) * 4;
      px[o] = v; px[o + 1] = v; px[o + 2] = v; px[o + 3] = 255; // BGRA
    }
  }
  return Buffer.concat([header, px]);
}

// Read back a column of brightness from a generated TGA (top to bottom).
function column(buf) {
  const w = buf.readUInt16LE(12), h = buf.readUInt16LE(14);
  const col = [];
  for (let y = 0; y < h; y++) {
    const row = h - 1 - y;
    col.push(buf[18 + (row * w) * 4] / 255);
  }
  return col;
}

// --- PNG encoding for previews ---
const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
  return Buffer.concat([len, td, c]);
}
function png(w, h, rgb) {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 3 + 1)] = 0;
    rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

// A bar as the addon draws it: dark background, fill = texture x color at 85% alpha.
function renderBar(col, color, width, height, fill) {
  const bg = [0.10, 0.11, 0.16];
  const rgb = Buffer.alloc(width * height * 3);
  for (let y = 0; y < height; y++) {
    // Linear sample of the texture column, as the client stretches it.
    const s = ((y + 0.5) / height) * col.length - 0.5;
    const i = Math.max(0, Math.min(col.length - 1, Math.floor(s)));
    const j = Math.min(col.length - 1, i + 1);
    const f = Math.max(0, s - i);
    const lum = col[i] * (1 - f) + col[j] * f;
    for (let x = 0; x < width; x++) {
      const inFill = x < width * fill;
      for (let k = 0; k < 3; k++) {
        const v = inFill ? bg[k] * 0.15 + lum * color[k] * 0.85 : bg[k];
        rgb[(y * width + x) * 3 + k] = Math.round(255 * clamp(v));
      }
    }
  }
  return png(width, height, rgb);
}

const colors = [['Amethyst', [0.64, 0.43, 0.96]], ['Jade', [0.19, 0.80, 0.65]], ['Ember', [1, 0.43, 0.23]],
  ['Glacier', [0.29, 0.70, 1]], ['Gold', [0.96, 0.74, 0.32]]];
const columns = { Flat: new Array(H).fill(1) };
for (const [name, fn] of Object.entries(designs)) {
  const file = path.join(out, `Bar-${name}.tga`);
  fs.writeFileSync(file, tga(fn));
  columns[name] = column(fs.readFileSync(file));
}

const img = buf => `<img src="data:image/png;base64,${buf.toString('base64')}" alt="">`;
let rows = '';
for (const [name, col] of Object.entries(columns)) {
  const tag = name === 'Flat' ? 'existing' : 'new';
  rows += `<section><h2>${name} <span class="${tag}">${tag}</span></h2>`;
  for (const h of [20, 26, 32]) rows += `<div class="bar"><span>${h}px</span>${img(renderBar(col, colors[0][1], 420, h, 0.68))}</div>`;
  rows += '<div class="swatches">' + colors.map(([cn, c]) =>
    `<figure>${img(renderBar(col, c, 150, 24, 0.75))}<figcaption>${cn}</figcaption></figure>`).join('') + '</div>';
  rows += `<div class="bar"><span>4x zoom</span>${img(renderBar(col, colors[0][1], 420, H * 4, 1))}</div></section>`;
}
const html = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>DoT Bars Forever Textures</title><style>
:root{--bg:#0b0c11;--card:#13151d;--text:#e6e8ef;--muted:#8d93a6;--accent:#f5d140}
body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 system-ui,sans-serif;padding:24px 16px}
main{max-width:860px;margin:0 auto}h1{font-size:20px;margin:0 0 4px}p{color:var(--muted);margin:0 0 20px}
section{background:var(--card);border-radius:10px;padding:16px 18px;margin:0 0 16px}
h2{font-size:16px;margin:0 0 12px}h2 span{font-size:11px;font-weight:500;border-radius:4px;padding:2px 6px;margin-left:6px;vertical-align:2px}
.new{background:#3b2a63;color:#d8c8ff}.existing{background:#2a2e3a;color:var(--muted)}
.bar{display:flex;align-items:center;gap:12px;margin:0 0 8px;min-width:0}.bar span{width:58px;color:var(--muted);font-size:12px;flex:none}
img{display:block;max-width:100%;min-width:0;border-radius:2px}.bar img{flex:0 1 auto}
.swatches{display:flex;flex-wrap:wrap;gap:10px;margin:10px 0 12px 70px}
@media (max-width:560px){.swatches{margin-left:0}}figure{margin:0}figcaption{color:var(--muted);font-size:11px;margin-top:3px}
</style></head><body><main><h1>DoT Bars Forever — proposed bar textures</h1>
<p>Rendered from the generated 256×32 game texture files, tinted and blended the way the addon draws bars (85% fill alpha over the dark bar background). Real in-game rendering can differ slightly.</p>
${rows}</main></body></html>`;
fs.writeFileSync(path.join(out, 'preview.html'), html);
console.log('wrote', Object.keys(designs).map(n => `Bar-${n}.tga`).join(', '), 'and preview.html to', out);
