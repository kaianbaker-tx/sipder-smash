// The player: walking, jumping, swimming and bumping into blocks.
import { SOLID } from './blocks.js';
import { W, D, SEA } from './world.js';

const HW = 0.3;       // half width
const HEIGHT = 1.8;
export const EYE = 1.62;

export class Player {
  constructor(world) {
    this.world = world;
    this.pos = { x: 0, y: 0, z: 0 };
    this.vel = { x: 0, y: 0, z: 0 };
    this.yaw = 0;
    this.pitch = 0;
    this.onGround = false;
    this.inWater = false;
    this.autoJump = true;
    this.walked = 0;     // for head bob and footsteps
  }

  solid(x, y, z) {
    return SOLID[this.world.get(x, y, z)] === 1;
  }

  // Does the player's box overlap any block at this spot?
  hits(px, py, pz) {
    const x0 = Math.floor(px - HW), x1 = Math.floor(px + HW - 1e-4);
    const y0 = Math.floor(py), y1 = Math.floor(py + HEIGHT - 1e-4);
    const z0 = Math.floor(pz - HW), z1 = Math.floor(pz + HW - 1e-4);
    for (let y = y0; y <= y1; y++) for (let z = z0; z <= z1; z++) for (let x = x0; x <= x1; x++)
      if (this.solid(x, y, z)) return true;
    return false;
  }

  // Would a block at x,y,z be inside the player?
  overlapsBlock(x, y, z) {
    const p = this.pos;
    return x + 1 > p.x - HW && x < p.x + HW && z + 1 > p.z - HW && z < p.z + HW && y + 1 > p.y && y < p.y + HEIGHT;
  }

  update(dt, input) {
    const p = this.pos, v = this.vel;
    const ocean = this.world.ocean[Math.floor(p.x) + W * Math.floor(p.z)];
    const wasWater = this.inWater;
    this.inWater = p.y + 0.5 < SEA && ocean !== 0;
    this.splashed = this.inWater && !wasWater;

    // Which way do we want to go?
    const sin = Math.sin(this.yaw), cos = Math.cos(this.yaw);
    let fx = -sin * input.forward + cos * input.right;
    let fz = -cos * input.forward - sin * input.right;
    const len = Math.hypot(fx, fz);
    if (len > 1) { fx /= len; fz /= len; }
    const speed = this.inWater ? 2.6 : input.sprint ? 6.4 : 4.5;
    const accel = this.onGround || this.inWater ? 40 : 12;
    const k = Math.min(1, accel * dt);
    v.x += (fx * speed - v.x) * k;
    v.z += (fz * speed - v.z) * k;

    if (this.inWater) {
      v.y -= 9 * dt;
      if (input.jump) v.y += 22 * dt;
      v.y = Math.max(-3, Math.min(3.6, v.y));
    } else {
      v.y -= 27 * dt;
      if (v.y < -40) v.y = -40;
      if (input.jump && this.onGround) v.y = 8.6;
    }

    // Move in small steps so we never go through a wall.
    const steps = Math.ceil(Math.max(Math.abs(v.x), Math.abs(v.y), Math.abs(v.z)) * dt / 0.35) || 1;
    const sdt = dt / steps;
    let blockedSide = false;
    this.onGround = false;
    for (let s = 0; s < steps; s++) {
      if (this.moveAxis('x', v.x * sdt)) blockedSide = true;
      if (this.moveAxis('z', v.z * sdt)) blockedSide = true;
      this.moveAxis('y', v.y * sdt);
    }
    // Stay on the island.
    p.x = Math.max(0.4, Math.min(W - 0.4, p.x));
    p.z = Math.max(0.4, Math.min(D - 0.4, p.z));
    if (p.y < -20) { p.y = 70; v.y = 0; }

    // Auto-jump up one block, and climb out of water at the shore.
    if (blockedSide && len > 0.1) {
      const ax = p.x + fx * 0.45, az = p.z + fz * 0.45;
      const stepUp = this.hits(ax, p.y + 0.05, az) && !this.hits(ax, p.y + 1.05, az);
      if (stepUp && this.inWater) v.y = 6.5;
      else if (stepUp && this.onGround && this.autoJump) v.y = 8.6;
    }
    if (this.onGround && len > 0.1) this.walked += Math.hypot(v.x, v.z) * dt;
  }

  moveAxis(axis, amt) {
    if (!amt) return false;
    const p = this.pos;
    const old = p[axis];
    p[axis] += amt;
    if (!this.hits(p.x, p.y, p.z)) return false;
    if (axis === 'y') {
      if (amt < 0) { p.y = Math.floor(p.y) + 1; this.onGround = true; }
      else p.y = Math.floor(p.y + HEIGHT) - HEIGHT - 1e-3;
      this.vel.y = 0;
    } else {
      if (amt > 0) p[axis] = Math.floor(p[axis] + HW) - HW - 1e-3;
      else p[axis] = Math.floor(p[axis] - HW) + 1 + HW + 1e-3;
      this.vel[axis] = 0;
    }
    // Still stuck (e.g. a block grew on us)? Undo the move.
    if (this.hits(p.x, p.y, p.z)) p[axis] = old;
    return true;
  }

  // Get unstuck if a block ends up inside us.
  unstick() {
    const p = this.pos;
    for (let i = 0; i < 64 && this.hits(p.x, p.y, p.z); i++) p.y += 1;
  }
}
