// CAVE CASH: starts everything and runs the game every frame.
import * as THREE from '../lib/three.min.js';
import { buildAtlas } from './atlas.js';
import { B, BLOCKS, SOLID } from './blocks.js';
import { ORES, PICKS, money } from './data.js';
import { World, W, D, SEA, GROUND, isProtected, R } from './world.js';
import { buildTown, buildCave, SPAWN, MINE, SHOP, CAVE } from './town.js';
import { Player, EYE } from './player.js';
import { Game } from './game.js';
import { UI } from './ui.js';
import { Bits, Popups, Sign, Target, Hand, makeSky, makeClouds, makeWater } from './fx.js';
import { DayNight } from './daynight.js';
import { Zombies } from './zombies.js';
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
const water = makeWater(scene, SEA, world, W, D);
const dayNight = new DayNight(scene, sky, clouds, water, blockMat);
const bits = new Bits(scene);
const popups = new Popups(scene);
const target = new Target(scene, atlasTex);
const hand = new Hand();
const zombies = new Zombies(world, scene, bits, sfx);
let wasNight = false;

// Signs.
new Sign(scene, (MINE.x0 + MINE.x1) / 2, GROUND + 7, MINE.z0 + 1, ['THE MINE', 'Ore grows back!'], { height: 1.8 });
new Sign(scene, CAVE.x - 1, GROUND + 4.5, (CAVE.z0 + CAVE.z1 + 1) / 2, ['MONEY CAVE', 'Dig for Money Ore!'], { height: 1.6, bg: '#27c95a', stroke: '#27c95a', color: '#fff6d6', color2: '#fff6d6', border: '#1b0d2e' });
new Sign(scene, SHOP.x0 + SHOP.w / 2, GROUND + 11, SHOP.z0 + SHOP.d / 2, ['SHOP', 'Press B'], { height: 2, bg: '#ffd21f', stroke: '#ffd21f' });

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
  if (e.code === 'KeyF' && !ui.shopOpen) game.eat();
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
    const ores = d ? d.ores || 1 : 0;
    const info = d ? `${money(d.money || 0)} &middot; ${ores} material${ores === 1 ? '' : 's'} &middot; day ${(d.nights || 0) + 1}` : 'Empty &middot; start a new world';
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
  zombies.clear();
  game.s = Game.fresh();
  game.regrow = [];
  world.resetToBase();
  world.setUnlocked(1);
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
  zombies.clear();
  if (data) {
    game.restore(data);
    if (data.pos) {
      [player.pos.x, player.pos.y, player.pos.z, player.yaw, player.pitch] = data.pos;
      player.unstick();
    }
    ui.toast(`Playing SAVE ${n}`, 'good');
  } else {
    setTimeout(() => ui.toast('Mine the orange Copper Ore in THE MINE. It turns into money!'), 800);
    setTimeout(() => ui.toast('Then press B to open the SHOP.'), 4200);
    setTimeout(() => ui.toast('Brave? Go down the MONEY CAVE to find Money Ore!'), 8000);
    setTimeout(() => ui.toast('Watch your hunger bar! Right-click an apple to eat it.'), 12000);
  }
  wasNight = game.night;
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
  askConfirm('START OVER?', `Your money and buildings in SAVE ${slot} will be gone.`, () => {
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
  const held = ui.selectedBlock();
  // Holding food? Right-click eats it, like Minecraft.
  if (held && BLOCKS[held].food) { input.build = false; game.eat(held); return; }
  if (!hit) return;
  const region = world.regionAt(hit.x, hit.y, hit.z);
  if (region === R.SHOP) { input.build = false; openShop('ores'); return; }
  if (held === B.HOUSE_KIT) { input.build = false; placeHouse(); return; }
  const x = hit.x + hit.nx, y = hit.y + hit.ny, z = hit.z + hit.nz;
  if (!world.inside(x, y, z) || SOLID[world.get(x, y, z)]) return;
  if (isProtected(world.regionAt(x, y, z))) { ui.toast("Can't build here!", 'bad'); return; }
  if (!held) { if (warnTimer <= 0) { ui.toast('No blocks yet! Mine some, or buy them in the SHOP.'); warnTimer = 2; } return; }
  if (player.overlapsBlock(x, y, z)) return;
  world.set(x, y, z, held);
  game.take(held);
  ui.changed();
  sfx.place();
}

// A whole house in one click! The door faces you.
function placeHouse() {
  if (!hit || hit.ny !== 1) { ui.toast('Aim at the ground to place your house!', 'bad'); return; }
  const fx = Math.abs(Math.sin(player.yaw)) > Math.abs(Math.cos(player.yaw)) ? -Math.sign(Math.sin(player.yaw)) : 0;
  const fz = fx ? 0 : -Math.sign(Math.cos(player.yaw));
  const rx = -fz, rz = fx;               // to the right
  const base = hit.y + 1;
  let ox = hit.x, oz = hit.z;            // middle of the front wall
  const cell = (i, j) => [ox + i * rx + j * fx, oz + i * rz + j * fz];
  // Do not build on top of the player.
  for (let t = 0; t < 3; t++) {
    let bad = false;
    for (let i = -3; i <= 3; i++) for (let j = 0; j <= 6; j++) {
      const [x, z] = cell(i, j);
      for (let y = base; y < base + 6; y++) if (player.overlapsBlock(x, y, z)) bad = true;
    }
    if (!bad) break;
    ox += fx; oz += fz;
  }
  for (let i = -3; i <= 3; i++) for (let j = 0; j <= 6; j++) {
    const [x, z] = cell(i, j);
    for (let y = base - 1; y < base + 7; y++) {
      if (!world.inside(x, y, z) || isProtected(world.regionAt(x, y, z)) || world.get(x, y, z) === B.BEDROCK) {
        ui.toast('No room for a house here. Try an open spot!', 'bad');
        sfx.nope();
        return;
      }
    }
  }
  game.take(B.HOUSE_KIT);
  for (let i = -3; i <= 3; i++) for (let j = 0; j <= 6; j++) {
    const [x, z] = cell(i, j);
    const edgeI = Math.abs(i) === 3, edgeJ = j === 0 || j === 6;
    // Floor, and a stone base down to the ground.
    world.set(x, base - 1, z, B.PLANKS);
    for (let y = base - 2, n = 0; n < 6 && y >= 0 && !SOLID[world.get(x, y, z)]; y--, n++) world.set(x, y, z, B.COBBLE);
    for (let y = base; y < base + 6; y++) world.set(x, y, z, 0);
    // Walls with windows.
    if (edgeI || edgeJ) {
      for (let h = 0; h < 3; h++) {
        let id = edgeI && edgeJ ? B.LOG : B.PLANKS;
        if (h === 1 && !(edgeI && edgeJ) && (edgeI ? j === 2 || j === 4 : Math.abs(i) === 2)) id = B.GLASS;
        world.set(x, base + h, z, id);
      }
    }
    // Roof like a little pyramid.
    const ring = Math.max(Math.abs(i), Math.abs(j - 3));
    world.set(x, base + 3, z, B.BRICK);
    if (ring <= 2) world.set(x, base + 4, z, B.BRICK);
    if (ring <= 1) world.set(x, base + 5, z, B.BRICK);
  }
  // Door, bed and a lamp.
  const put = (i, j, h, id) => { const [x, z] = cell(i, j); world.set(x, base + h, z, id); };
  put(0, 0, 0, 0); put(0, 0, 1, 0);
  put(-2, 5, 0, B.WHITE); put(-2, 4, 0, B.RED); put(-2, 3, 0, B.RED);
  put(2, 5, 0, B.LAMP);
  put(2, 1, 0, B.LOG);
  player.unstick();
  bits.burst(hit.x, base, hit.z, B.PLANKS, 30);
  sfx.levelUp();
  ui.toast('You built a house! Walk in through the door.', 'good');
  ui.changed();
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

// ---------- TNT ----------
const lit = [];             // TNT that is about to blow up
const flashGeo = new THREE.BoxGeometry(1.02, 1.02, 1.02);
let shake = 0;

function lightTNT(x, y, z, fuseTime = 3) {
  const old = lit.find((t) => t.x === x && t.y === y && t.z === z);
  if (old) { old.t = Math.min(old.t, fuseTime); return; }
  const mesh = new THREE.Mesh(flashGeo, new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0, depthWrite: false }));
  mesh.position.set(x + 0.5, y + 0.5, z + 0.5);
  scene.add(mesh);
  lit.push({ x, y, z, t: fuseTime, mesh });
  if (fuseTime > 1) { sfx.fuse(); ui.toast('RUN!!!', 'bad'); }
}

