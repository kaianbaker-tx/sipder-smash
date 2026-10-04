// Creatures, like in Minecraft.
// Zombies come out at night, chase you and hit you. They burn when the sun comes up
// and they are scared of lamps. Pigs, cows and chickens walk around and give you food.
import * as THREE from '../lib/three.min.js';
import { Player } from './player.js';
import { B, SOLID } from './blocks.js';
import { W, D } from './world.js';

const SCARED = 50;         // lamp light that zombies will not walk into

export const KINDS = {
  zombie: { hp: 10, speed: 0.55, h: 1.95, w: 0.35, hostile: true },
  pig: { hp: 6, speed: 0.3, h: 0.95, w: 0.45, food: B.PORK, say: 'oink' },
  cow: { hp: 8, speed: 0.28, h: 1.45, w: 0.5, food: B.BEEF, say: 'moo' },
  chicken: { hp: 4, speed: 0.35, h: 0.95, w: 0.3, food: B.CHICKEN, say: 'cluck' },
};

// A box with darker sides, like the blocks.
const geoCache = new Map();
function shadedBox(w, h, d, color) {
  const key = [w, h, d, color].join();
  if (geoCache.has(key)) return geoCache.get(key);
  const g = new THREE.BoxGeometry(w, h, d);
  const shade = [0.8, 0.8, 1, 0.5, 0.65, 0.65];
  const c = new THREE.Color(color), cols = [];
  for (let f = 0; f < 6; f++) for (let v = 0; v < 4; v++) cols.push(c.r * shade[f], c.g * shade[f], c.b * shade[f]);
  g.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
  geoCache.set(key, g);
  return g;
}

// Models face -Z (forward). Each one returns its legs (and arms) so they can swing.
function build(kind, mat) {
  const g = new THREE.Group();
  const box = (w, h, d, color, x, y, z, parent = g) => {
    const m = new THREE.Mesh(shadedBox(w, h, d, color), mat);
    m.position.set(x, y, z);
    parent.add(m);
    return m;
  };
  const pivot = (x, y, z) => { const p = new THREE.Group(); p.position.set(x, y, z); g.add(p); return p; };
  const legs = [], arms = [];
  if (kind === 'zombie') {
    box(0.5, 0.5, 0.5, '#5e9e4a', 0, 1.65, 0);
    box(0.12, 0.08, 0.02, '#101010', -0.11, 1.68, -0.255);
    box(0.12, 0.08, 0.02, '#101010', 0.11, 1.68, -0.255);
    box(0.5, 0.75, 0.26, '#2aa5ad', 0, 1.125, 0);
    for (const x of [-0.37, 0.37]) {
      const p = pivot(x, 1.38, 0);
      box(0.24, 0.24, 0.72, '#5e9e4a', 0, 0, -0.3, p);
      box(0.26, 0.26, 0.3, '#2aa5ad', 0, 0, -0.02, p);
      arms.push(p);
    }
    for (const x of [-0.125, 0.125]) {
      const p = pivot(x, 0.75, 0);
      box(0.25, 0.75, 0.25, '#3a43a6', 0, -0.375, 0, p);
      legs.push(p);
    }
  } else if (kind === 'pig') {
    box(0.62, 0.55, 0.95, '#f2a3ae', 0, 0.62, 0);
    box(0.5, 0.48, 0.45, '#f2a3ae', 0, 0.8, -0.62);
    box(0.24, 0.16, 0.06, '#e07f90', 0, 0.74, -0.87);
    box(0.08, 0.08, 0.02, '#111111', -0.14, 0.88, -0.85);
    box(0.08, 0.08, 0.02, '#111111', 0.14, 0.88, -0.85);
    for (const [x, z] of [[-0.19, -0.3], [0.19, -0.3], [-0.19, 0.3], [0.19, 0.3]]) {
      const p = pivot(x, 0.36, z);
      box(0.2, 0.36, 0.2, '#e8919f', 0, -0.18, 0, p);
      legs.push(p);
    }
  } else if (kind === 'cow') {
    box(0.75, 0.72, 1.15, '#4b3426', 0, 1.0, 0);
    box(0.77, 0.32, 0.42, '#efefef', 0, 1.12, 0.18);
    box(0.55, 0.5, 0.4, '#4b3426', 0, 1.26, -0.76);
    box(0.32, 0.22, 0.03, '#efefef', 0, 1.13, -0.97);
    box(0.08, 0.08, 0.02, '#111111', -0.16, 1.34, -0.97);
    box(0.08, 0.08, 0.02, '#111111', 0.16, 1.34, -0.97);
    box(0.08, 0.14, 0.08, '#e8e0c8', -0.31, 1.52, -0.76);
    box(0.08, 0.14, 0.08, '#e8e0c8', 0.31, 1.52, -0.76);
    for (const [x, z] of [[-0.24, -0.4], [0.24, -0.4], [-0.24, 0.4], [0.24, 0.4]]) {
      const p = pivot(x, 0.64, z);
      box(0.24, 0.64, 0.24, '#3a281c', 0, -0.32, 0, p);
      legs.push(p);
    }
  } else {
    box(0.42, 0.42, 0.52, '#f4f4f4', 0, 0.5, 0);
    box(0.28, 0.36, 0.26, '#f4f4f4', 0, 0.86, -0.3);
    box(0.18, 0.1, 0.14, '#f0a020', 0, 0.86, -0.49);
    box(0.1, 0.12, 0.06, '#d02020', 0, 0.74, -0.45);
    box(0.06, 0.06, 0.02, '#111111', -0.1, 0.93, -0.435);
    box(0.06, 0.06, 0.02, '#111111', 0.1, 0.93, -0.435);
    box(0.06, 0.26, 0.38, '#e2e2e2', -0.24, 0.55, 0);
    box(0.06, 0.26, 0.38, '#e2e2e2', 0.24, 0.55, 0);
    for (const x of [-0.1, 0.1]) {
      const p = pivot(x, 0.3, 0.02);
      box(0.06, 0.3, 0.06, '#f0a020', 0, -0.15, 0, p);
      legs.push(p);
    }
  }
  return { group: g, legs, arms };
}

