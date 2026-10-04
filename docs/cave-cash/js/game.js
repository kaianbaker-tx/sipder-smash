// Money, shopping, hunger, the mine growing back, and saving.
import { ORES, PICKS, PACKS, FOODS, BOOMS, HUNGER, MILESTONES, DOUBLE_MONEY_COST, moneyOreValue, money } from './data.js';
import { B, BLOCKS, isOre } from './blocks.js';
import { isProtected, R } from './world.js';
import { CYCLE, isNight } from './daynight.js';
import { mineRoll } from './town.js';
import { rng } from './noise.js';
import * as sfx from './sound.js';

const OLD_KEY = 'cave-cash-save-v1';
const SETTINGS_KEY = 'cave-cash-settings';
const slotKey = (n) => 'cave-cash-save-' + n;
const REGROW = [25, 45];   // seconds before a mine block grows back

export class Game {
  constructor(world, ui) {
    this.world = world;
    this.ui = ui;
    this.r = rng((Date.now() & 0xffffff) + 1);
    this.time = 0;
    this.regrow = [];
    this.hungerClock = 0;
    this.starveClock = 0;
    this.healClock = 0;
    this.s = Game.fresh();
  }

  static fresh() {
    return {
      money: 0, earned: 0, ores: 1, pick: 0, x2: false, milestone: 0, played: 0,
      inv: { [B.APPLE]: 3 }, hunger: HUNGER.max, health: 10,
      clock: 0.05 * CYCLE, nights: 0, kills: 0,
    };
  }

  get mult() { return this.s.x2 ? 2 : 1; }

  get dayTime() { return this.s.clock / CYCLE; }   // 0..1
  get night() { return isNight(this.dayTime); }

  earn(n) {
    n *= this.mult;
    this.s.money += n;
    this.s.earned += n;
    while (this.s.milestone < MILESTONES.length && this.s.earned >= MILESTONES[this.s.milestone][0]) {
      this.ui.bigText(MILESTONES[this.s.milestone][1], this.s.milestone >= 4);
      sfx.levelUp();
      this.s.milestone++;
    }
    return n;
  }

  spend(n) {
    if (this.s.money < n) {
      sfx.nope();
      this.ui.toast(`You need ${money(n - this.s.money)} more!`, 'bad');
      return false;
    }
    this.s.money -= n;
    sfx.buy();
    return true;
  }

  // ---------- Mining ----------
  // What happens when you break a block. Returns {cash, give} so the game can show it.
  mined(id, x, y, z) {
    const w = this.world;
    const region = w.regionAt(x, y, z);
    w.set(x, y, z, 0);
    if (region === 1) this.regrow.push({ i: w.idx(x, y, z), at: this.time + REGROW[0] + this.r() * (REGROW[1] - REGROW[0]) });
    if (id === B.MONEY_ORE) {
      return { cash: this.earn(moneyOreValue(this.s.ores)), jackpot: true };
    }
    if (isOre(id)) {
      const o = ORES[BLOCKS[id].ore];
      if (o.index < this.s.ores) return { cash: this.earn(o.value) };
      id = B.STONE;  // locked ore: just stone for now
    }
    const give = BLOCKS[id].drop;
    if (give) this.give(give, 1);
    // Like in Minecraft, leaves sometimes drop an apple.
    if (id === B.LEAVES && this.r() < 0.15) { this.give(B.APPLE, 1); return { give, apple: true }; }
    return { give };
  }

  give(id, n) { this.s.inv[id] = (this.s.inv[id] || 0) + n; }

  take(id) {
    if (!this.s.inv[id]) return false;
    if (--this.s.inv[id] <= 0) delete this.s.inv[id];
    return true;
  }

  // ---------- Hunger and health ----------
  // Called every frame while you play. Returns 'starved' if you just died.
  body(dt, busy) {
    const s = this.s;
    this.hungerClock += dt * (busy ? 1.5 : 1);
    if (this.hungerClock >= HUNGER.drain) {
      this.hungerClock = 0;
      if (s.hunger > 0) {
        s.hunger--;
        if (s.hunger === 3) this.ui.toast('You are hungry! Eat food: pick it in your hotbar and right-click (or press F).', 'bad');
        if (s.hunger === 0) this.ui.toast('STARVING! Eat now or you will die!', 'bad');
      }
    }
    if (s.hunger === 0) {
      this.starveClock += dt;
      if (this.starveClock >= HUNGER.starve) { this.starveClock = 0; if (this.hurt(1)) return 'starved'; }
    } else if (s.hunger >= 7 && s.health < 10) {
      this.healClock += dt;
      if (this.healClock >= HUNGER.heal) { this.healClock = 0; s.health++; }
    }
    return null;
  }