function updateTNT(dt) {
  for (let i = lit.length - 1; i >= 0; i--) {
    const t = lit[i];
    t.t -= dt;
    t.mesh.material.opacity = Math.sin(t.t * (t.t < 1 ? 30 : 12)) > 0 ? 0.7 : 0;
    t.mesh.scale.setScalar(1 + Math.max(0, 0.6 - t.t) * 0.25);
    if (t.t > 0) continue;
    lit.splice(i, 1);
    scene.remove(t.mesh);
    t.mesh.material.dispose();
    const id = world.get(t.x, t.y, t.z);
    if (id === B.TNT || id === B.MEGA_TNT) explodeAt(t.x, t.y, t.z, id);
  }
}

function explodeAt(x, y, z, id) {
  const big = id === B.MEGA_TNT, radius = BLOCKS[id].boom;
  world.set(x, y, z, 0);
  const res = game.explode(x, y, z, radius);
  const fire = [[1, 0.55, 0.1], [1, 0.85, 0.2], [0.35, 0.35, 0.35], [0.9, 0.2, 0.1]];
  for (let k = 0; k < (big ? 4 : 2); k++) bits.burst(x + (Math.random() - 0.5) * radius, y + (Math.random() - 0.5) * radius, z + (Math.random() - 0.5) * radius, B.STONE, 30, fire);
  sfx.boom(big);
  shake = big ? 0.9 : 0.5;
  if (res.cash) {
    popups.add('+' + money(res.cash), x + 0.5, y + 1.5, z + 0.5, '#ffd21f', true);
    if (res.jackpot) { ui.bigText('BOOM JACKPOT!'); sfx.jackpot(); } else sfx.coin(true);
  }
  for (const c of res.chain) lightTNT(c.x, c.y, c.z, 0.25 + Math.random() * 0.35);
  // Too close? Ouch! You get pushed away.
  const p = player.pos;
  const dx = p.x - (x + 0.5), dy = p.y + 0.9 - (y + 0.5), dz = p.z - (z + 0.5);
  const d = Math.hypot(dx, dy, dz);
  if (d < radius + 2.5 && state === 'play') {
    const push = (radius + 2.5 - d) * 3;
    player.vel.x += (dx / (d || 1)) * push;
    player.vel.z += (dz / (d || 1)) * push;
    player.vel.y += 4 + push * 0.4;
    if (game.hurt(Math.ceil((radius + 2.5 - d) * (big ? 1.6 : 1.3)))) died('You got blown up by TNT!');
  }
  ui.changed();
}

