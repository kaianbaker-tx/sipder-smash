// Everything on the screen: money, hotbar, messages and the shop.
import { ORES, PICKS, BUSINESSES, PACKS, FOODS, BOOMS, DOUBLE_MONEY_COST, bizCost, bizIncome, moneyOreValue, money } from './data.js';
import { B, BLOCKS, PLACEABLE } from './blocks.js';
import { blockIcon } from './atlas.js';
import * as sfx from './sound.js';

const $ = (id) => document.getElementById(id);

// Tiny pixel pictures for hearts and hunger, like Minecraft.
const HEART = ['.KK...KK.', 'KRRK.KRRK', 'KRWRKRRRK', 'KRRRRRRRK', 'KRRRRRRRK', '.KRRRRRK.', '..KRRRK..', '...KRK...', '....K....'];
const SHANK = ['.....KK..', '....KBBK.', '...KBBBBK', '..KBBBBBK', '.KBBBBBK.', 'KWKBBBK..', 'KWWKKK...', '.KWK.....', '..K......'];
function pixelIcon(rows, colors) {
  const c = document.createElement('canvas');
  c.width = c.height = 9;
  const g = c.getContext('2d');
  rows.forEach((row, y) => [...row].forEach((ch, x) => {
    if (!colors[ch]) return;
    g.fillStyle = colors[ch];
    g.fillRect(x, y, 1, 1);
  }));
  return c.toDataURL();
}
const ICON = {
  heart: pixelIcon(HEART, { K: '#1a0a0a', R: '#e8212b', W: '#ffd0d0' }),
  heartOff: pixelIcon(HEART, { K: '#1a0a0a', R: '#3b2a2a', W: '#3b2a2a' }),
  food: pixelIcon(SHANK, { K: '#2a1406', B: '#c8743a', W: '#f2ead8' }),
  foodOff: pixelIcon(SHANK, { K: '#2a1406', B: '#3b2f28', W: '#5a524a' }),
};

export class UI {
  constructor() {
    this.game = null;
    this.sel = 0;               // which hotbar block is picked
    this.tab = 'ores';
    this.shopOpen = false;
    this.hooks = {};            // set by main.js: onBizChanged, onBizPopup
    this.lastMoney = -1;
    this.lastIncome = -1;
    this.hotKey = '';
    this.shopKey = '';
    this.barKey = '';
    this.heldId = -1;
    $('shop-close').onclick = () => this.hooks.closeShop();
    document.querySelectorAll('.tab').forEach((t) => (t.onclick = () => { sfx.click(); this.showTab(t.dataset.tab); }));
    $('shop-list').addEventListener('click', (e) => this.shopClick(e));
    $('x2-btn').onclick = (e) => { if (!this.game.buyDouble()) this.shake(e.currentTarget); };
  }

  bind(game) { this.game = game; }

  // ---------- Called by the game ----------
  toast(msg, kind = '') {
    const box = $('toasts');
    const t = document.createElement('div');
    t.className = 'toast ' + kind;
    t.textContent = msg;
    box.appendChild(t);
    while (box.children.length > 4) box.firstChild.remove();
    setTimeout(() => t.classList.add('out'), 2800);
    setTimeout(() => t.remove(), 3300);
  }

  bigText(text) {
    const b = $('big-text');
    b.textContent = text;
    b.classList.remove('show');
    void b.offsetWidth;
    b.classList.add('show');
  }

  changed() {
    this.hotKey = '';
    this.shopKey = '';
    if (this.shopOpen) this.renderShop();
  }

  hurtFlash() {
    const f = $('hurt-flash');
    f.classList.add('on');
    clearTimeout(this.hurtT);
    this.hurtT = setTimeout(() => f.classList.remove('on'), 60);
  }

  businessChanged(k) { if (this.hooks.onBizChanged) this.hooks.onBizChanged(k); }
  bizPopup(k, v) { if (this.hooks.onBizPopup) this.hooks.onBizPopup(k, v); }

  // ---------- HUD ----------
  update() {
    const g = this.game, s = g.s;
    const m = Math.floor(s.money);
    if (m !== this.lastMoney) {
      const el = $('money');
      el.textContent = money(m);
      if (m > this.lastMoney && this.lastMoney >= 0) {
        el.classList.add('bump');
        clearTimeout(this.bumpT);
        this.bumpT = setTimeout(() => el.classList.remove('bump'), 110);
      }
      this.lastMoney = m;
      if (this.shopOpen) this.refreshPrices();
    }
    const inc = g.income();
    const night = g.night;
    const key = inc + ':' + s.pick + ':' + s.x2 + ':' + night + ':' + s.nights;
    if (key !== this.lastIncome) {
      $('income').textContent = inc > 0 ? `+${money(inc)} every second` : '';
      this.lastIncome = key;
      $('badges').innerHTML = (night ? `<div class="badge night">NIGHT ${s.nights} &middot; ZOMBIES!</div>` : `<div class="badge day">DAY ${s.nights + 1}</div>`) +
        `<div class="badge">${PICKS[s.pick].name}</div>` + (s.x2 ? '<div class="badge x2">2X MONEY</div>' : '');
    }
    this.renderHotbar();
    this.renderBars();
  }

