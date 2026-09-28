// The block world: making the land, changing blocks, and building the 3D shapes.
import * as THREE from '../lib/three.min.js';
import { B, BLOCKS, SOLID, OPAQUE, SHADOW, GLOW } from './blocks.js';
import { ORES, MONEY_ORE } from './data.js';
import { tileUV } from './atlas.js';
import { rng, noise3, fbm2, smoothstep, lerp } from './noise.js';

export const W = 128, H = 64, D = 128;
export const SEA = 20;
export const GROUND = 25;               // top block of the town, you stand at y = 26
export const TOWN = { x: 64, z: 58 };
const CS = 16;                          // section size
const LAMP_R = 6;                       // how far a lamp shines
const SX = W / CS, SY = H / CS, SZ = D / CS;

// Regions: what part of town a block belongs to.
export const R = { NONE: 0, MINE: 1, SHOP: 2, LEMON: 10, PIZZA: 11, FACTORY: 12 };
export const isProtected = (r) => r >= 2;

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

export class World {
  constructor(seed) {
    this.seed = seed;
    this.data = new Uint8Array(W * H * D);
    this.region = new Uint8Array(W * H * D);
    this.glow = new Uint8Array(W * H * D);     // light from lamps, 0..255
    this.top = new Int16Array(W * D).fill(-1);
    this.visual = new Uint8Array(256);  // what each block looks like (locked ores look like stone)
    for (let i = 0; i < 256; i++) this.visual[i] = i;
    this.edits = new Map();              // changes the player made (saved)
    this.base = null;
    this.meshes = new Array(SX * SY * SZ).fill(null);
    this.dirty = new Set();
    this.group = new THREE.Group();
    this.mineCells = [];
  }

  idx(x, y, z) { return x + W * (z + D * y); }
  inside(x, y, z) { return x >= 0 && y >= 0 && z >= 0 && x < W && y < H && z < D; }

  get(x, y, z) {
    if (y < 0) return B.BEDROCK;
    if (x < 0 || z < 0 || x >= W || z >= D || y >= H) return 0;
    return this.data[x + W * (z + D * y)];
  }

  regionAt(x, y, z) {
    if (!this.inside(x, y, z)) return 0;
    return this.region[x + W * (z + D * y)];
  }