// ---------- Dying ----------
function died(why) {
  const lost = game.die();
  state = 'dead';
  input.mine = input.build = false;
  if (document.pointerLockElement) document.exitPointerLock();
  $('dead-why').textContent = why;
  $('dead-lost').textContent = lost > 0 ? `You dropped ${money(lost)}.` : '';
  $('dead').classList.remove('hidden');
  save();
}
$('respawn-btn').onclick = () => {
  sfx.click();
  $('dead').classList.add('hidden');
  spawnPlayer();
  state = 'play';
  lock();
  ui.toast('Keep your hunger bar full! Eat food to stay alive.');
};
$('t-eat').addEventListener('pointerdown', (e) => { e.preventDefault(); if (state === 'play') game.eat(); });

// ---------- Fighting zombies ----------
let attackCool = 0;
let zombieHit = null;
function zombieMoney() { return Math.max(10, ORES[game.s.ores - 1].value * 3); }

function updateFight(dt) {
  attackCool -= dt;
  zombieHit = zombies.hitTest(eye, dir, 4);
  if (zombieHit && hit && hit.t < zombieHit.t) zombieHit = null;
  if (!zombieHit || !input.mine) return !!zombieHit;
  mining = null;
  if (attackCool > 0) return true;
  attackCool = 0.4;
  hand.swing = 0.25;
  const z = zombieHit.zombie;
  if (zombies.damage(z, 3 + game.s.pick * 1.2, dir)) {
    const p = z.body.pos;
    const cash = game.earn(zombieMoney());
    game.s.kills++;
    popups.add('+' + money(cash), p.x, p.y + 2.2, p.z, '#ffd21f', true);
    sfx.coin(true);
    if (Math.random() < 0.35) { game.give(B.APPLE, 1); ui.toast('The zombie dropped an apple!'); }
    ui.changed();
  }
  return true;
}

