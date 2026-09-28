// Paints all block pictures (16x16 pixels each) into one big texture.
import { TILE_NAMES, BLOCKS } from './blocks.js';
import { ORES } from './data.js';
import { rng } from './noise.js';

export const TS = 16;        // pixels per tile
export const COLS = 16;      // tiles per row
export const ATLAS = TS * COLS;

let canvas = null;
const avg = [];              // block id -> [r,g,b] 0..1 for particles
const iconCache = new Map();

function hex(h) {
  const n = parseInt(h.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
const clamp = (v) => (v < 0 ? 0 : v > 255 ? 255 : v | 0);
const shade = (c, k) => [c[0] * k, c[1] * k, c[2] * k];
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];

export function buildAtlas() {
  canvas = document.createElement('canvas');
  canvas.width = canvas.height = ATLAS;
  const ctx = canvas.getContext('2d');
  const img = ctx.createImageData(ATLAS, ATLAS);
  const d = img.data;

  let tile = 0;
  let r = rng(1);
  const px = (x, y, c, a = 255) => {
    if (x < 0 || y < 0 || x >= TS || y >= TS) return;
    const i = (((tile / COLS) | 0) * TS + y) * ATLAS * 4 + ((tile % COLS) * TS + x) * 4;
    d[i] = clamp(c[0]); d[i + 1] = clamp(c[1]); d[i + 2] = clamp(c[2]); d[i + 3] = a;
  };
  const get = (x, y) => {
    const i = (((tile / COLS) | 0) * TS + y) * ATLAS * 4 + ((tile % COLS) * TS + x) * 4;
    return [d[i], d[i + 1], d[i + 2]];
  };
  const jit = (c, amt) => {
    const j = (r() - 0.5) * amt;
    return [c[0] + j, c[1] + j, c[2] + j];
  };
  const fill = (base, amt) => {
    for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) px(x, y, jit(base, amt));
  };
  const speck = (c, chance, amt = 10) => {
    for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) if (r() < chance) px(x, y, jit(c, amt));
  };
  const stone = () => {
    fill([128, 128, 128], 16);
    speck([104, 104, 104], 0.16);
    speck([150, 150, 150], 0.08);
  };
  const blob = (cx, cy, c, rad = 1.4) => {
    for (let y = -2; y <= 2; y++) for (let x = -2; x <= 2; x++) {
      if (x * x + y * y > rad * rad + 0.3) continue;
      let k = 1 + (-x - y) * 0.09;
      px(cx + x, cy + y, jit(shade(c, k), 16));
    }
    px(cx - 1, cy - 1, mix(c, [255, 255, 255], 0.55));
  };
  const blobSpots = (n) => {
    const spots = [];
    let tries = 0;
    while (spots.length < n && tries++ < 200) {
      const x = 2 + ((r() * 12) | 0), y = 2 + ((r() * 12) | 0);
      if (spots.every((s) => Math.abs(s[0] - x) + Math.abs(s[1] - y) > 4)) spots.push([x, y]);
    }
    return spots;
  };
  const wool = (c) => {
    fill(c, 14);
    for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) if ((x + y * 3) % 5 === 0) px(x, y, jit(shade(c, 0.9), 8));
  };
  const DOLLAR = ['..##..', '.#####', '##.#..', '##.#..', '.####.', '..#.##', '..#.##', '#####.', '..##..'];

  const painters = {
    grass_top() { fill([98, 178, 60], 26); speck([76, 150, 44], 0.2, 12); speck([124, 200, 80], 0.08, 10); },
    grass_side() {
      painters.dirt();
      for (let x = 0; x < TS; x++) {
        const gh = 3 + (r() < 0.5 ? 1 : 0) + (r() < 0.25 ? 1 : 0);
        for (let y = 0; y < gh; y++) px(x, y, jit([98, 178, 60], 24));
      }
    },
    dirt() { fill([134, 96, 62], 18); speck([108, 76, 48], 0.14); speck([160, 120, 80], 0.06); },
    stone,
    sand() { fill([228, 212, 146], 12); speck([206, 188, 120], 0.12, 8); },
    log_side() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        const dark = x % 4 === 0 || (x % 4 === 2 && r() < 0.3);
        px(x, y, jit(dark ? [80, 58, 34] : [112, 82, 50], 12));
      }
    },
    log_top() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        const dd = Math.max(Math.abs(x - 7.5), Math.abs(y - 7.5));
        if (dd > 6.5) px(x, y, jit([96, 70, 40], 10));
        else px(x, y, jit(Math.floor(dd) % 2 ? [186, 150, 96] : [158, 124, 76], 10));
      }
    },
    leaves() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        if (r() < 0.2) { px(x, y, [0, 0, 0], 0); continue; }
        px(x, y, jit(r() < 0.25 ? [40, 118, 34] : [62, 156, 48], 26));
      }
    },
    planks() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        const row = (y / 4) | 0;
        const seam = y % 4 === 3 || x === (row * 7 + 3) % 16;
        px(x, y, jit(seam ? [128, 90, 52] : r() < 0.15 ? [170, 124, 72] : [188, 140, 84], 10));
      }
    },
    bedrock() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        const k = r();
        px(x, y, k < 0.3 ? [34, 34, 36] : k < 0.7 ? [70, 70, 74] : [104, 104, 108]);
      }
    },
    brick() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        const off = ((y / 4) | 0) % 2 ? 4 : 0;
        const mortar = y % 4 === 3 || (x + off) % 8 === 7;
        px(x, y, mortar ? jit([196, 188, 176], 8) : jit([172, 76, 54], 18));
      }
    },
    glass() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        const edge = x === 0 || y === 0 || x === 15 || y === 15;
        const shine = (x + y === 6 || x + y === 7) && x > 1 && x < 6;
        if (edge) px(x, y, [214, 238, 250]);
        else if (shine) px(x, y, [250, 255, 255]);
        else px(x, y, [0, 0, 0], 0);
      }
    },
    gold_block() {
      fill([255, 212, 58], 10);
      for (let i = 0; i < TS; i++) {
        px(i, 0, [255, 244, 170]); px(0, i, [255, 244, 170]);
        px(i, 15, [206, 150, 18]); px(15, i, [206, 150, 18]);
      }
      for (let i = 3; i < 13; i++) px(i, 3, [255, 236, 130]);
    },
    white() { wool([236, 236, 236]); },
    yellow() { wool([250, 214, 50]); },
    red() { wool([204, 48, 48]); },
    green() { wool([74, 178, 62]); },
    blue() { wool([52, 92, 206]); },
    orange() { wool([242, 132, 40]); },
    pink() { wool([246, 142, 190]); },
    lamp() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        const edge = x === 0 || y === 0 || x === 15 || y === 15;
        const bar = x === 5 || x === 10 || y === 5 || y === 10;
        const d = Math.hypot(x - 7.5, y - 7.5);
        px(x, y, edge ? [120, 84, 40] : bar ? [150, 106, 52] : mix([255, 250, 200], [255, 190, 60], Math.min(1, d / 7)));
      }
    },
    metal() {
      fill([122, 132, 148], 6);
      for (let i = 0; i < TS; i++) { px(i, 0, [92, 100, 114]); px(0, i, [92, 100, 114]); px(i, 8, [104, 112, 126]); }
      for (const [x, y] of [[3, 3], [12, 3], [3, 12], [12, 12]]) px(x, y, [196, 204, 214]);
    },
    money_block() {
      fill([44, 176, 84], 10);
      for (let i = 0; i < TS; i++) {
        px(i, 0, [20, 118, 52]); px(0, i, [20, 118, 52]); px(i, 15, [20, 118, 52]); px(15, i, [20, 118, 52]);
        if (i > 0 && i < 15) { px(i, 1, [110, 222, 140]); px(1, i, [110, 222, 140]); }
      }
      DOLLAR.forEach((row, y) => [...row].forEach((ch, x) => ch === '#' && px(5 + x, 3 + y, [232, 255, 232])));
    },
    lemon() {
      fill([255, 226, 58], 12);
      speck([255, 246, 160], 0.1, 6);
      for (let i = 0; i < TS; i++) { px(i, 15, [226, 186, 30]); px(15, i, [226, 186, 30]); }
      px(2, 2, [255, 255, 220]); px(3, 2, [255, 255, 220]); px(2, 3, [255, 255, 220]);
    },
    pizza() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        const edge = x < 2 || y < 2 || x > 13 || y > 13;
        px(x, y, edge ? jit([206, 142, 72], 16) : jit(r() < 0.12 ? [214, 72, 40] : [252, 208, 84], 14));
      }
      for (const [cx, cy] of [[5, 5], [10, 6], [6, 10], [11, 11]]) {
        for (let y = -2; y <= 2; y++) for (let x = -2; x <= 2; x++)
          if (x * x + y * y <= 3) px(cx + x, cy + y, jit([188, 40, 40], 12));
      }
    },
    window() {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        const edge = x === 0 || y === 0 || x === 15 || y === 15;
        const shine = x - y > 2 && x - y < 6;
        px(x, y, edge ? [226, 226, 226] : shine ? [132, 180, 226] : jit([44, 74, 116], 8));
      }
    },
    path() { fill([156, 126, 82], 18); speck([130, 128, 118], 0.12, 10); speck([180, 150, 100], 0.08, 10); },
    cobble() {
      const cs = [];
      for (let i = 0; i < 9; i++) cs.push([r() * 16, r() * 16, 106 + r() * 44]);
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
        let a = 1e9, b = 1e9, ci = 0;
        for (let i = 0; i < cs.length; i++) {
          for (const [ox, oy] of [[0, 0], [16, 0], [-16, 0], [0, 16], [0, -16]]) {
            const dx = x - cs[i][0] - ox, dy = y - cs[i][1] - oy, dd = Math.sqrt(dx * dx + dy * dy);
            if (dd < a) { b = a; a = dd; ci = i; } else if (dd < b) b = dd;
          }
        }
        const g = cs[ci][2];
        px(x, y, b - a < 1.1 ? [72, 72, 74] : jit([g, g, g], 12));
      }
    },
    money_ore() {
      stone();
      for (const [x, y] of [[2, 2], [9, 4], [3, 10], [9, 11]]) {
        for (let j = 0; j < 3; j++) for (let i = 0; i < 5; i++) px(x + i, y + j, [74, 214, 104]);
        for (let i = 0; i < 5; i++) px(x + i, y + 2, [40, 150, 70]);
        px(x + 2, y + 1, [22, 108, 48]);
      }
      for (const [x, y] of [[13, 1], [7, 8], [13, 8]]) {
        px(x, y, [255, 226, 70]); px(x + 1, y, [255, 206, 40]); px(x, y + 1, [230, 180, 30]); px(x + 1, y + 1, [210, 160, 20]);
      }
    },
  };
  ORES.forEach((o, i) => {
    painters['ore_' + ['copper', 'iron', 'gold', 'ruby', 'sapphire', 'amethyst', 'lava', 'ice', 'rainbow', 'cosmic'][i]] = () => {
      const c = hex(o.color);
      if (o.name === 'Cosmic') {
        fill([34, 22, 66], 12);
        speck([70, 40, 130], 0.2, 16);
        for (let k = 0; k < 10; k++) px((r() * 16) | 0, (r() * 16) | 0, r() < 0.5 ? [255, 255, 255] : [140, 240, 255]);
        blobSpots(3).forEach(([x, y]) => blob(x, y, [150, 110, 255], 1.1));
        return;
      }
      stone();
      const spots = blobSpots(5);
      const rainbow = ['#ff3b3b', '#ffb020', '#ffee33', '#3bdc5a', '#3b8bff', '#b44dff'];
      spots.forEach(([x, y], k) => {
        const col = o.name === 'Rainbow' ? hex(rainbow[k % rainbow.length]) : c;
        blob(x, y, col, 1.4);
        if (o.name === 'Lava Gem') px(x, y, [255, 240, 120]);
        if (o.name === 'Ice Crystal') { px(x + 1, y - 1, [255, 255, 255]); }
      });
    };
  });
  // Crack pictures for mining, 5 steps.
  const crackRand = rng(99);
  const lines = [];
  for (let i = 0; i < 6; i++) {
    const pts = [[7.5, 7.5]];
    let a = crackRand() * Math.PI * 2;
    for (let s = 0; s < 9; s++) {
      a += (crackRand() - 0.5) * 1.2;
      const p = pts[pts.length - 1];
      pts.push([p[0] + Math.cos(a), p[1] + Math.sin(a)]);
    }
    lines.push(pts);
  }
  for (let k = 0; k < 5; k++) {
    painters['crack' + k] = () => {
      for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) px(x, y, [0, 0, 0], 0);
      const n = Math.round(((k + 1) / 5) * 9);
      for (const pts of lines) for (let s = 0; s <= n; s++) px(Math.floor(pts[s][0]), Math.floor(pts[s][1]), [20, 20, 20], 220);
    };
  }

  TILE_NAMES.forEach((name, i) => {
    tile = i;
    r = rng(1000 + i * 17);
    painters[name]();
  });
  ctx.putImageData(img, 0, 0);

  // Average colours for break particles.
  for (const b of BLOCKS) {
    if (!b) continue;
    const t = b.tiles[2];
    let rr = 0, gg = 0, bb = 0, n = 0;
    for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) {
      const i = (((t / COLS) | 0) * TS + y) * ATLAS * 4 + ((t % COLS) * TS + x) * 4;
      if (d[i + 3] < 128) continue;
      rr += d[i]; gg += d[i + 1]; bb += d[i + 2]; n++;
    }
    avg[b.id] = n ? [rr / n / 255, gg / n / 255, bb / n / 255] : [1, 1, 1];
  }
  return canvas;
}