  // Change one block. record=true means the player did it (it goes in the save).
  set(x, y, z, id, record = true) {
    if (!this.inside(x, y, z)) return;
    const i = this.idx(x, y, z);
    const old = this.data[i];
    if (old === id) return;
    this.data[i] = id;
    if (old === B.LAMP || id === B.LAMP) this.relight(x, y, z);
    if (record && this.base) {
      if (this.base[i] === id) this.edits.delete(i);
      else this.edits.set(i, id);
    }
    const oldTop = this.top[x + W * z];
    this.fixTop(x, z);
    const newTop = this.top[x + W * z];
    this.markAround(x, y, z);
    if (oldTop !== newTop) {
      // Shadows below changed: redo the sections in this column and its neighbours.
      const y0 = Math.max(0, Math.min(oldTop, newTop) - 1), y1 = Math.min(H - 1, Math.max(oldTop, newTop) + 1);
      for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++)
        for (let sy = (y0 / CS) | 0; sy <= ((y1 / CS) | 0); sy++) this.markSection(x + dx, sy * CS, z + dz);
    }
  }

  fixTop(x, z) {
    let y = H - 1;
    const col = x + W * z;
    while (y >= 0 && !SHADOW[this.data[col + W * D * y]]) y--;
    this.top[col] = y;
  }

  markSection(x, y, z) {
    if (!this.inside(x, y, z)) return;
    this.dirty.add(((x / CS) | 0) + SX * (((z / CS) | 0) + SZ * ((y / CS) | 0)));
  }

  markAround(x, y, z) {
    for (let dy = -1; dy <= 1; dy++) for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++)
      this.markSection(x + dx, y + dy, z + dz);
  }

  markAll() {
    for (let i = 0; i < this.meshes.length; i++) this.dirty.add(i);
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
      this.markSection(Math.min(x, x1), Math.min(y, y1), Math.min(z, z1));
  }

  // Locked ores look like stone. Call this when you buy a new material.
  setUnlocked(count) {
    ORES.forEach((o, i) => (this.visual[o.id] = i < count ? o.id : B.STONE));
    this.markAll();
  }

  // ---------- Making the world ----------
  generate() {
    const seed = this.seed;
    const r = rng(seed);
    const heights = new Int16Array(W * D);
    this.ocean = new Uint8Array(W * D);   // 1 = sea water on top of this spot
    for (let z = 0; z < D; z++) for (let x = 0; x < W; x++) {
      const n = fbm2(x / 40, z / 40, seed, 4);
      const m = fbm2(x / 90 + 100, z / 90, seed + 7, 2);
      let h = 17 + n * 22 + (m - 0.5) * 12;
      const dx = (x - 64) / 64, dz = (z - 64) / 64;
      h -= smoothstep(0.62, 0.98, Math.sqrt(dx * dx + dz * dz)) * 22;
      const td = Math.max(Math.abs(x - TOWN.x), Math.abs(z - TOWN.z));
      h = lerp(h, GROUND + 1, 1 - smoothstep(31, 44, td));
      h = Math.max(4, Math.min(H - 10, Math.round(h)));
      heights[x + W * z] = h;
      this.ocean[x + W * z] = h < SEA ? 1 : 0;
      for (let y = 0; y < h; y++) {
        let id;
        if (y === 0 || (y === 1 && r() < 0.5)) id = B.BEDROCK;
        else if (y < h - 4) id = B.STONE;
        else if (h - 1 <= SEA + 1) id = B.SAND;
        else if (y < h - 1) id = B.DIRT;
        else id = B.GRASS;
        this.data[this.idx(x, y, z)] = id;
      }
    }
    // Caves: twisty tunnels, but not under the town.
    for (let z = 0; z < D; z++) for (let x = 0; x < W; x++) {
      const td = Math.max(Math.abs(x - TOWN.x), Math.abs(z - TOWN.z));
      if (td < 36) continue;
      const h = heights[x + W * z];
      for (let y = 3; y < h - 5; y++) {
        const a = noise3(x / 16, y / 11, z / 16, seed + 11);
        if (Math.abs(a - 0.5) > 0.05) continue;
        const b = noise3(x / 16, y / 11, z / 16, seed + 23);
        if (Math.abs(b - 0.5) < 0.1) this.data[this.idx(x, y, z)] = 0;
      }
    }
    // Ore veins. Locked ones hide as stone until you buy them.
    const vein = (id, [y0, y1], count, size) => {
      for (let v = 0; v < count; v++) {
        let x = (r() * W) | 0, y = y0 + ((r() * (y1 - y0)) | 0), z = (r() * D) | 0;
        const n = size[0] + ((r() * (size[1] - size[0] + 1)) | 0);
        for (let k = 0; k < n; k++) {
          if (this.inside(x, y, z) && this.data[this.idx(x, y, z)] === B.STONE) this.data[this.idx(x, y, z)] = id;
          const d = (r() * 6) | 0;
          if (d === 0) x++; else if (d === 1) x--; else if (d === 2) y++; else if (d === 3) y--; else if (d === 4) z++; else z--;
        }
      }
    };
    ORES.forEach((o) => vein(o.id, o.y, o.veins, [3, 7]));
    vein(B.MONEY_ORE, MONEY_ORE.y, MONEY_ORE.veins, [1, 4]);
    // Trees.
    const trees = [];
    for (let t = 0; t < 700 && trees.length < 150; t++) {
      const x = 3 + ((r() * (W - 6)) | 0), z = 3 + ((r() * (D - 6)) | 0);
      const td = Math.max(Math.abs(x - TOWN.x), Math.abs(z - TOWN.z));
      if (td < 36) continue;
      const h = heights[x + W * z];
      if (this.get(x, h - 1, z) !== B.GRASS) continue;
      if (trees.some(([a, b]) => Math.abs(a - x) + Math.abs(b - z) < 5)) continue;
      trees.push([x, z]);
      this.tree(x, h, z, r);
    }
  }

  tree(x, y, z, r) {
    const th = 4 + ((r() * 3) | 0);
    for (let i = 0; i < th; i++) this.data[this.idx(x, y + i, z)] = B.LOG;
    for (let dy = th - 3; dy <= th; dy++) {
      const rad = dy >= th - 1 ? 1 : 2;
      for (let dz = -rad; dz <= rad; dz++) for (let dx = -rad; dx <= rad; dx++) {
        if (Math.abs(dx) === rad && Math.abs(dz) === rad && (rad === 1 ? dy === th : r() < 0.5)) continue;
        const X = x + dx, Y = y + dy, Z = z + dz;
        if (this.inside(X, Y, Z) && !this.data[this.idx(X, Y, Z)]) this.data[this.idx(X, Y, Z)] = B.LEAVES;
      }
    }
  }

  // After the land and town are made: remember it so we only save changes.
  finish() {
    this.base = this.data.slice();
    this.lightAll();
    for (let z = 0; z < D; z++) for (let x = 0; x < W; x++) this.fixTop(x, z);
    this.markAll();
  }

  // Undo everything the player changed (for NEW WORLD).
  resetToBase() {
    this.data.set(this.base);
    this.edits.clear();
    for (let z = 0; z < D; z++) for (let x = 0; x < W; x++) this.fixTop(x, z);
    this.lightAll();
    this.markAll();
  }

  lightAll() {
    this.glow.fill(0);
    for (let i = 0; i < this.data.length; i++) {
      if (this.data[i] !== B.LAMP) continue;
      this.addGlow(i % W, (i / (W * D)) | 0, ((i / W) | 0) % D);
    }
  }

  applyEdits(list) {
    for (let k = 0; k < list.length; k += 2) {
      const i = list[k], id = list[k + 1];
      if (i < 0 || i >= this.data.length) continue;
      this.data[i] = id;
      if (this.base[i] === id) this.edits.delete(i);
      else this.edits.set(i, id);
    }
    for (let z = 0; z < D; z++) for (let x = 0; x < W; x++) this.fixTop(x, z);
    this.lightAll();
    this.markAll();
  }

  editList() {
    const out = [];
    for (const [i, id] of this.edits) out.push(i, id);
    return out;
  }

  // ---------- 3D shapes ----------
  // Rebuild changed sections. Stops after `budgetMs` so the game stays smooth.
  remesh(material, budgetMs = 6) {
    const t0 = performance.now();
    for (const s of this.dirty) {
      this.dirty.delete(s);
      this.buildSection(s, material);
      if (performance.now() - t0 > budgetMs) break;
    }
  }

  buildSection(s, material) {
    const sx = s % SX, sz = ((s / SX) | 0) % SZ, sy = (s / (SX * SZ)) | 0;
    const x0 = sx * CS, y0 = sy * CS, z0 = sz * CS;
    const pos = [], col = [], uv = [], ind = [];
    const data = this.data, vis = this.visual, top = this.top, glow = this.glow;
    const g = (x, y, z) => this.get(x, y, z);
    const occ = (x, y, z) => (OPAQUE[g(x, y, z)] || g(x, y, z) === B.LEAVES ? 1 : 0);
    let vc = 0;
    for (let y = y0; y < y0 + CS; y++) for (let z = z0; z < z0 + CS; z++) for (let x = x0; x < x0 + CS; x++) {
      const id = data[x + W * (z + D * y)];
      if (!id) continue;
      const bd = BLOCKS[vis[id]];
      for (let f = 0; f < 6; f++) {
        const F = FACES[f];
        const nx = x + F.n[0], ny = y + F.n[1], nz = z + F.n[2];
        const nid = g(nx, ny, nz);
        if (OPAQUE[nid]) continue;
        if (nid === id && id === B.GLASS) continue;
        // Covered from the sky? Then it is in shadow.
        let light = 1;
        if (nx >= 0 && nz >= 0 && nx < W && nz < D && ny < top[nx + W * nz]) {
          light = 0.55;
          if (ny < H) light = Math.min(1, light + glow[nx + W * (nz + D * ny)] / 400);
        }
        if (GLOW[id]) light = 1.25;
        const uvb = tileUV(bd.tiles[F.t]);
        const ao = F.tmp;
        for (let k = 0; k < 4; k++) {
          const c = F.c[k], o = F.ao[k];
          const s1 = occ(nx + o[0], ny + o[1], nz + o[2]);
          const s2 = occ(nx + o[3], ny + o[4], nz + o[5]);
          const s3 = occ(nx + o[6], ny + o[7], nz + o[8]);
          ao[k] = s1 && s2 ? 0 : 3 - (s1 + s2 + s3);
          pos.push(x + c[0], y + c[1], z + c[2]);
          const br = light > 1 ? 1 : F.s * AO[ao[k]] * light;
          col.push(br, br, br);
          uv.push(uvb[UVC[k][0]], uvb[UVC[k][1]]);
        }
        if (ao[0] + ao[2] < ao[1] + ao[3]) ind.push(vc + 1, vc + 2, vc + 3, vc + 3, vc, vc + 1);
        else ind.push(vc, vc + 1, vc + 2, vc + 2, vc + 3, vc);
        vc += 4;
      }
    }
    const old = this.meshes[s];
    if (old) {
      this.group.remove(old);
      old.geometry.dispose();
      this.meshes[s] = null;
    }
    if (!vc) return;
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
    geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    geo.setIndex(vc > 65535 ? new THREE.Uint32BufferAttribute(ind, 1) : new THREE.Uint16BufferAttribute(ind, 1));
    geo.computeBoundingSphere();
    const mesh = new THREE.Mesh(geo, material);
    mesh.matrixAutoUpdate = false;
    this.meshes[s] = mesh;
    this.group.add(mesh);
  }

  // Walk along a line and find the first block. Returns the block and the face we hit.
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
      if (id && SOLID[id]) return { x, y, z, id, nx, ny, nz, t };
      if (tx < ty && tx < tz) { x += stepX; t = tx; tx += tdx; nx = -stepX; ny = 0; nz = 0; }
      else if (ty < tz) { y += stepY; t = ty; ty += tdy; nx = 0; ny = -stepY; nz = 0; }
      else { z += stepZ; t = tz; tz += tdz; nx = 0; ny = 0; nz = -stepZ; }
    }
    return null;
  }
}