function zombieHitsPlayer(dmg, z) {
  if (state !== 'play' || ui.shopOpen) return;
  const zp = z.body.pos, p = player.pos;
  const dx = p.x - zp.x, dz = p.z - zp.z, d = Math.hypot(dx, dz) || 1;
  player.vel.x += (dx / d) * 6;
  player.vel.z += (dz / d) * 6;
  player.vel.y = Math.max(player.vel.y, 4);
  if (game.hurt(dmg)) died('A zombie got you! Stay near lamps at night.');
}

function updateMining(dt) {
  if (!input.mine || !hit) { mining = null; return; }
  if (hit.id === B.TNT || hit.id === B.MEGA_TNT) {
    // Hitting TNT lights it.
    if (!lit.some((t) => t.x === hit.x && t.y === hit.y && t.z === hit.z)) lightTNT(hit.x, hit.y, hit.z);
    mining = null;
    return;
  }
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
let stepAt = 0, titleT = 0;

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
    if (shake > 0) {
      camera.position.x += (Math.random() - 0.5) * shake;
      camera.position.y += (Math.random() - 0.5) * shake;
      camera.position.z += (Math.random() - 0.5) * shake;
      shake = Math.max(0, shake - dt * 1.5);
    }
    const fov = input.sprint && active && Math.hypot(player.vel.x, player.vel.z) > 5 ? 82 : 75;
    if (Math.abs(camera.fov - fov) > 0.1) { camera.fov += (fov - camera.fov) * Math.min(1, dt * 8); camera.updateProjectionMatrix(); }

    if (state === 'play') {
      camera.getWorldDirection(dir);
      eye.copy(camera.position);
      hit = active ? world.raycast(eye, dir, REACH) : null;
      if (active) {
        if (!updateFight(dt)) updateMining(dt);
        if (input.build) { buildTimer -= dt; if (buildTimer <= 0) { buildTimer = 0.25; tryBuild(); } }
      } else mining = null;
      game.tick(dt, player);
      updateTNT(dt);
      if (active) {
        const busy = input.mine || (input.sprint && Math.hypot(player.vel.x, player.vel.z) > 5);
        if (game.body(dt, busy) === 'starved') died('You starved! Your hunger bar ran out.');
      }
      // Night: zombies come out.
      const night = game.night;
      if (night && !wasNight) {
        game.s.nights++;
        ui.bigText('NIGHT ' + game.s.nights);
        ui.toast('Night is here! ZOMBIES come out. Stay near lamps, or hit them with your pickaxe!', 'bad');
      } else if (!night && wasNight) {
        ui.toast('The sun is up! The zombies are burning!', 'good');
      } else if (!night && game.dayTime > 0.55 && game.dayTime < 0.553) {
        ui.toast('The sun is going down... get ready for zombies!');
      }
      wasNight = night;
      if (active) zombies.update(dt, { player, night, level: dayNight.level, max: 3 + Math.min(5, game.s.nights), hitPlayer: zombieHitsPlayer });
      ui.update();
      if (zombieHit) $('look-label').innerHTML = `Zombie &nbsp;<span class="cash">${'&#9829;'.repeat(Math.max(1, Math.ceil(zombieHit.zombie.hp / 2)))} +${money(zombieMoney() * game.mult)}</span>`;
      else ui.setLook(hit, world);
    }
    target.show(hit, mining ? mining.p : 0);

    // Under water?
    const under = camera.position.y < SEA - 0.1 && player.inWater;
    $('water-tint').classList.toggle('on', under);
    if (under) scene.fog.color.copy(WATER_FOG);
    scene.fog.near = under ? 2 : 40;
    scene.fog.far = under ? 28 : 120;
  }

  dayNight.update(game.dayTime);
  hand.light(Math.max(0.45, dayNight.level));
  if (!$('water-tint').classList.contains('on')) scene.fog.color.copy(dayNight.fog);
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
window.cave = { world, game, player, ui, input, camera, zombies, dayNight, startGame, openShop, closeShop, breakBlock, lightTNT, tryBuild, get state() { return state; }, get hit() { return hit; } };