  renderBars() {
    const s = this.game.s;
    const key = s.health + ':' + s.hunger;
    if (key === this.barKey) return;
    this.barKey = key;
    let h = '', f = '';
    for (let i = 0; i < 10; i++) {
      h += `<img alt="" src="${i < s.health ? ICON.heart : ICON.heartOff}">`;
      f += `<img alt="" src="${i < s.hunger ? ICON.food : ICON.foodOff}">`;
    }
    $('hearts').innerHTML = h;
    $('hunger').innerHTML = f;
    $('hearts').classList.toggle('low', s.health <= 3);
    $('hunger').classList.toggle('low', s.hunger <= 3);
  }

  // Show the name of what you are holding for a moment, like Minecraft.
  showHeld(id) {
    if (id === this.heldId) return;
    this.heldId = id;
    const el = $('held-name');
    if (!id) { el.classList.remove('show'); return; }
    const b = BLOCKS[id];
    el.textContent = b.food ? `${b.name} - right-click to eat` : b.boom ? `${b.name} - place it, then hit it to light it!` : id === B.HOUSE_KIT ? 'House Kit - aim at the ground, right-click!' : b.name;
    el.classList.add('show');
    clearTimeout(this.heldT);
    this.heldT = setTimeout(() => el.classList.remove('show'), 2200);
  }

  setLook(hit, world) {
    const el = $('look-label');
    if (!hit) { el.innerHTML = ''; return; }
    const g = this.game;
    const region = world.regionAt(hit.x, hit.y, hit.z);
    const plots = { 10: 0, 11: 1, 12: 2 };
    if (region === 2) { el.innerHTML = 'SHOP &nbsp;<span class="cash">right-click or press B</span>'; return; }
    if (region in plots) {
      const k = plots[region], b = BUSINESSES[k], lv = g.s.biz[k];
      const what = !lv ? 'right-click to buy it' : k === 0 ? 'right-click to buy lemonade' : k === 1 ? 'right-click to buy pizza' : 'right-click to buy explosives';
      el.innerHTML = `${b.name} ${lv ? 'level ' + lv : '- for sale'} &nbsp;<span class="cash">${what}</span>`;
      return;
    }
    const vis = world.visual[hit.id];
    const bd = BLOCKS[vis];
    let extra = '';
    if (hit.id === B.MONEY_ORE) extra = `JACKPOT ${money(moneyOreValue(g.s.ores) * g.mult)}!`;
    else if (bd.ore !== undefined) extra = money(ORES[bd.ore].value * g.mult);
    el.innerHTML = `${bd.name}${extra ? ' &nbsp;<span class="cash">' + extra + '</span>' : ''}`;
  }

  // ---------- Hotbar ----------
  owned() { return PLACEABLE.filter((id) => (this.game.s.inv[id] || 0) > 0); }

  selectedBlock() {
    const own = this.owned();
    if (!own.length) return 0;
    if (this.sel >= own.length) this.sel = own.length - 1;
    return own[this.sel];
  }

  scroll(dir) {
    const n = this.owned().length;
    if (!n) return;
    this.sel = (this.sel + dir + n) % n;
    this.hotKey = '';
  }

  pick(slot) {
    const own = this.owned();
    const start = this.windowStart(own.length);
    if (start + slot < own.length) { this.sel = start + slot; this.hotKey = ''; }
  }

  windowStart(n) { return Math.max(0, Math.min(this.sel - 4, n - 9)); }

