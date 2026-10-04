// Things that make it look alive: bits flying, +$ numbers, signs, the pickaxe, clouds, sky.
import * as THREE from '../lib/three.min.js';
import { avgColor, tileUV } from './atlas.js';
import { T } from './blocks.js';
import { rng } from './noise.js';

const FONT = '"Luckiest Guy", "Arial Black", sans-serif';

// ---------- Flying bits ----------
const MAX_BITS = 300;
export class Bits {
  constructor(scene) {
    this.mesh = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshBasicMaterial(), MAX_BITS);
    this.mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.mesh.frustumCulled = false;
    this.list = [];
    this.m = new THREE.Matrix4();
    this.c = new THREE.Color();
    for (let i = 0; i < MAX_BITS; i++) this.mesh.setColorAt(i, this.c.setRGB(1, 1, 1));
    scene.add(this.mesh);
  }

  burst(x, y, z, id, n = 14, colors = null) {
    const base = avgColor(id);
    for (let i = 0; i < n; i++) {
      if (this.list.length >= MAX_BITS) this.list.shift();
      const col = colors ? colors[i % colors.length] : base;
      const k = 0.8 + Math.random() * 0.35;
      this.list.push({
        x: x + 0.2 + Math.random() * 0.6, y: y + 0.2 + Math.random() * 0.6, z: z + 0.2 + Math.random() * 0.6,
        vx: (Math.random() - 0.5) * 4, vy: 2 + Math.random() * 4, vz: (Math.random() - 0.5) * 4,
        life: 0.5 + Math.random() * 0.5, size: colors ? 0.16 : 0.1 + Math.random() * 0.08,
        r: col[0] * k, g: col[1] * k, b: col[2] * k,
      });
    }
  }

  update(dt, world) {
    const m = this.m;
    let n = 0;
    for (let i = this.list.length - 1; i >= 0; i--) {
      const p = this.list[i];
      p.life -= dt;
      if (p.life <= 0) { this.list.splice(i, 1); continue; }
      if (!p.float) {
        p.vy -= 20 * dt;
        const ny = p.y + p.vy * dt;
        if (world.get(Math.floor(p.x), Math.floor(ny - p.size / 2), Math.floor(p.z))) { p.vy *= -0.3; p.vx *= 0.6; p.vz *= 0.6; }
        else p.y = ny;
      } else p.y += p.vy * dt;
      p.x += p.vx * dt;
      p.z += p.vz * dt;
    }
    for (const p of this.list) {
      const s = p.float ? p.size * Math.min(1, p.life) : p.size;
      m.makeScale(s, s, s);
      m.setPosition(p.x, p.y, p.z);
      this.mesh.setMatrixAt(n, m);
      this.mesh.setColorAt(n, this.c.setRGB(p.r, p.g, p.b));
      n++;
    }
    this.mesh.count = n;
    this.mesh.instanceMatrix.needsUpdate = true;
    if (this.mesh.instanceColor) this.mesh.instanceColor.needsUpdate = true;
  }
}

// ---------- Text pictures (signs, +$ numbers) ----------
function textCanvas(lines, opts = {}) {
  const size = opts.size || 64;
  const pad = opts.pad ?? 18;
  const c = document.createElement('canvas');
  const g = c.getContext('2d');
  const fonts = lines.map((l, i) => `${i === 0 ? size : Math.round(size * 0.62)}px ${FONT}`);
  let w = 0;
  lines.forEach((l, i) => { g.font = fonts[i]; w = Math.max(w, g.measureText(l).width); });
  const lh = lines.map((l, i) => (i === 0 ? size : size * 0.62) * 1.12);
  c.width = Math.ceil(w + pad * 2 + 12);
  c.height = Math.ceil(lh.reduce((a, b) => a + b, 0) + pad * 2);
  if (opts.bg) {
    g.fillStyle = opts.border || '#1b0d2e';
    roundRect(g, 0, 0, c.width, c.height, 22);
    g.fill();
    g.fillStyle = opts.bg;
    roundRect(g, 6, 6, c.width - 12, c.height - 12, 18);
    g.fill();
  }
  let y = pad;
  lines.forEach((l, i) => {
    g.font = fonts[i];
    g.textAlign = 'center';
    g.textBaseline = 'top';
    g.lineJoin = 'round';
    g.lineWidth = size * 0.16;
    g.strokeStyle = opts.stroke || '#1b0d2e';
    g.strokeText(l, c.width / 2, y + 4);
    g.fillStyle = i === 0 ? opts.color || '#fff' : opts.color2 || '#fff';
    g.fillText(l, c.width / 2, y + 4);
    y += lh[i];
  });
  return c;
}

function roundRect(g, x, y, w, h, r) {
  g.beginPath();
  g.moveTo(x + r, y);
  g.arcTo(x + w, y, x + w, y + h, r);
  g.arcTo(x + w, y + h, x, y + h, r);
  g.arcTo(x, y + h, x, y, r);
  g.arcTo(x, y, x + w, y, r);
  g.closePath();
}