  // Lose hearts. Returns true if that killed you.
  hurt(n) {
    this.s.health = Math.max(0, this.s.health - n);
    sfx.hurt();
    this.ui.hurtFlash();
    return this.s.health <= 0;
  }

  // You died: lose 10% of your money, come back full of health.
  die() {
    const lost = Math.floor(this.s.money * 0.1);
    this.s.money -= lost;
    this.s.health = 10;
    this.s.hunger = Math.max(this.s.hunger, 6);
    this.starveClock = this.hungerClock = 0;
    return lost;
  }

  // Eat a food. With no id, eat the smallest food you have.
  eat(id) {
    const s = this.s;
    if (!id) id = [B.APPLE, B.LEMONADE, B.PIZZA_FOOD].find((f) => s.inv[f]);
    if (!id) { this.ui.toast('No food! Buy some in the SHOP. Leaves drop apples too.', 'bad'); sfx.nope(); return false; }
    if (s.hunger >= HUNGER.max) { this.ui.toast('You are full!'); return false; }
    this.take(id);
    s.hunger = Math.min(HUNGER.max, s.hunger + BLOCKS[id].food);
    sfx.eat();
    this.ui.changed();
    return true;
  }

  mineHardness(id) {
    const vis = this.world.visual[id];
    return BLOCKS[vis === B.STONE && isOre(id) ? B.STONE : id].hard;
  }

  pickSpeed() { return PICKS[this.s.pick].speed; }

  // ---------- Shop ----------
  buyOre() {
    const i = this.s.ores;
    if (i >= ORES.length) return false;
    if (!this.spend(ORES[i].cost)) return false;
    this.s.ores++;
    this.world.setUnlocked(this.s.ores);
    // New ore pops into the walls of THE MINE.
    const w = this.world, o = ORES[i];
    let n = 0;
    for (const c of w.mineCells) {
      if (w.data[c] === B.STONE && this.r() < 0.2) {
        const x = c % 128, z = ((c / 128) | 0) % 128, y = (c / (128 * 128)) | 0;
        w.set(x, y, z, o.id);
        n++;
      }
    }
    this.ui.toast(`NEW! ${o.name} Ore is in THE MINE and in the caves!`, 'good');
    this.ui.toast(`Each ${o.name} block = ${money(o.value * this.mult)}`, 'good');
    this.ui.changed();
    return n;
  }

  buyPick() {
    const i = this.s.pick + 1;
    if (i >= PICKS.length) return false;
    if (!this.spend(PICKS[i].cost)) return false;
    this.s.pick = i;
    this.ui.toast(`You got the ${PICKS[i].name}! Mining is faster!`, 'good');
    this.ui.changed();
    return true;
  }

  buyDouble() {
    if (this.s.x2) return false;
    if (!this.spend(DOUBLE_MONEY_COST)) return false;
    this.s.x2 = true;
    sfx.levelUp();
    this.ui.bigText('2X MONEY!', true);
    this.ui.changed();
    return true;
  }

  buyFood(i) {
    const f = FOODS[i];
    if (!this.spend(f.cost)) return false;
    this.give(f.id, f.count);
    this.ui.toast(`Got ${f.count} ${f.name}! Pick it in your hotbar and right-click to eat.`, 'good');
    this.ui.changed();
    return true;
  }

  buyBoom(i) {
    const p = BOOMS[i];
    if (!this.spend(p.cost)) return false;
    for (const [id, n] of p.give) this.give(id, n);
    this.ui.toast(`Got ${p.name}! Place it, hit it to light it, then RUN!`, 'good');
    this.ui.changed();
    return true;
  }