  renderHotbar() {
    const own = this.owned(), inv = this.game.s.inv;
    this.selectedBlock();
    const key = own.map((id) => id + ':' + inv[id]).join(',') + '|' + this.sel;
    if (key === this.hotKey) return;
    this.showHeld(this.selectedBlock());
    this.hotKey = key;
    const bar = $('hotbar');
    if (!own.length) {
      bar.innerHTML = '<div class="hotbar-hint">Mine dirt, stone and wood to build with them!</div>';
      this.showHeld(0);
      return;
    }
    const start = this.windowStart(own.length);
    let html = '';
    for (let i = 0; i < 9; i++) {
      const id = own[start + i];
      if (id === undefined) { html += '<div class="slot empty"></div>'; continue; }
      html += `<div class="slot${start + i === this.sel ? ' on' : ''}" data-i="${start + i}"><img alt="" src="${blockIcon(id)}"><span class="n">${inv[id]}</span></div>`;
    }
    bar.innerHTML = html;
    bar.querySelectorAll('.slot[data-i]').forEach((el) => {
      el.onpointerdown = (e) => { e.stopPropagation(); this.sel = +el.dataset.i; this.hotKey = ''; };
    });
  }

  // ---------- Shop ----------
  openShop(tab) {
    this.shopOpen = true;
    $('shop').classList.remove('hidden');
    this.showTab(tab || this.tab);
  }

  closeShop() {
    this.shopOpen = false;
    $('shop').classList.add('hidden');
  }

