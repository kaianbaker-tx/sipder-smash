// Zombies! They come out at night, walk toward you and hit you.
// They burn when the sun comes up, and they are scared of lamps.
import * as THREE from '../lib/three.min.js';
import { Player } from './player.js';
import { B, SOLID } from './blocks.js';
import { W, D, TOWN, isProtected } from './world.js';

const SCARED = 50;         // lamp light that zombies will not walk into
const TOWN_SIZE = 31;      // zombies never come into town
const HP = 10;

// A box with darker sides, like the blocks.
function shadedBox(w, h, d, color) {
  const g = new THREE.BoxGeometry(w, h, d);
  const shade = [0.8, 0.8, 1, 0.5, 0.65, 0.65];
  const c = new THREE.Color(color), cols = [];
  for (let f = 0; f < 6; f++) for (let v = 0; v < 4; v++) cols.push(c.r * shade[f], c.g * shade[f], c.b * shade[f]);
  g.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
  return g;
}
const GEO = {
  head: shadedBox(0.5, 0.5, 0.5, '#5e9e4a'),
  eye: shadedBox(0.12, 0.08, 0.02, '#101010'),
  shirt: shadedBox(0.5, 0.75, 0.26, '#2aa5ad'),
  arm: shadedBox(0.24, 0.24, 0.72, '#5e9e4a'),
  sleeve: shadedBox(0.26, 0.26, 0.3, '#2aa5ad'),
  leg: shadedBox(0.25, 0.75, 0.25, '#3a43a6'),
};

class Zombie {
  constructor(world, scene, x, y, z) {
    this.body = new Player(world);
    this.body.pos.x = x; this.body.pos.y = y; this.body.pos.z = z;
    this.body.autoJump = true;
    this.hp = HP;
    this.hitCool = 0.8;
    this.flash = 0;
    this.burn = 0;
    this.rise = 1;
    this.walk = 0;
    this.swing = 0;
    this.groan = 2 + Math.random() * 8;
    this.mat = new THREE.MeshBasicMaterial({ vertexColors: true });
    const m = this.mat;
    const g = new THREE.Group();
    const add = (geo, x, y, z, parent = g) => { const mesh = new THREE.Mesh(geo, m); mesh.position.set(x, y, z); parent.add(mesh); return mesh; };
    add(GEO.head, 0, 1.65, 0);
    add(GEO.eye, -0.11, 1.68, -0.255);
    add(GEO.eye, 0.11, 1.68, -0.255);
    add(GEO.shirt, 0, 1.125, 0);
    this.arms = [-0.37, 0.37].map((ax) => {
      const pivot = new THREE.Group();
      pivot.position.set(ax, 1.38, 0);
      g.add(pivot);
      add(GEO.arm, 0, 0, -0.3, pivot);
      add(GEO.sleeve, 0, 0, -0.02, pivot);
      return pivot;
    });
    this.legs = [-0.125, 0.125].map((lx) => {
      const pivot = new THREE.Group();
      pivot.position.set(lx, 0.75, 0);
      g.add(pivot);
      add(GEO.leg, 0, -0.375, 0, pivot);
      return pivot;
    });
    this.group = g;
    scene.add(g);
  }
}

export class Zombies {
  constructor(world, scene, bits, sfx) {
    this.world = world;
    this.scene = scene;
    this.bits = bits;
    this.sfx = sfx;
    this.list = [];
    this.spawnTimer = 3;
    this.color = new THREE.Color();
  }

  get count() { return this.list.length; }

  // ctx: { player, night, level, max, hitPlayer(damage, zombie) }
  update(dt, ctx) {
    const p = ctx.player.pos;
    if (ctx.night) {
      this.spawnTimer -= dt;
      if (this.spawnTimer <= 0) {
        this.spawnTimer = 3 + Math.random() * 3;
        if (this.list.length < ctx.max) this.spawn(ctx.player);
      }
    }
    for (let i = this.list.length - 1; i >= 0; i--) {
      const z = this.list[i], zp = z.body.pos;
      const dx = p.x - zp.x, dz = p.z - zp.z, dist = Math.hypot(dx, dz);
      if (dist > 70) { this.remove(i); continue; }
      // Coming up out of the ground.
      if (z.rise > 0) {
        z.rise = Math.max(0, z.rise - dt);
        if (Math.random() < 0.4) this.bits.burst(Math.floor(zp.x), Math.floor(zp.y) - 1, Math.floor(zp.z), B.DIRT, 1);
      }
      // Burning in the sun.
      if (!ctx.night) {
        z.burn += dt;
        if (Math.random() < 0.5) this.bits.burst(zp.x - 0.5, zp.y + 0.8, zp.z - 0.5, B.LAMP, 2, [[1, 0.5, 0.1], [1, 0.8, 0.2], [0.3, 0.3, 0.3]]);
        if (z.burn > 2.5) { this.kill(i, false); continue; }
      }
      const yaw = Math.atan2(-dx, -dz);
      z.body.yaw = yaw;
      // Scared of lamps: stop at the edge of the light, back away if inside it.
      const fx = -Math.sin(yaw), fz = -Math.cos(yaw);
      const ax = zp.x + fx * 0.8, az = zp.z + fz * 0.8;
      const here = this.light(zp.x, zp.y + 0.5, zp.z), ahead = Math.max(this.light(ax, zp.y + 0.5, az), this.light(ax, zp.y + 1.5, az));
      let forward = 0.55;
      if (here >= SCARED + 30 || this.inTown(zp.x, zp.z)) forward = -0.5;
      else if (ahead >= SCARED || this.inTown(ax, az) || dist < 1.0 || z.rise > 0) forward = 0;
      z.body.update(dt, { forward, right: 0, jump: false, sprint: false });
      z.walk += Math.hypot(z.body.vel.x, z.body.vel.z) * dt * 3;
      // Hit the player.
      z.hitCool -= dt;
      if (dist < 1.35 && Math.abs(p.y - zp.y) < 1.6 && z.hitCool <= 0 && z.rise <= 0) {
        z.hitCool = 1.1;
        z.swing = 1;
        ctx.hitPlayer(2, z);
      }
      // Groan sometimes.
      z.groan -= dt;
      if (z.groan <= 0) { z.groan = 5 + Math.random() * 8; if (dist < 22) this.sfx.groan(); }
      // Move the model.
      z.flash = Math.max(0, z.flash - dt);
      z.swing = Math.max(0, z.swing - dt * 3);
      const g = z.group;
      g.position.set(zp.x, zp.y - z.rise * 1.9, zp.z);
      g.rotation.y = yaw;
      const leg = Math.sin(z.walk) * 0.6;
      z.legs[0].rotation.x = leg;
      z.legs[1].rotation.x = -leg;
      z.arms.forEach((a, k) => (a.rotation.x = Math.sin(z.walk * 0.5 + k) * 0.08 - z.swing * 0.9));
      const base = Math.max(0.42, ctx.level);
      if (z.flash > 0) this.color.setRGB(1, 0.35, 0.35);
      else if (z.burn > 0) this.color.setRGB(1, 0.6, 0.35);
      else this.color.setRGB(base, base, base);
      z.mat.color.copy(this.color);
    }
  }