function spriteFrom(canvas, height) {
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.minFilter = THREE.LinearFilter;
  tex.generateMipmaps = false;
  const mat = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, fog: false });
  const s = new THREE.Sprite(mat);
  s.scale.set((height * canvas.width) / canvas.height, height, 1);
  return s;
}

export class Sign {
  constructor(scene, x, y, z, lines, opts = {}) {
    this.scene = scene;
    this.opts = opts;
    this.height = opts.height || 1.3;
    this.sprite = null;
    this.key = '';
    this.pos = new THREE.Vector3(x, y, z);
    this.set(lines);
  }
  set(lines, pos) {
    if (pos) this.pos.set(pos.x, pos.y, pos.z);
    const key = lines.join('|');
    if (key === this.key) { if (this.sprite) this.sprite.position.copy(this.pos); return; }
    this.key = key;
    if (this.sprite) {
      this.scene.remove(this.sprite);
      this.sprite.material.map.dispose();
      this.sprite.material.dispose();
    }
    this.sprite = spriteFrom(textCanvas(lines, { bg: '#fff6d6', color: '#1b0d2e', color2: '#1b0d2e', stroke: '#fff6d6', ...this.opts }), this.height * (lines.length > 1 ? 1.35 : 1));
    this.sprite.position.copy(this.pos);
    this.scene.add(this.sprite);
  }
}

// "+$12" numbers that float up and fade.
export class Popups {
  constructor(scene) {
    this.scene = scene;
    this.list = [];
    this.cache = new Map();
  }
  add(text, x, y, z, color = '#5dff7a', big = false) {
    const key = text + color + big;
    let canvas = this.cache.get(key);
    if (!canvas) {
      canvas = textCanvas([text], { size: big ? 90 : 64, color, pad: 6 });
      if (this.cache.size > 80) this.cache.clear();
      this.cache.set(key, canvas);
    }
    const s = spriteFrom(canvas, big ? 1.2 : 0.7);
    s.material.depthTest = false;
    s.renderOrder = 10;
    s.position.set(x, y, z);
    this.scene.add(s);
    this.list.push({ s, life: big ? 2 : 1.2, max: big ? 2 : 1.2, h: s.scale.y });
  }
  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const p = this.list[i];
      p.life -= dt;
      p.s.position.y += dt * 1.2;
      const t = p.life / p.max;
      p.s.material.opacity = Math.min(1, t * 2.5);
      if (p.life <= 0) {
        this.scene.remove(p.s);
        p.s.material.map.dispose();
        p.s.material.dispose();
        this.list.splice(i, 1);
      }
    }
  }
}

// ---------- The block you are looking at ----------
export class Target {
  constructor(scene, atlasTex) {
    const edges = new THREE.EdgesGeometry(new THREE.BoxGeometry(1.004, 1.004, 1.004));
    this.box = new THREE.LineSegments(edges, new THREE.LineBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.55 }));
    this.box.visible = false;
    scene.add(this.box);
    // Cracks while mining.
    this.crackGeo = new THREE.BoxGeometry(1.01, 1.01, 1.01);
    this.crack = new THREE.Mesh(this.crackGeo, new THREE.MeshBasicMaterial({
      map: atlasTex, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -1, fog: false,
    }));
    this.crack.visible = false;
    this.stage = -1;
    scene.add(this.crack);
  }
  show(hit, progress) {
    if (!hit) { this.box.visible = false; this.crack.visible = false; return; }
    this.box.visible = true;
    this.box.position.set(hit.x + 0.5, hit.y + 0.5, hit.z + 0.5);
    if (progress <= 0) { this.crack.visible = false; return; }
    const stage = Math.min(4, Math.floor(progress * 5));
    if (stage !== this.stage) {
      this.stage = stage;
      const [u0, v0, u1, v1] = tileUV(T['crack' + stage]);
      const uv = this.crackGeo.attributes.uv;
      for (let f = 0; f < 6; f++) {
        uv.setXY(f * 4 + 0, u0, v1);
        uv.setXY(f * 4 + 1, u1, v1);
        uv.setXY(f * 4 + 2, u0, v0);
        uv.setXY(f * 4 + 3, u1, v0);
      }
      uv.needsUpdate = true;
    }
    this.crack.visible = true;
    this.crack.position.copy(this.box.position);
  }
}

