// Money, shopping, businesses, the mine growing back, and saving.
import { ORES, PICKS, BUSINESSES, PACKS, MILESTONES, DOUBLE_MONEY_COST, bizCost, bizIncome, moneyOreValue, money } from './data.js';
import { B, BLOCKS, isOre } from './blocks.js';
import { mineRoll, buildBusiness, PLOTS } from './town.js';
import { rng } from './noise.js';
import * as sfx from './sound.js';

const SAVE_KEY = 'cave-cash-save-v1';
const REGROW = [25, 45];   // seconds before a mine block grows back

export class Game {
  constructor(world, ui) {
    this.world = world;
    this.ui = ui;
    this.r = rng((Date.now() & 0xffffff) + 1);
    this.time = 0;
    this.regrow = [];
    this.bizClock = 0;
    this.bizBank = [0, 0, 0];
    this.s = Game.fresh();
  }

  static fresh() {
    return { money: 0, earned: 0, ores: 1, pick: 0, biz: [0, 0, 0], x2: false, inv: {}, milestone: 0 };
  }

  get mult() { return this.s.x2 ? 2 : 1; }

  income() {
    return BUSINESSES.reduce((sum, b, i) => sum + bizIncome(b, this.s.biz[i]), 0) * this.mult;
  }

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
    if (give) this.s.inv[give] = (this.s.inv[give] || 0) + 1;
    return { give };
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

  buyBiz(k) {
    const b = BUSINESSES[k], lv = this.s.biz[k];
    if (lv >= b.max) return false;
    if (!this.spend(bizCost(b, lv))) return false;
    this.s.biz[k] = lv + 1;
    buildBusiness(this.world, PLOTS[k], lv + 1);
    sfx.levelUp();
    this.ui.toast(lv === 0 ? `You own the ${b.name}! It makes money every second.` : `${b.name} is now level ${lv + 1}!`, 'good');
    this.ui.businessChanged(k);
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

  buyPack(i) {
    const p = PACKS[i];
    if (!this.spend(p.cost)) return false;
    for (const [id, n] of p.give) this.s.inv[id] = (this.s.inv[id] || 0) + n;
    this.ui.toast(`Got ${p.name}! Right-click to build with them.`, 'good');
    this.ui.changed();
    return true;
  }

  // ---------- Every frame ----------
  tick(dt, player) {
    this.time += dt;
    // Businesses make money.
    const inc = this.income();
    if (inc > 0) {
      this.s.money += inc * dt;
      this.s.earned += inc * dt;
      BUSINESSES.forEach((b, k) => (this.bizBank[k] += bizIncome(b, this.s.biz[k]) * this.mult * dt));
      this.bizClock += dt;
      if (this.bizClock > 3) {
        this.bizClock = 0;
        this.bizBank.forEach((v, k) => { if (v >= 1) this.ui.bizPopup(k, v); this.bizBank[k] = 0; });
      }
      while (this.s.milestone < MILESTONES.length && this.s.earned >= MILESTONES[this.s.milestone][0]) {
        this.ui.bigText(MILESTONES[this.s.milestone][1], this.s.milestone >= 4);
        this.s.milestone++;
      }
    }
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
  save(player, settings) {
    const p = player.pos;
    const data = {
      ...this.s,
      pos: [p.x, p.y, p.z, player.yaw, player.pitch],
      edits: this.world.editList(),
      savedAt: Date.now(),
      settings,
    };
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(data)); } catch (e) { /* storage full or blocked */ }
  }

  static loadData() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (e) { return null; }
  }

  static wipe() {
    try { localStorage.removeItem(SAVE_KEY); } catch (e) { /* ignore */ }
  }

  // Put a saved game back. Returns money made while you were away.
  restore(data) {
    const f = Game.fresh();
    for (const k of Object.keys(f)) if (data[k] !== undefined) this.s[k] = data[k];
    this.s.ores = Math.max(1, Math.min(ORES.length, this.s.ores | 0));
    this.s.pick = Math.max(0, Math.min(PICKS.length - 1, this.s.pick | 0));
    this.s.biz = BUSINESSES.map((b, k) => Math.max(0, Math.min(b.max, (data.biz && data.biz[k]) | 0)));
    if (Array.isArray(data.edits)) this.world.applyEdits(data.edits);
    this.world.setUnlocked(this.s.ores);
    this.s.biz.forEach((lv, k) => lv && buildBusiness(this.world, PLOTS[k], lv));
    // Mine blocks that were dug out grow back soon.
    for (const c of this.world.mineCells) if (this.world.data[c] === 0) this.regrow.push({ i: c, at: 3 + this.r() * 25 });
    const away = Math.min(2 * 3600, Math.max(0, (Date.now() - (data.savedAt || Date.now())) / 1000));
    const made = this.income() * away;
    if (made >= 1) { this.s.money += made; this.s.earned += made; }
    return made;
  }
}