  inTown(x, z) {
    return Math.max(Math.abs(x - TOWN.x), Math.abs(z - TOWN.z)) <= TOWN_SIZE;
  }

  light(x, y, z) {
    const w = this.world;
    x = Math.floor(x); y = Math.floor(y); z = Math.floor(z);
    if (!w.inside(x, y, z)) return 0;
    return w.glow[w.idx(x, y, z)];
  }

  // Find a dark spot 16-34 blocks away to pop up from.
  spawn(player) {
    const w = this.world, p = player.pos;
    const under = p.y < w.top[Math.floor(p.x) + W * Math.floor(p.z)];
    for (let t = 0; t < 12; t++) {
      const a = Math.random() * Math.PI * 2, d = 16 + Math.random() * 18;
      const x = Math.floor(p.x + Math.cos(a) * d), z = Math.floor(p.z + Math.sin(a) * d);
      if (x < 1 || z < 1 || x >= W - 1 || z >= D - 1 || w.ocean[x + W * z] || this.inTown(x, z)) continue;
      let y = -1;
      if (under) {
        // In a cave: find a floor near the player's height.
        for (let yy = Math.floor(p.y) + 5; yy > Math.floor(p.y) - 6 && yy > 1; yy--) {
          if (SOLID[w.get(x, yy - 1, z)] && !w.get(x, yy, z) && !w.get(x, yy + 1, z)) { y = yy; break; }
        }
      } else {
        const top = w.top[x + W * z];
        const ground = w.get(x, top, z);
        if (top > 0 && SOLID[ground] && ground !== B.LEAVES && ground !== B.GLASS) y = top + 1;
      }
      if (y < 1 || w.get(x, y, z) || w.get(x, y + 1, z)) continue;
      if (isProtected(w.regionAt(x, y, z)) || isProtected(w.regionAt(x, y - 1, z))) continue;
      if (this.light(x, y, z) > 40) continue;
      this.list.push(new Zombie(w, this.scene, x + 0.5, y, z + 0.5));
      return true;
    }
    return false;
  }

  // Did the player's swing hit a zombie? Returns { zombie, t }.
  hitTest(o, d, maxDist) {
    let best = null;
    for (const z of this.list) {
      if (z.rise > 0.5) continue;
      const p = z.body.pos;
      const box = [p.x - 0.35, p.y, p.z - 0.35, p.x + 0.35, p.y + 1.95, p.z + 0.35];
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
      if (ok && (!best || t0 < best.t)) best = { zombie: z, t: t0 };
    }
    return best;
  }

  // Hit a zombie. Returns true if it was defeated.
  damage(z, amount, dir) {
    z.hp -= amount;
    z.flash = 0.25;
    z.body.vel.x += dir.x * 8;
    z.body.vel.z += dir.z * 8;
    z.body.vel.y = 5;
    if (z.hp > 0) { this.sfx.zombieHurt(); return false; }
    this.kill(this.list.indexOf(z), true);
    return true;
  }

  kill(i, byPlayer) {
    const z = this.list[i];
    const p = z.body.pos;
    this.bits.burst(p.x - 0.5, p.y + 0.5, p.z - 0.5, B.GRASS, 24, [[0.37, 0.62, 0.29], [0.16, 0.65, 0.68], [0.23, 0.26, 0.65]]);
    if (byPlayer) this.sfx.zombieDie();
    this.remove(i);
  }

  remove(i) {
    const z = this.list[i];
    this.scene.remove(z.group);
    z.mat.dispose();
    this.list.splice(i, 1);
  }

  clear() {
    while (this.list.length) this.remove(this.list.length - 1);
  }
}
