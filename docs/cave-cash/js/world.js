// The block world: a HUGE island that loads in chunks around you, like Minecraft.
// The map (heights and biomes) is made at the start. The blocks of each 16x16 chunk
// are made the first time you get close to it.
import * as THREE from '../lib/three.min.js';
import { B, BLOCKS, SOLID, OPAQUE, SHADOW, GLOW, PLANT, isLeaves } from './blocks.js';
import { ORES, MONEY_ORE } from './data.js';
import { tileUV } from './atlas.js';
import { rng, noise3, fbm2, smoothstep, lerp } from './noise.js';

export const W = 512, H = 96, D = 512;
export const SEA = 40;
const CS = 16;                          // chunk and section size
const CX = W / CS, CZ = D / CS, SY = H / CS;
const LAMP_R = 6;                       // how far a lamp shines

export const BIOME = { OCEAN: 0, BEACH: 1, PLAINS: 2, FOREST: 3, DESERT: 4, SNOW: 5, MOUNTAIN: 6 };
export const BIOME_NAMES = ['Ocean', 'Beach', 'Plains', 'Forest', 'Desert', 'Snowy Land', 'Mountains'];  // shown when you walk into one

// Faces: normal, 4 corners (bottom-left, bottom-right, top-right, top-left), brightness, tile slot.
const FACES = [
  { n: [1, 0, 0], c: [[1, 0, 1], [1, 0, 0], [1, 1, 0], [1, 1, 1]], s: 0.8, t: 2 },
  { n: [-1, 0, 0], c: [[0, 0, 0], [0, 0, 1], [0, 1, 1], [0, 1, 0]], s: 0.8, t: 2 },
  { n: [0, 1, 0], c: [[0, 1, 1], [1, 1, 1], [1, 1, 0], [0, 1, 0]], s: 1.0, t: 0 },
  { n: [0, -1, 0], c: [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]], s: 0.5, t: 1 },
  { n: [0, 0, 1], c: [[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]], s: 0.65, t: 2 },
  { n: [0, 0, -1], c: [[1, 0, 0], [0, 0, 0], [0, 1, 0], [1, 1, 0]], s: 0.65, t: 2 },
];
const AO = [0.42, 0.62, 0.82, 1.0];
// For each corner: where the 3 blocks that can darken it (ambient occlusion) are.
for (const F of FACES) {
  const ax = F.n[0] ? 0 : F.n[1] ? 1 : 2;
  const ua = ax === 0 ? 1 : 0, va = ax === 2 ? 1 : 2;
  F.tmp = [0, 0, 0, 0];
  F.ao = F.c.map((c) => {
    const a = [0, 0, 0], b = [0, 0, 0];
    a[ua] = c[ua] ? 1 : -1;
    b[va] = c[va] ? 1 : -1;
    return [...a, ...b, a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  });
}
const UVC = [[0, 1], [2, 1], [2, 3], [0, 3]];
// Plants are two crossed pictures.
const CROSS = [
  [[0.15, 0, 0.15], [0.85, 0, 0.85], [0.85, 1, 0.85], [0.15, 1, 0.15]],
  [[0.85, 0, 0.15], [0.15, 0, 0.85], [0.15, 1, 0.85], [0.85, 1, 0.15]],
];

// Chunks in order from near to far, for loading the closest ones first.
const OFFSETS = [];
for (let z = -14; z <= 14; z++) for (let x = -14; x <= 14; x++) OFFSETS.push([x, z, Math.hypot(x, z)]);
OFFSETS.sort((a, b) => a[2] - b[2]);

const hash = (a, b, s) => {
  let h = (Math.imul(a, 73856093) ^ Math.imul(b, 19349663) ^ Math.imul(s, 83492791)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return (h ^ (h >>> 16)) >>> 0;
};

export class World {
  constructor(seed) {
    this.seed = seed;
    this.data = new Uint8Array(W * H * D);
    this.glow = new Uint8Array(W * H * D);     // light from lamps, 0..255
    this.top = new Int16Array(W * D).fill(-1); // highest block that blocks the sky
    this.height = new Int16Array(W * D);       // how high the land is (from the map)
    this.biome = new Uint8Array(W * D);
    this.ocean = new Uint8Array(W * D);        // 1 = water on top
    this.made = new Uint8Array(CX * CZ);       // 1 = this chunk's blocks are made
    this.colMeshed = new Uint8Array(CX * CZ);  // 1 = this chunk has its 3D shapes
    this.visual = new Uint8Array(256);         // what each block looks like (locked ores look like stone)
    for (let i = 0; i < 256; i++) this.visual[i] = i;
    this.edits = new Map();                    // changes the player made (saved)
    this.pending = new Map();                  // saved changes for chunks not made yet
    this.treeCache = new Map();
    this.meshes = new Array(CX * CZ * SY).fill(null);
    this.urgent = new Set();                   // sections to redo right now (you changed a block)
    this.dirty = new Set();                    // sections to redo soon
    this.group = new THREE.Group();
    this.unloadClock = 0;
    this.makeMap();
  }

  idx(x, y, z) { return x + W * (z + D * y); }
  inside(x, y, z) { return x >= 0 && y >= 0 && z >= 0 && x < W && y < H && z < D; }
  isMade(x, z) {
    if (x < 0 || z < 0 || x >= W || z >= D) return false;
    return this.made[(x >> 4) + CX * (z >> 4)] === 1;
  }

  get(x, y, z) {
    if (y < 0) return B.BEDROCK;
    if (x < 0 || z < 0 || x >= W || z >= D || y >= H) return 0;
    return this.data[x + W * (z + D * y)];
  }

  // Change one block. record=true means the player did it (it goes in the save).
  set(x, y, z, id, record = true) {
    if (!this.inside(x, y, z)) return;
    const i = this.idx(x, y, z);
    const old = this.data[i];
    if (old === id) return;
    this.data[i] = id;
    if (record) this.edits.set(i, id);
    if (old === B.LAMP || id === B.LAMP) this.relight(x, y, z);
    const oldTop = this.top[x + W * z];
    this.fixTop(x, z);
    const newTop = this.top[x + W * z];
    this.markAround(x, y, z, true);
    if (oldTop !== newTop) {
      // Shadows below changed: redo the sections in this column and its neighbours.
      const y0 = Math.max(0, Math.min(oldTop, newTop) - 1), y1 = Math.min(H - 1, Math.max(oldTop, newTop) + 1);
      for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++)
        for (let sy = (y0 / CS) | 0; sy <= ((y1 / CS) | 0); sy++) this.markSection(x + dx, sy * CS, z + dz, true);
    }
    // A flower or tall grass falls off if the block under it goes away.
    if (!SOLID[id] && y + 1 < H && PLANT[this.data[i + W * D]]) this.set(x, y + 1, z, 0, record);
  }

  fixTop(x, z) {
    let y = H - 1;
    const col = x + W * z;
    while (y >= 0 && !SHADOW[this.data[col + W * D * y]]) y--;
    this.top[col] = y;
  }

  markSection(x, y, z, urgent) {
    if (!this.inside(x, y, z)) return;
    const c = (x >> 4) + CX * (z >> 4);
    if (!this.colMeshed[c]) return;
    const s = c + CX * CZ * ((y / CS) | 0);
    (urgent ? this.urgent : this.dirty).add(s);
  }

  markAround(x, y, z, urgent) {
    for (let dy = -1; dy <= 1; dy++) for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++)
      this.markSection(x + dx, y + dy, z + dz, urgent);
  }

  markAll() {
    for (let c = 0; c < CX * CZ; c++) if (this.colMeshed[c]) for (let sy = 0; sy < SY; sy++) this.dirty.add(c + CX * CZ * sy);
  }

  // ---------- Lamps ----------
  addGlow(lx, ly, lz, x0 = -1e9, y0 = -1e9, z0 = -1e9, x1 = 1e9, y1 = 1e9, z1 = 1e9) {
    const R = LAMP_R;
    for (let y = Math.max(ly - R, y0, 0); y <= Math.min(ly + R, y1, H - 1); y++)
      for (let z = Math.max(lz - R, z0, 0); z <= Math.min(lz + R, z1, D - 1); z++)
        for (let x = Math.max(lx - R, x0, 0); x <= Math.min(lx + R, x1, W - 1); x++) {
          const d = Math.sqrt((x - lx) ** 2 + (y - ly) ** 2 + (z - lz) ** 2);
          if (d > R) continue;
          const v = Math.round(255 * (1 - d / (R + 1)));
          const i = x + W * (z + D * y);
          if (v > this.glow[i]) this.glow[i] = v;
        }
  }

  // A lamp was added or removed: redo the light around it.
  relight(cx, cy, cz) {
    const R = LAMP_R;
    const x0 = cx - R, y0 = cy - R, z0 = cz - R, x1 = cx + R, y1 = cy + R, z1 = cz + R;
    for (let y = Math.max(0, y0); y <= Math.min(H - 1, y1); y++)
      for (let z = Math.max(0, z0); z <= Math.min(D - 1, z1); z++)
        for (let x = Math.max(0, x0); x <= Math.min(W - 1, x1); x++) this.glow[x + W * (z + D * y)] = 0;
    for (let y = Math.max(0, cy - 2 * R); y <= Math.min(H - 1, cy + 2 * R); y++)
      for (let z = Math.max(0, cz - 2 * R); z <= Math.min(D - 1, cz + 2 * R); z++)
        for (let x = Math.max(0, cx - 2 * R); x <= Math.min(W - 1, cx + 2 * R); x++)
          if (this.data[x + W * (z + D * y)] === B.LAMP) this.addGlow(x, y, z, x0, y0, z0, x1, y1, z1);
    for (let y = y0; y <= y1 + CS; y += CS) for (let z = z0; z <= z1 + CS; z += CS) for (let x = x0; x <= x1 + CS; x += CS)
      this.markSection(Math.min(x, x1), Math.min(y, y1), Math.min(z, z1), true);
  }

  // Locked ores look like stone. Call this when you buy a new material.
  setUnlocked(count) {
    ORES.forEach((o, i) => (this.visual[o.id] = i < count ? o.id : B.STONE));
    this.markAll();
  }

  // ---------- The map: how high the land is, and which biome ----------
  makeMap() {
    const s = this.seed;
    for (let z = 0; z < D; z++) for (let x = 0; x < W; x++) {
      // A big, roundish-square island with a wobbly coast. Always sea at the very edge.
      const dx = (x - W / 2) / (W / 2), dz = (z - D / 2) / (D / 2);
      const edge = Math.pow(dx ** 4 + dz ** 4, 0.25);
      const coast = (fbm2(x / 70, z / 70, s + 3, 3) - 0.5) * 0.5;
      const land = (1 - smoothstep(0.8, 0.96, edge + coast)) * (1 - smoothstep(0.9, 0.98, edge));
      const hills = fbm2(x / 46, z / 46, s, 4);
      const temp = fbm2(x / 110 + 50, z / 110, s + 11, 2);
      const wet = fbm2(x / 95, z / 95 + 80, s + 17, 2);
      const where = smoothstep(0.58, 0.74, fbm2(x / 120, z / 120, s + 23, 2));   // mountain areas
      const ridge = 1 - Math.abs(fbm2(x / 55, z / 55, s + 29, 4) * 2 - 1);
      // Deserts are flatter. Blend them in so there is no sudden cliff.
      const dry = smoothstep(0.55, 0.61, temp) * (1 - smoothstep(0.47, 0.53, wet));
      const desert = dry > 0.5;
      const normalH = SEA + 4 + (hills - 0.5) * 18 + where * (6 + ridge * ridge * 44);
      const desertH = SEA + 4 + (hills - 0.5) * 9 + where * ridge * 14;
      const landH = lerp(normalH, desertH, dry);
      const floor = SEA - 16 + hills * 8;
      const h = Math.max(6, Math.min(H - 6, Math.round(lerp(floor, landH, land))));
      const col = x + W * z;
      this.height[col] = h;
      this.ocean[col] = h < SEA ? 1 : 0;
      let b;
      if (h < SEA) b = BIOME.OCEAN;
      else if (h <= SEA + 1 && land < 0.995) b = BIOME.BEACH;
      else if (h > SEA + 26) b = BIOME.MOUNTAIN;
      else if (desert) b = BIOME.DESERT;
      else if (temp < 0.34) b = BIOME.SNOW;
      else if (wet > 0.52) b = BIOME.FOREST;
      else b = BIOME.PLAINS;
      this.biome[col] = b;
    }
  }

  // A nice grassy place to start, near the middle, with grassland all around.
  findSpawn() {
    const grassy = (x, z) => { const b = this.biome[x + W * z]; return b === BIOME.PLAINS || b === BIOME.FOREST; };
    const treeNear = (x, z) => {
      for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++)
        if (this.trees((x >> 4) + dx, (z >> 4) + dz).some((t) => t.type !== 'cactus' && Math.abs(t.x - x) <= 4 && Math.abs(t.z - z) <= 4)) return true;
      return false;
    };
    for (let r = 0; r < 220; r += 2) for (let a = 0; a < 24; a++) {
      const x = Math.round(W / 2 + Math.cos(a / 24 * Math.PI * 2) * r), z = Math.round(D / 2 + Math.sin(a / 24 * Math.PI * 2) * r);
      const h = this.height[x + W * z];
      if (h <= SEA + 2 || h >= SEA + 16) continue;
      if (grassy(x, z) && grassy(x + 8, z) && grassy(x - 8, z) && grassy(x, z + 8) && grassy(x, z - 8) && !treeNear(x, z)) return { x: x + 0.5, y: h, z: z + 0.5 };
    }
    return { x: W / 2 + 0.5, y: this.height[W / 2 + W * (D / 2)], z: D / 2 + 0.5 };
  }

  // ---------- Making one chunk of blocks ----------
  makeChunk(cx, cz) {
    const s = this.seed, x0 = cx * CS, z0 = cz * CS;
    const r = rng(hash(cx, cz, s));
    const data = this.data, WD = W * D;
    for (let lz = 0; lz < CS; lz++) for (let lx = 0; lx < CS; lx++) {
      const x = x0 + lx, z = z0 + lz, col = x + W * z;
      const h = this.height[col], bio = this.biome[col];
      for (let y = 0; y < h; y++) {
        let id;
        if (y === 0 || (y === 1 && r() < 0.6) || (y === 2 && r() < 0.25)) id = B.BEDROCK;
        else if (bio === BIOME.OCEAN) id = y >= h - 3 ? (h < SEA - 8 ? B.GRAVEL : B.SAND) : B.STONE;
        else if (bio === BIOME.BEACH || bio === BIOME.DESERT) id = y >= h - 4 ? B.SAND : B.STONE;
        else if (bio === BIOME.MOUNTAIN) id = y === h - 1 && h > SEA + 40 ? B.SNOW : y >= h - 2 && h < SEA + 32 ? (y === h - 1 ? B.GRASS : B.DIRT) : B.STONE;
        else if (y < h - 4) id = B.STONE;
        else if (y < h - 1) id = B.DIRT;
        else id = bio === BIOME.SNOW ? B.SNOW_GRASS : B.GRASS;
        data[col + WD * y] = id;
      }
      // Caves: long twisty tunnels everywhere, and big caverns deep down.
      const wet = this.ocean[col];
      for (let y = 1; y < h; y++) {
        if (wet && y >= h - 4) break;
        const i = col + WD * y;
        if (data[i] === B.BEDROCK) continue;
        if (y < 34) {
          const c = noise3(x / 34, y / 16, z / 34, s + 47);
          if (c < 0.26) { data[i] = 0; continue; }
        }
        const a = noise3(x / 20, y / 13, z / 20, s + 41);
        if (Math.abs(a - 0.5) > 0.045) continue;
        const b = noise3(x / 20, y / 13, z / 20, s + 43);
        if (Math.abs(b - 0.5) < 0.05) data[i] = 0;
      }
    }
    // Ore veins. Locked ones look like stone until you buy them.
    const vein = (id, y0, y1, count, size) => {
      for (let v = 0; v < count; v++) {
        let x = x0 + ((r() * CS) | 0), y = y0 + ((r() * (y1 - y0)) | 0), z = z0 + ((r() * CS) | 0);
        const n = size[0] + ((r() * (size[1] - size[0] + 1)) | 0);
        for (let k = 0; k < n; k++) {
          if (x >= x0 && x < x0 + CS && z >= z0 && z < z0 + CS && y > 0 && y < H && data[x + W * z + WD * y] === B.STONE) data[x + W * z + WD * y] = id;
          const d = (r() * 6) | 0;
          if (d === 0) x++; else if (d === 1) x--; else if (d === 2) y++; else if (d === 3) y--; else if (d === 4) z++; else z--;
        }
      }
    };
    ORES.forEach((o) => vein(o.id, o.y[0], o.y[1], o.perChunk, [3, 7]));
    vein(B.MONEY_ORE, MONEY_ORE.y[0], MONEY_ORE.y[1], MONEY_ORE.perChunk, [1, 3]);
    // Trees (also the ones from next door that hang over into this chunk).
    for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++)
      for (const t of this.trees(cx + dx, cz + dz)) this.placeTree(t, x0, z0);
    // Tall grass and flowers.
    for (let lz = 0; lz < CS; lz++) for (let lx = 0; lx < CS; lx++) {
      const x = x0 + lx, z = z0 + lz, col = x + W * z, h = this.height[col], bio = this.biome[col];
      if (h >= H - 1 || data[col + WD * (h - 1)] !== B.GRASS || data[col + WD * h]) continue;
      const k = r();
      const grass = bio === BIOME.PLAINS ? 0.16 : bio === BIOME.FOREST ? 0.08 : bio === BIOME.MOUNTAIN ? 0.04 : 0;
      if (k < grass) data[col + WD * h] = B.TALL_GRASS;
      else if (k < grass + (bio === BIOME.PLAINS ? 0.02 : 0.006)) data[col + WD * h] = r() < 0.5 ? B.POPPY : B.DANDELION;
    }
    // Your saved changes for this chunk.
    const mine = this.pending.get(cx + CX * cz);
    if (mine) {
      for (const [i, id] of mine) { data[i] = id; this.edits.set(i, id); }
      this.pending.delete(cx + CX * cz);
    }
    for (let lz = 0; lz < CS; lz++) for (let lx = 0; lx < CS; lx++) this.fixTop(x0 + lx, z0 + lz);
    for (let y = 0; y < H; y++) for (let lz = 0; lz < CS; lz++) for (let lx = 0; lx < CS; lx++)
      if (data[x0 + lx + W * (z0 + lz) + WD * y] === B.LAMP) this.addGlow(x0 + lx, y, z0 + lz);
    this.made[cx + CX * cz] = 1;
  }

  // Where the trees in a chunk go. Always the same for the same chunk.
  trees(cx, cz) {
    if (cx < 0 || cz < 0 || cx >= CX || cz >= CZ) return [];
    const key = cx + CX * cz;
    if (this.treeCache.has(key)) return this.treeCache.get(key);
    const r = rng(hash(cx, cz, this.seed + 99));
    const list = [];
    for (let t = 0; t < 14; t++) {
      const x = cx * CS + ((r() * CS) | 0), z = cz * CS + ((r() * CS) | 0);
      const roll = r(), kind = r(), size = r();
      const col = x + W * z, bio = this.biome[col];
      const chance = bio === BIOME.FOREST ? 0.7 : bio === BIOME.PLAINS ? 0.05 : bio === BIOME.SNOW ? 0.35 : bio === BIOME.DESERT ? 0.12 : 0;
      if (roll > chance) continue;
      if (list.some((o) => Math.abs(o.x - x) + Math.abs(o.z - z) < 4)) continue;
      const type = bio === BIOME.SNOW ? 'spruce' : bio === BIOME.DESERT ? 'cactus' : bio === BIOME.FOREST && kind < 0.35 ? 'birch' : 'oak';
      list.push({ x, z, y: this.height[col], type, size });
    }
    this.treeCache.set(key, list);
    return list;
  }

  placeTree(t, x0, z0) {
    const data = this.data, WD = W * D;
    const put = (x, y, z, id, onlyAir) => {
      if (x < x0 || x >= x0 + CS || z < z0 || z >= z0 + CS || y < 1 || y >= H) return;
      const i = x + W * z + WD * y;
      if (onlyAir && data[i] && !PLANT[data[i]]) return;
      data[i] = id;
    };
    const { x, y, z } = t;
    if (t.type === 'cactus') {
      const hgt = 1 + Math.floor(t.size * 3);
      for (let i = 0; i < hgt; i++) put(x, y + i, z, B.CACTUS);
      return;
    }
    if (t.type === 'spruce') {
      const hgt = 6 + Math.floor(t.size * 4);
      for (let i = 0; i < hgt; i++) put(x, y + i, z, B.SPRUCE_LOG);
      for (let i = 2; i <= hgt; i++) {
        const rad = i === hgt ? 0 : (hgt - i) % 2 === 0 ? 1 : Math.min(2, 1 + ((hgt - i) >> 2));
        for (let dz = -rad; dz <= rad; dz++) for (let dx = -rad; dx <= rad; dx++) {
          if (Math.abs(dx) + Math.abs(dz) > rad + (rad > 1 ? 0 : 1)) continue;
          put(x + dx, y + i, z + dz, B.SPRUCE_LEAVES, true);
        }
      }
      put(x, y + hgt, z, B.SPRUCE_LEAVES, true);
      return;
    }
    const birch = t.type === 'birch';
    const hgt = (birch ? 5 : 4) + Math.floor(t.size * 3);
    const log = birch ? B.BIRCH_LOG : B.LOG, leaf = birch ? B.BIRCH_LEAVES : B.LEAVES;
    for (let i = 0; i < hgt; i++) put(x, y + i, z, log);
    for (let dy = hgt - 3; dy <= hgt; dy++) {
      const rad = dy >= hgt - 1 ? 1 : 2;
      for (let dz = -rad; dz <= rad; dz++) for (let dx = -rad; dx <= rad; dx++) {
        if (Math.abs(dx) === rad && Math.abs(dz) === rad && (rad === 1 ? dy === hgt : ((x + dx * 3 + z + dz * 7 + dy) & 1))) continue;
        put(x + dx, y + dy, z + dz, leaf, true);
      }
    }
  }

  // ---------- Loading chunks around you ----------
  // Makes blocks for close chunks, builds 3D shapes for the ones you can see,
  // and forgets the shapes of chunks that are far away.
  stream(fx, fz, view, material, budgetMs = 6) {
    const t0 = performance.now();
    const pcx = Math.floor(fx / CS), pcz = Math.floor(fz / CS);
    // Always have the ground under your feet.
    for (let dz = -2; dz <= 2; dz++) for (let dx = -2; dx <= 2; dx++) this.ensure(pcx + dx, pcz + dz);
    // Blocks you just changed.
    for (const s of this.urgent) { this.urgent.delete(s); this.dirty.delete(s); this.buildSection(s, material); }
    for (const s of this.dirty) {
      if (performance.now() - t0 > budgetMs) return;
      this.dirty.delete(s);
      this.buildSection(s, material);
    }
    for (const [ox, oz, dist] of OFFSETS) {
      if (dist > view + 1.5) break;
      const cx = pcx + ox, cz = pcz + oz;
      if (cx < 0 || cz < 0 || cx >= CX || cz >= CZ) continue;
      const c = cx + CX * cz;
      if (!this.made[c]) {
        this.makeChunk(cx, cz);
        if (performance.now() - t0 > budgetMs) return;
        continue;
      }
      if (dist > view || this.colMeshed[c]) continue;
      if (!this.ready(cx, cz)) continue;
      this.colMeshed[c] = 1;
      for (let sy = 0; sy < SY; sy++) this.buildSection(c + CX * CZ * sy, material);
      if (performance.now() - t0 > budgetMs) return;
    }
    // Forget far away shapes now and then.
    if (++this.unloadClock > 90) {
      this.unloadClock = 0;
      for (let c = 0; c < CX * CZ; c++) {
        if (!this.colMeshed[c]) continue;
        if (Math.hypot((c % CX) - pcx, ((c / CX) | 0) - pcz) <= view + 2.5) continue;
        this.colMeshed[c] = 0;
        for (let sy = 0; sy < SY; sy++) this.dropMesh(c + CX * CZ * sy);
      }
    }
  }

  ensure(cx, cz) {
    if (cx < 0 || cz < 0 || cx >= CX || cz >= CZ) return;
    if (!this.made[cx + CX * cz]) this.makeChunk(cx, cz);
  }

  // Can we build the shapes? Only when all the chunks around are made.
  ready(cx, cz) {
    for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) {
      const x = cx + dx, z = cz + dz;
      if (x < 0 || z < 0 || x >= CX || z >= CZ) continue;
      if (!this.made[x + CX * z]) return false;
    }
    return true;
  }

  // Make all the chunks around a spot right away (at the start).
  prepare(fx, fz, radius, material) {
    const pcx = Math.floor(fx / CS), pcz = Math.floor(fz / CS);
    for (let dz = -radius - 1; dz <= radius + 1; dz++) for (let dx = -radius - 1; dx <= radius + 1; dx++) this.ensure(pcx + dx, pcz + dz);
    this.stream(fx, fz, radius, material, Infinity);
  }

  // Start over: forget all blocks and shapes. Chunks get made again when you come near.
  reset() {
    this.data.fill(0);
    this.glow.fill(0);
    this.top.fill(-1);
    this.made.fill(0);
    for (let s = 0; s < this.meshes.length; s++) this.dropMesh(s);
    this.colMeshed.fill(0);
    this.urgent.clear();
    this.dirty.clear();
    this.edits.clear();
    this.pending.clear();
  }

  // Saved changes: they go in when their chunk is made.
  applyEdits(list) {
    for (let k = 0; k + 1 < list.length; k += 2) {
      const i = list[k], id = list[k + 1];
      if (!(i >= 0 && i < this.data.length) || !(id >= 0 && id < 256)) continue;
      const x = i % W, z = ((i / W) | 0) % D, y = (i / (W * D)) | 0;
      const c = (x >> 4) + CX * (z >> 4);
      if (this.made[c]) { this.set(x, y, z, id); continue; }
      if (!this.pending.has(c)) this.pending.set(c, []);
      this.pending.get(c).push([i, id]);
    }
  }

  editList() {
    const out = [];
    for (const [i, id] of this.edits) out.push(i, id);
    for (const list of this.pending.values()) for (const [i, id] of list) out.push(i, id);
    return out;
  }

  // ---------- 3D shapes ----------
  dropMesh(s) {
    const old = this.meshes[s];
    if (!old) return;
    this.group.remove(old);
    old.geometry.dispose();
    this.meshes[s] = null;
  }

  buildSection(s, material) {
    const c = s % (CX * CZ), sy = (s / (CX * CZ)) | 0;
    const x0 = (c % CX) * CS, z0 = ((c / CX) | 0) * CS, y0 = sy * CS;
    const pos = [], col = [], uv = [], ind = [], lit = [];
    const data = this.data, vis = this.visual, top = this.top, glow = this.glow;
    const g = (x, y, z) => this.get(x, y, z);
    const occ = (x, y, z) => { const id = g(x, y, z); return OPAQUE[id] || isLeaves(id) ? 1 : 0; };
    let vc = 0;
    for (let y = y0; y < y0 + CS; y++) for (let z = z0; z < z0 + CS; z++) for (let x = x0; x < x0 + CS; x++) {
      const id = data[x + W * (z + D * y)];
      if (!id) continue;
      const bd = BLOCKS[vis[id]];
      if (PLANT[id]) {
        // A little X made of two pictures, seen from both sides.
        const open = y < top[x + W * z] ? 0 : 1, lamp = Math.min(1, (glow[x + W * (z + D * y)] / 255) * 1.3);
        const uvb = tileUV(bd.tiles[0]);
        for (const q of CROSS) {
          for (let k = 0; k < 4; k++) {
            pos.push(x + q[k][0], y + q[k][1], z + q[k][2]);
            col.push(0.9, 0.9, 0.9);
            lit.push(open, lamp);
            uv.push(uvb[UVC[k][0]], uvb[UVC[k][1]]);
          }
          ind.push(vc, vc + 1, vc + 2, vc + 2, vc + 3, vc, vc + 2, vc + 1, vc, vc, vc + 3, vc + 2);
          vc += 4;
        }
        continue;
      }
      for (let f = 0; f < 6; f++) {
        const F = FACES[f];
        const nx = x + F.n[0], ny = y + F.n[1], nz = z + F.n[2];
        const nid = g(nx, ny, nz);
        if (OPAQUE[nid]) continue;
        if (nid === id && id === B.GLASS) continue;
        // Two kinds of light, like Minecraft: sky light (changes with day and night) and lamp light.
        let open = 1, lamp = 0;
        if (nx >= 0 && nz >= 0 && nx < W && nz < D && ny < H) {
          if (ny < top[nx + W * nz]) open = 0;
          lamp = Math.min(1, (glow[nx + W * (nz + D * ny)] / 255) * 1.3);
        }
        const bright = GLOW[id] === 1;
        if (bright) { open = 1; lamp = 1; }
        const uvb = tileUV(bd.tiles[F.t]);
        const ao = F.tmp;
        for (let k = 0; k < 4; k++) {
          const cc = F.c[k], o = F.ao[k];
          const s1 = occ(nx + o[0], ny + o[1], nz + o[2]);
          const s2 = occ(nx + o[3], ny + o[4], nz + o[5]);
          const s3 = occ(nx + o[6], ny + o[7], nz + o[8]);
          ao[k] = s1 && s2 ? 0 : 3 - (s1 + s2 + s3);
          pos.push(x + cc[0], y + cc[1], z + cc[2]);
          const br = bright ? 1 : F.s * AO[ao[k]];
          col.push(br, br, br);
          lit.push(open, lamp);
          uv.push(uvb[UVC[k][0]], uvb[UVC[k][1]]);
        }
        if (ao[0] + ao[2] < ao[1] + ao[3]) ind.push(vc + 1, vc + 2, vc + 3, vc + 3, vc, vc + 1);
        else ind.push(vc, vc + 1, vc + 2, vc + 2, vc + 3, vc);
        vc += 4;
      }
    }
    this.dropMesh(s);
    if (!vc) return;
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
    geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    geo.setAttribute('lit', new THREE.Float32BufferAttribute(lit, 2));
    geo.setIndex(vc > 65535 ? new THREE.Uint32BufferAttribute(ind, 1) : new THREE.Uint16BufferAttribute(ind, 1));
    geo.computeBoundingSphere();
    const mesh = new THREE.Mesh(geo, material);
    mesh.matrixAutoUpdate = false;
    this.meshes[s] = mesh;
    this.group.add(mesh);
  }

  // Walk along a line and find the first block (plants count too). Returns the block and the face we hit.
  raycast(o, d, maxDist) {
    let x = Math.floor(o.x), y = Math.floor(o.y), z = Math.floor(o.z);
    const stepX = d.x > 0 ? 1 : -1, stepY = d.y > 0 ? 1 : -1, stepZ = d.z > 0 ? 1 : -1;
    const tdx = d.x ? Math.abs(1 / d.x) : Infinity, tdy = d.y ? Math.abs(1 / d.y) : Infinity, tdz = d.z ? Math.abs(1 / d.z) : Infinity;
    let tx = d.x ? (d.x > 0 ? x + 1 - o.x : o.x - x) * tdx : Infinity;
    let ty = d.y ? (d.y > 0 ? y + 1 - o.y : o.y - y) * tdy : Infinity;
    let tz = d.z ? (d.z > 0 ? z + 1 - o.z : o.z - z) * tdz : Infinity;
    let nx = 0, ny = 0, nz = 0, t = 0;
    while (t <= maxDist) {
      const id = this.get(x, y, z);
      if (id) return { x, y, z, id, nx, ny, nz, t };
      if (tx < ty && tx < tz) { x += stepX; t = tx; tx += tdx; nx = -stepX; ny = 0; nz = 0; }
      else if (ty < tz) { y += stepY; t = ty; ty += tdy; nx = 0; ny = -stepY; nz = 0; }
      else { z += stepZ; t = tz; tz += tdz; nx = 0; ny = 0; nz = -stepZ; }
    }
    return null;
  }
}
