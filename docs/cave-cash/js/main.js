// CAVE CASH: starts everything and runs the game every frame.
import * as THREE from '../lib/three.min.js';
import { buildAtlas } from './atlas.js';
import { B, BLOCKS, SOLID } from './blocks.js';
import { BUSINESSES, PICKS, bizCost, bizIncome, money } from './data.js';
import { World, W, D, SEA, GROUND, isProtected, R } from './world.js';
import { buildTown, buildCave, buildBusiness, SPAWN, MINE, SHOP, CAVE, PLOTS, plotSignPos, chimneys } from './town.js';
import { Player, EYE } from './player.js';
import { Game } from './game.js';
import { UI } from './ui.js';
import { Bits, Popups, Sign, Target, Hand, makeSky, makeClouds, makeWater } from './fx.js';
import { setupTouch } from './touch.js';
import { rng } from './noise.js';
import * as sfx from './sound.js';

const SEED = 20260928;
const REACH = 5.5;
const $ = (id) => document.getElementById(id);

// ---------- Renderer ----------
const canvas = $('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
renderer.autoClear = false;
const scene = new THREE.Scene();
const SKY_FOG = new THREE.Color('#bfe6ff'), WATER_FOG = new THREE.Color('#1d4f9a');
scene.fog = new THREE.Fog(SKY_FOG.clone(), 40, 120);
const camera = new THREE.PerspectiveCamera(75, 1, 0.05, 500);
camera.rotation.order = 'YXZ';

function resize() {
  const w = window.innerWidth, h = window.innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
resize();

// ---------- Build the world ----------
await document.fonts.load('40px "Luckiest Guy"').catch(() => {});
const atlasCanvas = buildAtlas();
const atlasTex = new THREE.CanvasTexture(atlasCanvas);
atlasTex.magFilter = THREE.NearestFilter;
atlasTex.minFilter = THREE.NearestFilter;
atlasTex.generateMipmaps = false;
atlasTex.colorSpace = THREE.SRGBColorSpace;
const blockMat = new THREE.MeshBasicMaterial({ map: atlasTex, vertexColors: true, alphaTest: 0.5 });

const world = new World(SEED);
world.generate();
buildTown(world, rng(SEED + 5));
buildCave(world, rng(SEED + 9));
world.finish();
world.setUnlocked(1);
scene.add(world.group);

const ui = new UI();
const game = new Game(world, ui);
ui.bind(game);
const player = new Player(world);

const sky = makeSky(scene);
const clouds = makeClouds(scene);
makeWater(scene, SEA, world, W, D);
const bits = new Bits(scene);
const popups = new Popups(scene);
const target = new Target(scene, atlasTex);
const hand = new Hand();

// Signs.
new Sign(scene, (MINE.x0 + MINE.x1) / 2, GROUND + 7, MINE.z0 + 1, ['THE MINE', 'Ore grows back!'], { height: 1.8 });
new Sign(scene, CAVE.x - 1, GROUND + 4.5, (CAVE.z0 + CAVE.z1 + 1) / 2, ['MONEY CAVE', 'Dig for Money Ore!'], { height: 1.6, bg: '#27c95a', stroke: '#27c95a', color: '#fff6d6', color2: '#fff6d6', border: '#1b0d2e' });
new Sign(scene, SHOP.x0 + SHOP.w / 2, GROUND + 11, SHOP.z0 + SHOP.d / 2, ['SHOP', 'Press B'], { height: 2, bg: '#ffd21f', stroke: '#ffd21f' });
const bizSigns = PLOTS.map((p) => new Sign(scene, 0, 0, 0, ['']));
function updateBizSign(k) {
  const b = BUSINESSES[k], lv = game.s.biz[k];
  const lines = lv ? [b.name, `Level ${lv}  ${money(bizIncome(b, lv) * game.mult)}/sec`] : [b.name, `FOR SALE ${money(bizCost(b, 0))}`];
  bizSigns[k].set(lines, plotSignPos(PLOTS[k], lv));
}
ui.hooks.onBizChanged = (k) => {
  updateBizSign(k);
  const p = PLOTS[k];
  if (player.hits(player.pos.x, player.pos.y, player.pos.z)) {
    player.pos.x = p.x0 + p.w / 2;
    player.pos.z = p.z0 - 2;
    player.pos.y = GROUND + 1;
  }
};
ui.hooks.onBizPopup = (k, v) => {
  const s = bizSigns[k].pos;
  if (Math.hypot(s.x - player.pos.x, s.z - player.pos.z) < 45) popups.add('+' + money(v), s.x, s.y + 1.4, s.z);
};
BUSINESSES.forEach((b, k) => updateBizSign(k));

// Build all the shapes now (the title screen shows the world).
world.remesh(blockMat, Infinity);

// ---------- Input ----------
const input = { forward: 0, right: 0, jump: false, sprint: false, mine: false, build: false };
const keys = new Set();
let state = 'title';        // title, play, pause
let touchMode = window.matchMedia('(pointer: coarse)').matches;
let locked = false;
let mouseSens = 0.0024;

function lookBy(dx, dy, sens = mouseSens) {
  player.yaw -= dx * sens;
  player.pitch = Math.max(-1.55, Math.min(1.55, player.pitch - dy * sens));
}

document.addEventListener('mousemove', (e) => {
  if (state === 'play' && locked && !ui.shopOpen) lookBy(e.movementX, e.movementY);
});
document.addEventListener('pointerlockchange', () => {
  locked = document.pointerLockElement === canvas;
  if (!locked && state === 'play' && !ui.shopOpen && !touchMode) pause();
});
document.addEventListener('pointerlockerror', () => {
  locked = false;
});
function lock() {
  if (touchMode) return;
  try {
    const p = canvas.requestPointerLock();
    if (p && p.catch) p.catch(() => {});
  } catch (e) { /* not allowed right now */ }
}

canvas.addEventListener('mousedown', (e) => {
  if (state !== 'play' || ui.shopOpen || touchMode) return;
  if (!locked) { lock(); return; }
  if (e.button === 0) input.mine = true;
  if (e.button === 2) { input.build = true; buildTimer = 0.25; tryBuild(); }
});
window.addEventListener('mouseup', (e) => {
  if (e.button === 0) input.mine = false;
  if (e.button === 2) input.build = false;
});
canvas.addEventListener('contextmenu', (e) => e.preventDefault());
canvas.addEventListener('wheel', (e) => { if (state === 'play') ui.scroll(e.deltaY > 0 ? 1 : -1); }, { passive: true });

window.addEventListener('keydown', (e) => {
  keys.add(e.code);
  if (state !== 'play') return;
  if (e.code === 'KeyB' || e.code === 'KeyE') { ui.shopOpen ? closeShop() : openShop(); }
  if (e.code === 'Escape' && ui.shopOpen) closeShop(true);
  if (e.code === 'KeyM') toggleMusic();
  if (e.code.startsWith('Digit')) {
    const n = +e.code.slice(5);
    if (n >= 1) ui.pick(n - 1);
  }
  if (e.code === 'Space') e.preventDefault();
});
window.addEventListener('keyup', (e) => keys.delete(e.code));
window.addEventListener('blur', () => { keys.clear(); input.mine = false; input.build = false; });
window.addEventListener('touchstart', () => {
  if (!touchMode) { touchMode = true; startTouch(); }
}, { passive: true });

let touchStarted = false;
function startTouch() {
  if (touchStarted || state === 'title') return;
  touchStarted = true;
  setupTouch(input, lookBy, () => { buildTimer = 0.3; tryBuild(); });
}

// ---------- Screens and save files ----------
let slot = 1;              // which save file we are playing
let worldUsed = false;     // true after the first game, so switching files resets the world
let confirmAction = null;

applySettings(Game.loadSettings());
renderSlots();
$('loading').classList.add('hidden');

function applySettings(s) {
  if (!s) return;
  sfx.setMusic(s.music !== false);
  player.autoJump = s.autoJump !== false;
  updateSettingButtons();
}
function settings() { return { music: sfx.isMusicOn(), autoJump: player.autoJump }; }
function updateSettingButtons() {
  $('music-btn').textContent = 'MUSIC: ' + (sfx.isMusicOn() ? 'ON' : 'OFF');
  $('jump-btn').textContent = 'AUTO-JUMP: ' + (player.autoJump ? 'ON' : 'OFF');
}
function toggleMusic() {
  sfx.setMusic(!sfx.isMusicOn());
  updateSettingButtons();
  Game.saveSettings(settings());
  ui.toast('Music ' + (sfx.isMusicOn() ? 'on' : 'off'));
}

// The 3 save files on the title screen.
function renderSlots() {
  let html = '';
  for (let n = 1; n <= 3; n++) {
    const d = Game.loadData(n);
    const bizCount = d && Array.isArray(d.biz) ? d.biz.filter((l) => l > 0).length : 0;
    const ores = d ? d.ores || 1 : 0;
    const info = d ? `${money(d.money || 0)} &middot; ${ores} material${ores === 1 ? '' : 's'} &middot; ${bizCount} business${bizCount === 1 ? '' : 'es'}` : 'Empty &middot; start a new world';
    html += `<div class="save-card"><button class="btn save-play${d ? ' green' : ''}" data-slot="${n}">
      <span class="save-name">SAVE ${n}</span><span class="save-info">${info}</span></button>
      ${d ? `<button class="btn red small save-del" data-slot="${n}" aria-label="Delete save ${n}">X</button>` : ''}</div>`;
  }
  $('slots').innerHTML = html;
}
$('slots').addEventListener('click', (e) => {
  const del = e.target.closest('.save-del'), play = e.target.closest('.save-play');
  sfx.startAudio();
  sfx.click();
  if (del) {
    const n = +del.dataset.slot;
    askConfirm(`DELETE SAVE ${n}?`, 'That save file will be gone forever.', () => { Game.wipe(n); renderSlots(); });
  } else if (play) startGame(+play.dataset.slot);
});

function askConfirm(title, text, action) {
  $('confirm-title').textContent = title;
  $('confirm-text').textContent = text;
  confirmAction = action;
  $('confirm').classList.remove('hidden');
}

// Put the world back the way it was made, with nothing bought.
function resetWorld() {
  game.s = Game.fresh();
  game.regrow = [];
  world.resetToBase();
  world.setUnlocked(1);
  PLOTS.forEach((p) => buildBusiness(world, p, 0));
  ui.sel = 0;
  ui.lastIncome = -1;
  ui.changed();
}

function spawnPlayer() {
  player.pos.x = SPAWN.x; player.pos.y = SPAWN.y; player.pos.z = SPAWN.z;
  player.vel.x = player.vel.y = player.vel.z = 0;
  player.yaw = 0; player.pitch = -0.05;
}

function showGame() {
  BUSINESSES.forEach((b, k) => updateBizSign(k));
  hand.setColor(PICKS[game.s.pick].color);
  $('confirm').classList.add('hidden');
  $('title').classList.add('hidden');
  $('pause').classList.add('hidden');
  $('hud').classList.remove('hidden');
  state = 'play';
  if (touchMode) startTouch();
  lock();
}

function startGame(n) {
  sfx.startAudio();
  slot = n;
  if (worldUsed) resetWorld();
  worldUsed = true;
  spawnPlayer();
  const data = Game.loadData(n);
  if (data) {
    const made = game.restore(data);
    if (data.pos) {
      [player.pos.x, player.pos.y, player.pos.z, player.yaw, player.pitch] = data.pos;
      player.unstick();
    }
    ui.toast(`Playing SAVE ${n}`, 'good');
    if (made >= 1) setTimeout(() => ui.toast(`Welcome back! Your businesses made ${money(made)} while you were gone!`, 'good'), 600);
  } else {
    setTimeout(() => ui.toast('Mine the orange Copper Ore in THE MINE. It turns into money!'), 800);
    setTimeout(() => ui.toast('Then press B to open the SHOP.'), 4200);
    setTimeout(() => ui.toast('Brave? Go down the MONEY CAVE to find Money Ore!'), 8000);
  }
  showGame();
  save();
}

// Back to the title screen to pick another save file.
function toTitle() {
  save();
  state = 'title';
  input.mine = input.build = false;
  if (document.pointerLockElement) document.exitPointerLock();
  $('pause').classList.add('hidden');
  $('hud').classList.add('hidden');
  renderSlots();
  $('title').classList.remove('hidden');
}

$('resume-btn').onclick = () => { sfx.click(); resume(); };
$('pause-btn').onclick = () => { sfx.click(); ui.shopOpen ? closeShop(true) : pause(); };
$('shop-btn').onclick = () => { sfx.click(); ui.shopOpen ? closeShop() : openShop(); };
$('music-btn').onclick = () => toggleMusic();
$('jump-btn').onclick = () => { player.autoJump = !player.autoJump; updateSettingButtons(); Game.saveSettings(settings()); sfx.click(); };
$('save-btn').onclick = () => {
  const ok = save();
  sfx.coin();
  const b = $('save-btn');
  b.textContent = ok ? `SAVED TO SAVE ${slot}!` : 'COULD NOT SAVE';
  clearTimeout(b.timer);
  b.timer = setTimeout(() => (b.textContent = 'SAVE GAME'), 1800);
};
$('files-btn').onclick = () => { sfx.click(); toTitle(); };
$('reset-btn').onclick = () => {
  sfx.click();
  askConfirm('START OVER?', `Your money, businesses and buildings in SAVE ${slot} will be gone.`, () => {
    Game.wipe(slot);
    resetWorld();
    spawnPlayer();
    showGame();
    ui.toast('A brand new world! Mine Copper Ore in THE MINE.', 'good');
    save();
  });
};
$('confirm-no').onclick = () => { sfx.click(); $('confirm').classList.add('hidden'); };
$('confirm-yes').onclick = () => {
  sfx.click();
  $('confirm').classList.add('hidden');
  const a = confirmAction;
  confirmAction = null;
  if (a) a();
};

function pause() {
  if (state !== 'play') return;
  state = 'pause';
  input.mine = input.build = false;
  if (document.pointerLockElement) document.exitPointerLock();
  $('pause').classList.remove('hidden');
  save();
}
function resume() {
  $('pause').classList.add('hidden');
  state = 'play';
  lock();
}
ui.hooks.closeShop = () => closeShop();
function openShop(tab) {
  ui.openShop(tab);
  input.mine = input.build = false;
  if (document.pointerLockElement) document.exitPointerLock();
}
function closeShop(noLock) {
  ui.closeShop();
  hand.setColor(PICKS[game.s.pick].color);
  if (!noLock) lock();
  else if (!touchMode) pause();
}

// ---------- Mining and building ----------
let hit = null;
let mining = null;         // { x, y, z, p }
let digTimer = 0, buildTimer = 0, warnTimer = 0;
const eye = new THREE.Vector3(), dir = new THREE.Vector3();

function tryBuild() {
  if (!hit) return;
  const region = world.regionAt(hit.x, hit.y, hit.z);
  if (region === R.SHOP) { input.build = false; openShop('ores'); return; }
  if (region >= R.LEMON) { input.build = false; openShop('biz'); return; }
  const x = hit.x + hit.nx, y = hit.y + hit.ny, z = hit.z + hit.nz;
  if (!world.inside(x, y, z) || SOLID[world.get(x, y, z)]) return;
  if (isProtected(world.regionAt(x, y, z))) { ui.toast("Can't build here!", 'bad'); return; }
  const id = ui.selectedBlock();
  if (!id) { if (warnTimer <= 0) { ui.toast('No blocks yet! Mine some, or buy them in the SHOP.'); warnTimer = 2; } return; }
  if (player.overlapsBlock(x, y, z)) return;
  world.set(x, y, z, id);
  game.s.inv[id]--;
  if (game.s.inv[id] <= 0) delete game.s.inv[id];
  ui.changed();
  sfx.place();
}

function breakBlock(h) {
  const res = game.mined(h.id, h.x, h.y, h.z);
  const bx = h.x + 0.5, by = h.y + 0.5, bz = h.z + 0.5;
  bits.burst(h.x, h.y, h.z, world.visual[h.id]);
  if (res.cash) {
    if (res.jackpot) {
      bits.burst(h.x, h.y, h.z, B.MONEY_ORE, 40, [[0.2, 0.85, 0.35], [1, 0.82, 0.12], [0.6, 1, 0.6]]);
      popups.add('+' + money(res.cash), bx, by + 0.6, bz, '#ffd21f', true);
      ui.bigText('JACKPOT!');
      sfx.jackpot();
    } else {
      popups.add('+' + money(res.cash), bx, by + 0.5, bz);
      sfx.coin(res.cash >= 100);
    }
  } else sfx.breakBlock(BLOCKS[h.id].hard);
  ui.changed();
}

function updateMining(dt) {
  if (!input.mine || !hit) { mining = null; return; }
  if (!mining || mining.x !== hit.x || mining.y !== hit.y || mining.z !== hit.z) mining = { x: hit.x, y: hit.y, z: hit.z, p: 0 };
  const hard = game.mineHardness(hit.id);
  if (hard === Infinity || isProtected(world.regionAt(hit.x, hit.y, hit.z))) {
    if (warnTimer <= 0) { ui.toast(hard === Infinity ? 'Bedrock is too hard to break!' : 'You can\'t break buildings. Right-click to shop!'); warnTimer = 2.5; }
    mining = null;
    return;
  }
  mining.p += (dt * game.pickSpeed()) / hard;
  digTimer -= dt;
  if (digTimer <= 0) { sfx.dig(hard); digTimer = 0.22; }
  if (mining.p >= 1) {
    breakBlock(hit);
    mining = null;
    hit = null;
  }
}

// ---------- Saving ----------
function save() { return state !== 'title' && worldUsed ? game.save(player, slot) : false; }
setInterval(save, 5000);
document.addEventListener('visibilitychange', () => { if (document.hidden) { save(); if (state === 'play' && touchMode) pause(); } });
window.addEventListener('pagehide', save);

// ---------- Every frame ----------
let last = performance.now();
let stepAt = 0, puffTimer = 0, titleT = 0;

function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  warnTimer -= dt;

  if (state === 'title') {
    titleT += dt * 0.08;
    camera.position.set(64 + Math.cos(titleT) * 46, GROUND + 22, 58 + Math.sin(titleT) * 46);
    camera.lookAt(64, GROUND + 2, 58);
  } else {
    const active = state === 'play' && !ui.shopOpen;
    if (!touchMode) {
      input.forward = (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0) - (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0);
      input.right = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0) - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0);
      input.jump = keys.has('Space');
      input.sprint = keys.has('ShiftLeft') || keys.has('ShiftRight');
    }
    const still = { forward: 0, right: 0, jump: false, sprint: false };
    if (state === 'play') player.update(dt, active ? input : still);
    if (player.splashed) sfx.splash();
    if (player.walked > stepAt) { stepAt = player.walked + 1.9; sfx.step(); }

    const bob = player.onGround ? Math.abs(Math.sin(player.walked * 2.2)) * 0.06 : 0;
    camera.position.set(player.pos.x, player.pos.y + EYE + bob, player.pos.z);
    camera.rotation.set(player.pitch, player.yaw, 0);
    const fov = input.sprint && active && Math.hypot(player.vel.x, player.vel.z) > 5 ? 82 : 75;
    if (Math.abs(camera.fov - fov) > 0.1) { camera.fov += (fov - camera.fov) * Math.min(1, dt * 8); camera.updateProjectionMatrix(); }

    if (state === 'play') {
      camera.getWorldDirection(dir);
      eye.copy(camera.position);
      hit = active ? world.raycast(eye, dir, REACH) : null;
      if (active) {
        updateMining(dt);
        if (input.build) { buildTimer -= dt; if (buildTimer <= 0) { buildTimer = 0.25; tryBuild(); } }
      } else mining = null;
      game.tick(dt, player);
      ui.update();
      ui.setLook(hit, world);
    }
    target.show(hit, mining ? mining.p : 0);

    // Under water?
    const under = camera.position.y < SEA - 0.1 && player.inWater;
    $('water-tint').classList.toggle('on', under);
    scene.fog.color.copy(under ? WATER_FOG : SKY_FOG);
    scene.fog.near = under ? 2 : 40;
    scene.fog.far = under ? 28 : 120;

    // Money smoke from the factory.
    puffTimer -= dt;
    if (game.s.biz[2] > 0 && puffTimer <= 0) {
      puffTimer = 0.3;
      for (const c of chimneys(game.s.biz[2])) bits.puff(c.x, c.y, c.z);
    }
  }

  world.remesh(blockMat, 7);
  bits.update(dt, world);
  popups.update(dt);
  sky.position.copy(camera.position);
  clouds.position.x = ((clouds.position.x + dt * 1.2 + 200) % 400) - 200;
  hand.update(dt, !!mining, player.walked, camera.aspect);

  renderer.clear();
  renderer.render(scene, camera);
  if (state !== 'title') {
    renderer.clearDepth();
    renderer.render(hand.scene, hand.camera);
  }
}
requestAnimationFrame(frame);

// For testing from the browser console.
window.cave = { world, game, player, ui, input, camera, startGame, openShop, closeShop, breakBlock, get state() { return state; }, get hit() { return hit; } };