  showTab(tab) {
    this.tab = tab;
    document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('on', t.dataset.tab === tab));
    this.shopKey = '';
    this.renderShop();
    $('shop-list').scrollTop = 0;
  }

  renderShop() {
    const g = this.game, s = g.s;
    const key = this.tab + JSON.stringify([s.ores, s.pick, s.biz, s.x2]);
    if (key !== this.shopKey) {
      this.shopKey = key;
      $('shop-list').innerHTML = this['tab_' + this.tab]();
    }
    const x2 = $('x2-btn');
    x2.classList.toggle('owned', s.x2);
    x2.dataset.cost = s.x2 ? '' : DOUBLE_MONEY_COST;
    x2.innerHTML = s.x2 ? '2X MONEY is ON! Everything pays double!' : `2X MONEY — all money counts double! &nbsp; ${money(DOUBLE_MONEY_COST)}`;
    this.refreshPrices();
  }

  refreshPrices() {
    const m = this.game.s.money;
    $('shop-money').textContent = money(m);
    document.querySelectorAll('#shop-list .btn[data-cost]').forEach((b) => b.classList.toggle('cant', m < +b.dataset.cost));
  }

  tab_ores() {
    const s = this.game.s, mult = this.game.mult;
    let html = '';
    ORES.forEach((o, i) => {
      const owned = i < s.ores, next = i === s.ores;
      const right = owned ? '<div class="done">OWNED</div>'
        : next ? `<button class="btn green" data-buy="ore" data-cost="${o.cost}">BUY ${money(o.cost)}</button>`
          : `<div class="done" style="color:#b9a4ff">${money(o.cost)}</div>`;
      html += `<div class="card${!owned && !next ? ' locked' : ''}"><img alt="" src="${blockIcon(o.id)}"><div class="info">
        <div class="name">${o.name}</div>
        <div class="sub">Each block = <span class="cash">${money(o.value * mult)}</span>${owned ? '' : next ? ' — buy it and it shows up in THE MINE and the caves!' : ' — buy the one above first'}</div>
      </div>${right}</div>`;
    });
    html += `<div class="card"><img alt="" src="${blockIcon(B.MONEY_ORE)}"><div class="info">
      <div class="name">Money Ore <span class="tagline">JACKPOT</span></div>
      <div class="sub">Where diamonds would be! Deep in the caves. Each = <span class="cash">${money(moneyOreValue(s.ores) * mult)}</span></div>
    </div><div class="done">FREE</div></div>`;
    return html;
  }

  tab_picks() {
    const s = this.game.s;
    return PICKS.map((p, i) => {
      const right = i === s.pick ? '<div class="done">USING</div>'
        : i < s.pick ? '<div class="done" style="opacity:.6">OLD</div>'
          : i === s.pick + 1 ? `<button class="btn green" data-buy="pick" data-cost="${p.cost}">BUY ${money(p.cost)}</button>`
            : `<div class="done" style="color:#b9a4ff">${money(p.cost)}</div>`;
      return `<div class="card${i > s.pick + 1 ? ' locked' : ''}"><div class="ico" style="background:${p.color}">⛏</div><div class="info">
        <div class="name">${p.name}</div><div class="sub">Mines ${p.speed}x as fast as wood</div>
      </div>${right}</div>`;
    }).join('');
  }

  tab_biz() {
    const s = this.game.s, mult = this.game.mult;
    const order = [2, 0, 1];
    return order.map((k) => {
      const b = BUSINESSES[k], lv = s.biz[k];
      const icon = k === 0 ? B.LEMON : k === 1 ? B.PIZZA : B.MONEY_BLOCK;
      const now = bizIncome(b, lv) * mult, nxt = bizIncome(b, lv + 1) * mult;
      const right = lv >= b.max ? '<div class="done">MAX!</div>'
        : `<button class="btn green" data-buy="biz" data-k="${k}" data-cost="${bizCost(b, lv)}">${lv ? 'UPGRADE' : 'BUY'} ${money(bizCost(b, lv))}</button>`;
      return `<div class="card${k === 2 ? ' main' : ''}"><img alt="" src="${blockIcon(icon)}"><div class="info">
        <div class="name">${b.name}<span class="tagline">${b.size}</span></div>
        <div class="sub">${lv ? `Level ${lv} — makes <span class="cash">${money(now)}</span> every second` : 'Not yours yet'}${lv < b.max ? ` → <span class="cash">${money(nxt)}</span>/sec` : ''}</div>
        <div class="bar"><i style="width:${(lv / b.max) * 100}%"></i></div>
      </div>${right}</div>`;
    }).join('');
  }

  tab_food() {
    const s = this.game.s;
    const have = (id) => s.inv[id] || 0;
    return `<div class="card"><img alt="" src="${blockIcon(B.LEAVES)}"><div class="info">
        <div class="name">Free apples!</div><div class="sub">Break tree leaves. Sometimes an apple falls out.</div></div></div>` +
      FOODS.map((f, i) => {
        const locked = f.need !== undefined && !s.biz[f.need];
        const right = locked ? `<div class="done" style="color:#b9a4ff">LOCKED</div>`
          : `<button class="btn green" data-buy="food" data-i="${i}" data-cost="${f.cost}">BUY ${money(f.cost)}</button>`;
        return `<div class="card${locked ? ' locked' : ''}"><img alt="" src="${blockIcon(f.id)}"><div class="info">
          <div class="name">${f.count} ${f.name}</div>
          <div class="sub">Each one fills ${BLOCKS[f.id].food} hunger. You have ${have(f.id)}.${locked ? ` Buy the ${BUSINESSES[f.need].name} to sell it!` : ''}</div>
        </div>${right}</div>`;
      }).join('');
  }

  tab_boom() {
    const s = this.game.s, owned = s.biz[2] > 0;
    let html = owned ? '' : `<div class="card main"><img alt="" src="${blockIcon(B.MONEY_BLOCK)}"><div class="info">
      <div class="name">Buy the Money Factory first!</div><div class="sub">Your factory makes the explosives. Find it in BUSINESSES.</div></div></div>`;
    html += BOOMS.map((p, i) => `<div class="card${owned ? '' : ' locked'}"><img alt="" src="${blockIcon(p.icon)}"><div class="info">
        <div class="name">${p.name}</div><div class="sub">${p.about} Ore it blows up turns into money!</div>
      </div>${owned ? `<button class="btn green" data-buy="boom" data-i="${i}" data-cost="${p.cost}">BUY ${money(p.cost)}</button>` : '<div class="done" style="color:#b9a4ff">LOCKED</div>'}</div>`).join('');
    html += `<div class="card"><div class="ico" style="background:#ff3b5c">!</div><div class="info">
      <div class="name">How to blow stuff up</div><div class="sub">Pick the TNT in your hotbar. Right-click to place it. Hit it to light it. RUN! Too close and you lose hearts.</div></div></div>`;
    return html;
  }

  tab_blocks() {
    return PACKS.map((p, i) => {
      const count = p.give.reduce((a, g) => a + g[1], 0);
      return `<div class="card"><img alt="" src="${blockIcon(p.icon)}"><div class="info">
        <div class="name">${p.name}</div><div class="sub">${p.about || count + ' blocks for building'}</div>
      </div><button class="btn green" data-buy="pack" data-i="${i}" data-cost="${p.cost}">BUY ${money(p.cost)}</button></div>`;
    }).join('');
  }

  shopClick(e) {
    const b = e.target.closest('[data-buy]');
    if (!b) return;
    const g = this.game;
    let ok = false;
    if (b.dataset.buy === 'ore') ok = g.buyOre();
    else if (b.dataset.buy === 'pick') ok = g.buyPick();
    else if (b.dataset.buy === 'biz') ok = g.buyBiz(+b.dataset.k);
    else if (b.dataset.buy === 'pack') ok = g.buyPack(+b.dataset.i);
    else if (b.dataset.buy === 'food') ok = g.buyFood(+b.dataset.i);
    else if (b.dataset.buy === 'boom') ok = g.buyBoom(+b.dataset.i);
    if (!ok) this.shake(b);
  }

  shake(el) {
    el.classList.remove('shake');
    void el.offsetWidth;
    el.classList.add('shake');
  }
}