  // Blow up blocks around x,y,z. Ore turns into money. Returns money made and TNT that should go off next.
  explode(cx, cy, cz, radius) {
    const w = this.world, r = this.r;
    const n = Math.ceil(radius);
    let cash = 0, jackpot = false;
    const chain = [];
    for (let dy = -n; dy <= n; dy++) for (let dz = -n; dz <= n; dz++) for (let dx = -n; dx <= n; dx++) {
      const d = Math.sqrt(dx * dx + dy * dy + dz * dz);
      if (d > radius + (r() - 0.5) * 0.9) continue;
      const x = cx + dx, y = cy + dy, z = cz + dz;
      if (!w.inside(x, y, z)) continue;
      const id = w.data[w.idx(x, y, z)];
      if (!id || id === B.BEDROCK) continue;
      const region = w.regionAt(x, y, z);
      if (isProtected(region)) continue;
      if ((id === B.TNT || id === B.MEGA_TNT) && (dx || dy || dz)) { chain.push({ x, y, z, id }); continue; }
      w.set(x, y, z, 0);
      if (region === R.MINE) this.regrow.push({ i: w.idx(x, y, z), at: this.time + REGROW[0] + r() * (REGROW[1] - REGROW[0]) });
      if (id === B.MONEY_ORE) { cash += moneyOreValue(this.s.ores); jackpot = true; }
      else if (isOre(id) && BLOCKS[id].ore < this.s.ores) cash += ORES[BLOCKS[id].ore].value;
      else if (r() < 0.25 && BLOCKS[id].drop && !isOre(id)) this.give(BLOCKS[id].drop, 1);
    }
    return { cash: cash ? this.earn(cash) : 0, jackpot, chain };
  }

  buyPack(i) {
    const p = PACKS[i];
    if (!this.spend(p.cost)) return false;
    for (const [id, n] of p.give) this.give(id, n);
    this.ui.toast(p.icon === B.HOUSE_KIT ? 'Got a House Kit! Pick it, aim at the ground and right-click!' : `Got ${p.name}! Right-click to build with them.`, 'good');
    this.ui.changed();
    return true;
  }

  // ---------- Every frame ----------
  tick(dt, player) {
    this.time += dt;
    this.s.played += dt;
    this.s.clock = (this.s.clock + dt) % CYCLE;
    // The mine grows back.
    const w = this.world;
    for (let k = this.regrow.length - 1; k >= 0; k--) {
      const g = this.regrow[k];
      if (g.at > this.time) continue;
      this.regrow.splice(k, 1);
      if (w.data[g.i] !== 0) continue;
      const x = g.i % 128, z = ((g.i / 128) | 0) % 128, y = (g.i / (128 * 128)) | 0;
      if (player.overlapsBlock(x, y, z)) { g.at = this.time + 4; this.regrow.push(g); continue; }
      w.set(x, y, z, mineRoll(this.r, this.s.ores, y));
    }
  }

  // ---------- Saving ----------
  // There are 3 save files. Each one keeps its own world.
  save(player, slot) {
    const p = player.pos;
    const data = {
      ...this.s,
      pos: [p.x, p.y, p.z, player.yaw, player.pitch],
      edits: this.world.editList(),
      savedAt: Date.now(),
    };
    try {
      localStorage.setItem(slotKey(slot), JSON.stringify(data));
      return true;
    } catch (e) { return false; }
  }

  static loadData(slot) {
    try {
      // Games saved before there were save files go into SAVE 1.
      if (slot === 1 && !localStorage.getItem(slotKey(1)) && localStorage.getItem(OLD_KEY)) {
        localStorage.setItem(slotKey(1), localStorage.getItem(OLD_KEY));
        localStorage.removeItem(OLD_KEY);
      }
      const raw = localStorage.getItem(slotKey(slot));
      return raw ? JSON.parse(raw) : null;
    } catch (e) { return null; }
  }

  static wipe(slot) {
    try { localStorage.removeItem(slotKey(slot)); } catch (e) { /* ignore */ }
  }

  static loadSettings() {
    try { return JSON.parse(localStorage.getItem(SETTINGS_KEY)); } catch (e) { return null; }
  }

  static saveSettings(s) {
    try { localStorage.setItem(SETTINGS_KEY, JSON.stringify(s)); } catch (e) { /* ignore */ }
  }

  // Put a saved game back.
  restore(data) {
    const f = Game.fresh();
    for (const k of Object.keys(f)) if (data[k] !== undefined) this.s[k] = data[k];
    this.s.ores = Math.max(1, Math.min(ORES.length, this.s.ores | 0));
    this.s.pick = Math.max(0, Math.min(PICKS.length - 1, this.s.pick | 0));
    this.s.health = Math.max(1, Math.min(10, this.s.health | 0));
    this.s.hunger = Math.max(0, Math.min(HUNGER.max, this.s.hunger | 0));
    this.s.clock = (+this.s.clock || 0) % CYCLE;
    if (Array.isArray(data.edits)) this.world.applyEdits(data.edits);
    this.world.setUnlocked(this.s.ores);
    // Mine blocks that were dug out grow back soon.
    for (const c of this.world.mineCells) if (this.world.data[c] === 0) this.regrow.push({ i: c, at: this.time + 3 + this.r() * 25 });
  }
}