class Mob {
  constructor(world, scene, kind, x, y, z) {
    this.kind = kind;
    this.k = KINDS[kind];
    this.body = new Player(world);
    this.body.pos.x = x; this.body.pos.y = y; this.body.pos.z = z;
    this.body.autoJump = true;
    this.body.yaw = Math.random() * Math.PI * 2;
    this.hp = this.k.hp;
    this.hitCool = 0.8;
    this.flash = 0;
    this.burn = 0;
    this.rise = this.k.hostile ? 1 : 0;
    this.walk = 0;
    this.swing = 0;
    this.think = 0;
    this.go = 0;
    this.flee = 0;
    this.talk = 3 + Math.random() * 10;
    this.mat = new THREE.MeshBasicMaterial({ vertexColors: true });
    Object.assign(this, build(kind, this.mat));
    scene.add(this.group);
  }
}

export class Mobs {
  constructor(world, scene, bits, sfx) {
    this.world = world;
    this.scene = scene;
    this.bits = bits;
    this.sfx = sfx;
    this.list = [];
    this.zombieTimer = 3;
    this.animalTimer = 1;
    this.color = new THREE.Color();
  }

  count(hostile) { return this.list.filter((m) => !!m.k.hostile === hostile).length; }
  zombiesNear(p, r) { return this.list.some((m) => m.k.hostile && Math.hypot(m.body.pos.x - p.x, m.body.pos.z - p.z) < r); }