export const avgColor = (id) => avg[id] || [1, 1, 1];

// UV box of a tile: [u0, v0, u1, v1] (v goes up, like the GPU likes).
export function tileUV(t) {
  const e = 0.02 / ATLAS;
  const tx = t % COLS, ty = (t / COLS) | 0;
  return [tx / COLS + e, 1 - (ty + 1) / COLS + e, (tx + 1) / COLS - e, 1 - ty / COLS - e];
}

// Little 3D block picture for the hotbar and the shop.
export function blockIcon(id, size = 48) {
  const key = id + ':' + size;
  if (iconCache.has(key)) return iconCache.get(key);
  const b = BLOCKS[id];
  const c = document.createElement('canvas');
  c.width = c.height = 48;
  const g = c.getContext('2d');
  g.imageSmoothingEnabled = false;
  // Draw each face on its own layer so darkening only hits that face.
  const layer = (t, m, dark) => {
    const l = document.createElement('canvas');
    l.width = l.height = 48;
    const lg = l.getContext('2d');
    lg.imageSmoothingEnabled = false;
    lg.setTransform(...m);
    lg.drawImage(canvas, (t % COLS) * TS, ((t / COLS) | 0) * TS, TS, TS, 0, 0, TS, TS);
    if (dark) {
      lg.globalCompositeOperation = 'source-atop';
      lg.fillStyle = `rgba(0,0,0,${dark})`;
      lg.fillRect(0, 0, TS, TS);
    }
    g.drawImage(l, 0, 0);
  };
  const k = 1 / TS;
  layer(b.tiles[0], [20 * k, -10 * k, 20 * k, 10 * k, 4, 14]);
  layer(b.tiles[2], [20 * k, 10 * k, 0, 22 * k, 4, 14], 0.22);
  layer(b.tiles[2], [20 * k, -10 * k, 0, 22 * k, 24, 24], 0.4);
  const url = c.toDataURL();
  iconCache.set(key, url);
  return url;
}