// ---------- Pickaxe in your hand ----------
export class Hand {
  constructor() {
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(60, 1, 0.01, 10);
    this.group = new THREE.Group();
    this.scene.add(this.group);
    const mat = (c) => new THREE.MeshBasicMaterial({ color: c });
    this.handle = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.62, 0.07), mat(0x8a5a2b));
    this.head = new THREE.Group();
    this.headMat = mat(0xa0703f);
    this.tipMat = mat(0xffffff);
    const mid = new THREE.Mesh(new THREE.BoxGeometry(0.34, 0.1, 0.1), this.headMat);
    const l = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.09, 0.09), this.headMat);
    const r = l.clone();
    l.position.set(-0.2, -0.05, 0);
    r.position.set(0.2, -0.05, 0);
    const tl = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.07, 0.07), this.tipMat);
    const tr = tl.clone();
    tl.position.set(-0.3, -0.1, 0);
    tr.position.set(0.3, -0.1, 0);
    this.head.add(mid, l, r, tl, tr);
    this.head.position.y = 0.3;
    this.pick = new THREE.Group();
    this.pick.add(this.handle, this.head);
    this.pick.scale.setScalar(0.75);
    this.group.add(this.pick);
    this.swing = 0;
    this.t = 0;
  }
  setColor(hex) {
    this.headBase = new THREE.Color(hex);
    this.tipBase = new THREE.Color(hex).lerp(new THREE.Color(0xffffff), 0.45);
    this.light(this.lit || 1);
  }
  // Darker at night.
  light(k) {
    this.lit = k;
    if (!this.headBase) return;
    this.headMat.color.copy(this.headBase).multiplyScalar(k);
    this.tipMat.color.copy(this.tipBase).multiplyScalar(k);
    this.handle.material.color.setHex(0x8a5a2b).multiplyScalar(k);
  }
  update(dt, mining, walked, aspect) {
    this.camera.aspect = aspect;
    this.camera.updateProjectionMatrix();
    this.t += dt;
    if (mining) this.swing += dt * 11;
    else this.swing = this.swing % (Math.PI * 2) > 0.2 ? this.swing + dt * 11 : 0;
    const s = Math.sin(this.swing);
    const bobX = Math.sin(walked * 2.2) * 0.02, bobY = Math.abs(Math.cos(walked * 2.2)) * 0.02;
    this.pick.position.set(0.5 + bobX, -0.5 + bobY - Math.max(0, s) * 0.06, -1.1);
    this.pick.rotation.set(-0.5 - Math.max(0, s) * 0.9, 0.35, -0.25);
  }
}

// ---------- Sky and clouds ----------
export function makeSky(scene) {
  const geo = new THREE.SphereGeometry(400, 24, 12);
  const colors = [];
  const top = new THREE.Color('#3a8ef0'), mid = new THREE.Color('#8fd0ff'), low = new THREE.Color('#d9f2ff');
  const p = geo.attributes.position;
  const c = new THREE.Color();
  for (let i = 0; i < p.count; i++) {
    const h = p.getY(i) / 400;
    if (h > 0.15) c.copy(mid).lerp(top, Math.min(1, (h - 0.15) / 0.6));
    else c.copy(low).lerp(mid, Math.max(0, (h + 0.05) / 0.2));
    colors.push(c.r, c.g, c.b);
  }
  geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
  const sky = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide, fog: false, depthWrite: false }));
  sky.renderOrder = -10;
  scene.add(sky);
  return sky;
}

export function makeClouds(scene) {
  const r = rng(7);
  const g = new THREE.Group();
  const mat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.85, fog: false });
  const box = new THREE.BoxGeometry(1, 1, 1);
  const count = 70;
  const inst = new THREE.InstancedMesh(box, mat, count);
  const m = new THREE.Matrix4();
  for (let i = 0; i < count; i++) {
    const w = 8 + r() * 22, d = 6 + r() * 16;
    m.makeScale(w, 2.5, d);
    m.setPosition(-200 + r() * 520, 0, -200 + r() * 520);
    inst.setMatrixAt(i, m);
  }
  g.add(inst);
  g.position.y = 78;
  scene.add(g);
  return g;
}

// Water only over the sea, so deep holes on land stay dry.
export function makeWater(scene, sea, world, W, D) {
  const tex = new THREE.CanvasTexture(waterCanvas());
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.magFilter = THREE.NearestFilter;
  tex.colorSpace = THREE.SRGBColorSpace;
  const pos = [], uv = [];
  const quad = (x0, z0, x1, z1) => {
    const y = sea - 0.12;
    pos.push(x0, y, z0, x0, y, z1, x1, y, z1, x0, y, z0, x1, y, z1, x1, y, z0);
    uv.push(x0, z0, x0, z1, x1, z1, x0, z0, x1, z1, x1, z0);
  };
  for (let z = 0; z < D; z++) {
    let run = -1;
    for (let x = 0; x <= W; x++) {
      const wet = x < W && world.ocean[x + W * z];
      if (wet && run < 0) run = x;
      if (!wet && run >= 0) { quad(run, z, x, z + 1); run = -1; }
    }
  }
  const F = 300;
  quad(-F, -F, W + F, 0);
  quad(-F, D, W + F, D + F);
  quad(-F, 0, 0, D);
  quad(W, 0, W + F, D);
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  const mat = new THREE.MeshBasicMaterial({ map: tex, transparent: true, opacity: 0.78, depthWrite: false, side: THREE.DoubleSide });
  const water = new THREE.Mesh(geo, mat);
  water.renderOrder = 2;
  scene.add(water);
  return water;
}

function waterCanvas() {
  const c = document.createElement('canvas');
  c.width = c.height = 16;
  const g = c.getContext('2d');
  const r = rng(3);
  for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
    const k = r();
    g.fillStyle = k < 0.15 ? '#5aa8f0' : k < 0.3 ? '#2f6fd0' : '#3f86e0';
    g.fillRect(x, y, 1, 1);
  }
  return c;
}

export { textCanvas };