  // ctx: { player, night, level, maxZombies, hitPlayer(damage, mob) }
  update(dt, ctx) {
    const p = ctx.player.pos;
    if (ctx.night) {
      this.zombieTimer -= dt;
      if (this.zombieTimer <= 0) {
        this.zombieTimer = 3 + Math.random() * 3;
        if (this.count(true) < ctx.maxZombies) this.spawn(ctx.player, 'zombie');
      }
    }
    this.animalTimer -= dt;
    if (this.animalTimer <= 0) {
      this.animalTimer = 2.5;
      if (this.count(false) < 10) {
        const k = Math.random();
        this.spawn(ctx.player, k < 0.4 ? 'pig' : k < 0.75 ? 'cow' : 'chicken');
      }
    }
    for (let i = this.list.length - 1; i >= 0; i--) {
      const m = this.list[i], mp = m.body.pos;
      const dx = p.x - mp.x, dz = p.z - mp.z, dist = Math.hypot(dx, dz);
      if (dist > (m.k.hostile ? 70 : 90)) { this.remove(i); continue; }
      if (m.k.hostile) { if (this.zombie(m, dt, ctx, dx, dz, dist)) { this.kill(i, false); continue; } }
      else this.animal(m, dt, dx, dz, dist);
      // Talk sometimes.
      m.talk -= dt;
      if (m.talk <= 0) {
        m.talk = 6 + Math.random() * 10;
        if (dist < 18) this.sfx[m.k.hostile ? 'groan' : m.k.say]();
      }
      // Move the model.
      m.flash = Math.max(0, m.flash - dt);
      m.swing = Math.max(0, m.swing - dt * 3);
      const g = m.group;
      g.position.set(mp.x, mp.y - m.rise * 1.9, mp.z);
      g.rotation.y = m.body.yaw;
      const leg = Math.sin(m.walk) * 0.6;
      m.legs.forEach((l, k) => (l.rotation.x = (k % 2 === (k >> 1) % 2 ? leg : -leg)));
      m.arms.forEach((a, k) => (a.rotation.x = Math.sin(m.walk * 0.5 + k) * 0.08 - m.swing * 0.9));
      const base = m.k.hostile ? Math.max(0.42, ctx.level) : Math.max(0.3, ctx.level);
      if (m.flash > 0) this.color.setRGB(1, 0.35, 0.35);
      else if (m.burn > 0) this.color.setRGB(1, 0.6, 0.35);
      else this.color.setRGB(base, base, base);
      m.mat.color.copy(this.color);
    }
  }

  // Returns true when the zombie has burned up.
  zombie(m, dt, ctx, dx, dz, dist) {
    const mp = m.body.pos;
    if (m.rise > 0) {
      m.rise = Math.max(0, m.rise - dt);
      if (Math.random() < 0.4) this.bits.burst(Math.floor(mp.x), Math.floor(mp.y) - 1, Math.floor(mp.z), B.DIRT, 1);
    }
    if (!ctx.night) {
      m.burn += dt;
      if (Math.random() < 0.5) this.bits.burst(mp.x - 0.5, mp.y + 0.8, mp.z - 0.5, B.LAMP, 2, [[1, 0.5, 0.1], [1, 0.8, 0.2], [0.3, 0.3, 0.3]]);
      if (m.burn > 2.5) return true;
    }
    const yaw = Math.atan2(-dx, -dz);
    m.body.yaw = yaw;
    // Scared of lamps: stop at the edge of the light, back away if inside it.
    const fx = -Math.sin(yaw), fz = -Math.cos(yaw);
    const ax = mp.x + fx * 0.8, az = mp.z + fz * 0.8;
    const here = this.light(mp.x, mp.y + 0.5, mp.z), ahead = Math.max(this.light(ax, mp.y + 0.5, az), this.light(ax, mp.y + 1.5, az));
    let forward = m.k.speed;
    if (here >= SCARED + 30) forward = -0.5;
    else if (ahead >= SCARED || dist < 1.0 || m.rise > 0) forward = 0;
    m.body.update(dt, { forward, right: 0, jump: false, sprint: false });
    m.walk += Math.hypot(m.body.vel.x, m.body.vel.z) * dt * 3;
    m.hitCool -= dt;
    const p = ctx.player.pos;
    if (dist < 1.35 && Math.abs(p.y - mp.y) < 1.6 && m.hitCool <= 0 && m.rise <= 0) {
      m.hitCool = 1.1;
      m.swing = 1;
      ctx.hitPlayer(2, m);
    }
    return false;
  }

  // Animals wander around, and run away when you hit them.
  animal(m, dt, dx, dz) {
    m.think -= dt;
    if (m.flee > 0) {
      m.flee -= dt;
      m.body.yaw = Math.atan2(dx, dz) + Math.sin(m.flee * 3) * 0.4;
      m.go = 0.8;
    } else if (m.think <= 0) {
      m.think = 2 + Math.random() * 4;
      m.go = Math.random() < 0.55 ? m.k.speed : 0;
      m.body.yaw += (Math.random() - 0.5) * 2.5;
    }
    // Do not walk into the sea.
    const mp = m.body.pos;
    const ax = Math.floor(mp.x - Math.sin(m.body.yaw) * 1.5), az = Math.floor(mp.z - Math.cos(m.body.yaw) * 1.5);
    if (ax < 1 || az < 1 || ax >= W - 1 || az >= D - 1 || this.world.ocean[ax + W * az]) { m.body.yaw += Math.PI; m.think = 1; }
    m.body.update(dt, { forward: m.go, right: 0, jump: false, sprint: false });
    m.walk += Math.hypot(m.body.vel.x, m.body.vel.z) * dt * 4;
  }

  light(x, y, z) {
    const w = this.world;
    x = Math.floor(x); y = Math.floor(y); z = Math.floor(z);
    if (!w.inside(x, y, z)) return 0;
    return w.glow[w.idx(x, y, z)];
  }

  // Find a spot to pop up: zombies in the dark, animals on grass in the sun.
  spawn(player, kind) {
    const w = this.world, p = player.pos;
    const hostile = kind === 'zombie';
    const under = p.y < w.top[Math.floor(p.x) + W * Math.floor(p.z)];
    for (let t = 0; t < 12; t++) {
      const a = Math.random() * Math.PI * 2, d = hostile ? 16 + Math.random() * 18 : 22 + Math.random() * 30;
      const x = Math.floor(p.x + Math.cos(a) * d), z = Math.floor(p.z + Math.sin(a) * d);
      if (x < 1 || z < 1 || x >= W - 1 || z >= D - 1 || w.ocean[x + W * z] || !w.isMade(x, z)) continue;
      let y = -1;
      if (hostile && under) {
        // In a cave: find a floor near the player's height.
        for (let yy = Math.floor(p.y) + 5; yy > Math.floor(p.y) - 6 && yy > 1; yy--) {
          if (SOLID[w.get(x, yy - 1, z)] && !SOLID[w.get(x, yy, z)] && !SOLID[w.get(x, yy + 1, z)]) { y = yy; break; }
        }
      } else {
        const top = w.top[x + W * z];
        const ground = w.get(x, top, z);
        if (top > 0 && (hostile ? SOLID[ground] && ground !== B.GLASS : ground === B.GRASS || ground === B.SNOW_GRASS)) y = top + 1;
      }
      if (y < 1 || SOLID[w.get(x, y, z)] || SOLID[w.get(x, y + 1, z)]) continue;
      if (hostile && this.light(x, y, z) > 40) continue;
      this.list.push(new Mob(w, this.scene, kind, x + 0.5, y, z + 0.5));
      return true;
    }
    return false;
  }

  // Did the player's swing hit a creature? Returns { mob, t }.
  hitTest(o, d, maxDist) {
    let best = null;
    for (const m of this.list) {
      if (m.rise > 0.5) continue;
      const p = m.body.pos, hw = m.k.w;
      const box = [p.x - hw, p.y, p.z - hw, p.x + hw, p.y + m.k.h, p.z + hw];
      let t0 = 0, t1 = maxDist, ok = true;
      for (let a = 0; a < 3 && ok; a++) {
        const oa = a === 0 ? o.x : a === 1 ? o.y : o.z, da = a === 0 ? d.x : a === 1 ? d.y : d.z;
        const lo = box[a], hi = box[a + 3];
        if (Math.abs(da) < 1e-9) { if (oa < lo || oa > hi) ok = false; continue; }
        let ta = (lo - oa) / da, tb = (hi - oa) / da;
        if (ta > tb) [ta, tb] = [tb, ta];
        t0 = Math.max(t0, ta);
        t1 = Math.min(t1, tb);
        if (t0 > t1) ok = false;
      }
      if (ok && (!best || t0 < best.t)) best = { mob: m, t: t0 };
    }
    return best;
  }

  // Hit a creature. Returns true if it was defeated.
  damage(m, amount, dir) {
    m.hp -= amount;
    m.flash = 0.25;
    m.body.vel.x += dir.x * 8;
    m.body.vel.z += dir.z * 8;
    m.body.vel.y = 5;
    if (!m.k.hostile) m.flee = 4;
    if (m.hp > 0) { this.sfx[m.k.hostile ? 'zombieHurt' : m.k.say](); return false; }
    this.kill(this.list.indexOf(m), true);
    return true;
  }

  kill(i, byPlayer) {
    const m = this.list[i];
    const p = m.body.pos;
    this.bits.burst(p.x - 0.5, p.y + 0.3, p.z - 0.5, B.GRASS, 24, [[0.9, 0.9, 0.9], [0.7, 0.7, 0.7], [0.5, 0.5, 0.5]]);
    if (byPlayer && m.k.hostile) this.sfx.zombieDie();
    this.remove(i);
  }

  remove(i) {
    const m = this.list[i];
    this.scene.remove(m.group);
    m.mat.dispose();
    this.list.splice(i, 1);
  }

  clear() {
    while (this.list.length) this.remove(this.list.length - 1);
  }
}
