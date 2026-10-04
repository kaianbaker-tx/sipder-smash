// CAVE CASH: starts everything and runs the game every frame.
import * as THREE from '../lib/three.min.js';
import { buildAtlas } from './atlas.js';
import { B, BLOCKS, SOLID, PLANT } from './blocks.js';
import { ORES, PICKS, money } from './data.js';
import { World, W, D, SEA, BIOME, BIOME_NAMES } from './world.js';
import { Player, EYE } from './player.js';
import { Game } from './game.js';
import { UI } from './ui.js';
import { Bits, Popups, Target, Hand, makeSky, makeClouds, makeWater } from './fx.js';
import { DayNight, CYCLE } from './daynight.js';
import { Mobs } from './mobs.js';
import { setupTouch } from './touch.js';
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
const SPAWN = world.findSpawn();
world.setUnlocked(1);
scene.add(world.group);
let viewFar = true;
const view = () => (viewFar ? 6 : 4);   // how many chunks you can see

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
const mobs = new Mobs(world, scene, bits, sfx);
let wasNight = false;

// Make the land around the start right away (the title screen shows it).
world.prepare(SPAWN.x, SPAWN.z, 3, blockMat);

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

const menuOpen = () => ui.shopOpen || ui.invOpen;
document.addEventListener('mousemove', (e) => {
  if (state === 'play' && locked && !menuOpen()) lookBy(e.movementX, e.movementY);
});
document.addEventListener('pointerlockchange', () => {
  locked = document.pointerLockElement === canvas;
  if (!locked && state === 'play' && !menuOpen() && !touchMode) pause();
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
  if (state !== 'play' || menuOpen() || touchMode) return;
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
  if (e.code === 'KeyB' && !ui.invOpen) { ui.shopOpen ? closeShop() : openShop(); }
  if (e.code === 'KeyE' && !ui.shopOpen) { ui.invOpen ? closeInv() : openInv(); }
  if (e.code === 'Escape' && ui.shopOpen) closeShop(true);
  if (e.code === 'Escape' && ui.invOpen) closeInv(true);
  if (e.code === 'KeyM') toggleMusic();
  if (e.code === 'KeyF' && !menuOpen()) game.eat();
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
  viewFar = s.viewFar !== false;
  updateSettingButtons();
}
function settings() { return { music: sfx.isMusicOn(), autoJump: player.autoJump, viewFar }; }
function updateSettingButtons() {
  $('music-btn').textContent = 'MUSIC: ' + (sfx.isMusicOn() ? 'ON' : 'OFF');
  $('jump-btn').textContent = 'AUTO-JUMP: ' + (player.autoJump ? 'ON' : 'OFF');
  $('view-btn').textContent = 'VIEW: ' + (viewFar ? 'FAR' : 'NEAR');
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
  mobs.clear();
  for (const t of lit) { scene.remove(t.mesh); t.mesh.material.dispose(); }
  lit.length = 0;
  game.s = Game.fresh();
  world.reset();
  world.setUnlocked(1);
  ui.sel = 0;
  ui.lastIncome = -1;
  ui.changed();
}

// Wake up at your bed if you have one, or at the start.
function spawnPlayer() {
  let p = SPAWN;
  const bed = game.s.spawn;
  if (bed) {
    world.prepare(bed[0], bed[2], 1, blockMat);
    if (world.get(Math.floor(bed[0]), Math.floor(bed[1]) - 1, Math.floor(bed[2])) === B.BED) p = { x: bed[0], y: bed[1], z: bed[2] };
    else { game.s.spawn = null; ui.toast('Your bed was gone, so you woke up at the start.'); }
  }
  world.prepare(p.x, p.z, 2, blockMat);
  player.pos.x = p.x; player.pos.y = p.y; player.pos.z = p.z;
  player.vel.x = player.vel.y = player.vel.z = 0;
  player.yaw = 0; player.pitch = -0.05;
  player.fallTop = null; player.fallHurt = 0;
  player.unstick();
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
  resetWorld();          // the title screen already made some land; start clean
  worldUsed = true;
  const data = Game.loadData(n);
  mobs.clear();
  if (data) {
    const same = game.restore(data);
    spawnPlayer();
    if (same && data.pos) {
      [player.pos.x, player.pos.y, player.pos.z, player.yaw, player.pitch] = data.pos;
      world.prepare(player.pos.x, player.pos.z, 2, blockMat);
      player.unstick();
    }
    ui.toast(`Playing SAVE ${n}`, 'good');
    if (!same) setTimeout(() => ui.toast('The island got WAY bigger! You kept your money and your stuff.', 'good'), 600);
  } else {
    spawnPlayer();
    tutorial();
  }
  wasNight = game.night;
  showGame();
  save();
}

function tutorial() {
  setTimeout(() => ui.toast('Explore! Ore in caves and cliffs turns into money.'), 800);
  setTimeout(() => ui.toast('Orange specks are Copper Ore. Press B to open the SHOP.'), 4200);
  setTimeout(() => ui.toast('Build your House Kit before night: pick it, aim at the ground, right-click!'), 8000);
  setTimeout(() => ui.toast('Hungry? Hit pigs, cows and chickens for food. Press E for your inventory.'), 12000);
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
$('view-btn').onclick = () => { viewFar = !viewFar; updateSettingButtons(); Game.saveSettings(settings()); sfx.click(); };
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
    ui.toast('A brand new world! Go explore!', 'good');
    tutorial();
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
ui.hooks.closeInv = () => closeInv();
function openInv() {
  ui.openInv();
  input.mine = input.build = false;
  if (document.pointerLockElement) document.exitPointerLock();
}
function closeInv(noLock) {
  ui.closeInv();
  if (!noLock) lock();
  else if (!touchMode) pause();
}
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
  if (hit.id === B.BED) { input.build = false; sleep(hit.x, hit.y, hit.z); return; }
  if (held === B.HOUSE_KIT) { input.build = false; placeHouse(); return; }
  // Tall grass and flowers get replaced, like in Minecraft.
  const swap = PLANT[hit.id] === 1;
  const x = swap ? hit.x : hit.x + hit.nx, y = swap ? hit.y : hit.y + hit.ny, z = swap ? hit.z : hit.z + hit.nz;
  if (!world.inside(x, y, z) || SOLID[world.get(x, y, z)]) return;
  if (held && PLANT[held] && !SOLID[world.get(x, y - 1, z)]) return;
  if (!held) { if (warnTimer <= 0) { ui.toast('No blocks yet! Mine some, or buy them in the SHOP.'); warnTimer = 2; } return; }
  if (player.overlapsBlock(x, y, z)) return;
  world.set(x, y, z, held);
  game.take(held);
  ui.changed();
  sfx.place();
}

// A whole house in one click! The door faces you.
function placeHouse() {
  // Aiming at tall grass or a flower counts as aiming at the ground under it.
  const ground = hit && PLANT[hit.id] ? { x: hit.x, y: hit.y - 1, z: hit.z, ny: 1 } : hit;
  if (!ground || ground.ny !== 1) { ui.toast('Aim at the ground to place your house!', 'bad'); return; }
  const fx = Math.abs(Math.sin(player.yaw)) > Math.abs(Math.cos(player.yaw)) ? -Math.sign(Math.sin(player.yaw)) : 0;
  const fz = fx ? 0 : -Math.sign(Math.cos(player.yaw));
  const rx = -fz, rz = fx;               // to the right
  const base = ground.y + 1;
  let ox = ground.x, oz = ground.z;      // middle of the front wall
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
      if (!world.inside(x, y, z) || world.get(x, y, z) === B.BEDROCK) {
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
  put(-2, 5, 0, B.BED); put(-2, 4, 0, B.BED);
  put(2, 5, 0, B.LAMP);
  put(2, 1, 0, B.LOG);
  player.unstick();
  bits.burst(ground.x, base, ground.z, B.PLANKS, 30);
  sfx.levelUp();
  ui.toast('You built a house! Right-click the bed to sleep through the night.', 'good');
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
  mobs.clear();
  spawnPlayer();
  state = 'play';
  lock();
  ui.toast('Keep your hunger bar full! Eat food to stay alive.');
};
$('t-eat').addEventListener('pointerdown', (e) => { e.preventDefault(); if (state === 'play') game.eat(); });

// ---------- Fighting ----------
let attackCool = 0;
let mobHit = null;
function zombieMoney() { return Math.max(10, ORES[game.s.ores - 1].value * 3); }
const MOB_NAMES = { zombie: 'Zombie', pig: 'Pig', cow: 'Cow', chicken: 'Chicken' };

function updateFight(dt) {
  attackCool -= dt;
  mobHit = mobs.hitTest(eye, dir, 4);
  if (mobHit && hit && hit.t < mobHit.t) mobHit = null;
  if (!mobHit || !input.mine) return !!mobHit;
  mining = null;
  if (attackCool > 0) return true;
  attackCool = 0.4;
  hand.swing = 0.25;
  const m = mobHit.mob;
  if (mobs.damage(m, 3 + game.s.pick * 1.2, dir)) {
    const p = m.body.pos;
    if (m.k.hostile) {
      const cash = game.earn(zombieMoney());
      game.s.kills++;
      popups.add('+' + money(cash), p.x, p.y + 2.2, p.z, '#ffd21f', true);
      sfx.coin(true);
      if (Math.random() < 0.35) { game.give(B.APPLE, 1); ui.toast('The zombie dropped an apple!'); }
    } else {
      const n = m.kind === 'cow' ? 2 : 1;
      game.give(m.k.food, n);
      popups.add(`+${n} ${BLOCKS[m.k.food].name}`, p.x, p.y + 1.4, p.z, '#ffe0a0');
      sfx.place();
    }
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

// ---------- Sleeping ----------
let sleepTimer = 0;
function sleep(x, y, z) {
  game.s.spawn = [x + 0.5, y + 1, z + 0.5];
  if (!game.night) {
    ui.toast('Bed set! You will wake up here. You can only sleep at night.', 'good');
    save();
    return;
  }
  if (mobs.zombiesNear(player.pos, 10)) { ui.toast("You can't sleep now, there are zombies nearby!", 'bad'); return; }
  state = 'sleep';
  sleepTimer = 2.6;
  input.mine = input.build = false;
  $('sleep-fade').classList.add('on');
  sfx.sleep();
}

function updateSleep(dt) {
  sleepTimer -= dt;
  if (sleepTimer < 1.3 && game.night) game.s.clock = 0.995 * CYCLE;
  if (sleepTimer > 0) return;
  $('sleep-fade').classList.remove('on');
  state = 'play';
  ui.toast('Good morning!', 'good');
  save();
}

// Touching a cactus hurts.
let cactusClock = 0;
function touchingCactus() {
  const p = player.pos;
  for (let y = Math.floor(p.y); y <= Math.floor(p.y + 1.7); y++)
    for (let z = Math.floor(p.z - 0.36); z <= Math.floor(p.z + 0.36); z++)
      for (let x = Math.floor(p.x - 0.36); x <= Math.floor(p.x + 0.36); x++)
        if (world.get(x, y, z) === B.CACTUS) return true;
  return false;
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
  if (hard === Infinity) {
    if (warnTimer <= 0) { ui.toast('Bedrock is too hard to break!'); warnTimer = 2.5; }
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
let stepAt = 0, titleT = 0, cloudDrift = 0;
let biomeHere = -1, biomeTime = 0;

// Say hello when you walk into a new biome.
function checkBiome(dt) {
  const x = Math.floor(player.pos.x), z = Math.floor(player.pos.z);
  if (x < 0 || z < 0 || x >= W || z >= D) return;
  const b = world.biome[x + W * z];
  if (b === BIOME.OCEAN || b === BIOME.BEACH) return;
  if (b === biomeHere) { biomeTime = 0; return; }
  biomeTime += dt;
  if (biomeTime < 1.5) return;
  const first = biomeHere === -1;
  biomeHere = b;
  biomeTime = 0;
  if (!first) ui.toast('Welcome to the ' + BIOME_NAMES[b] + '!');
}

function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  warnTimer -= dt;

  // Load the chunks around you.
  const fx = state === 'title' ? SPAWN.x : player.pos.x, fz = state === 'title' ? SPAWN.z : player.pos.z;
  world.stream(fx, fz, view(), blockMat, 7);

  if (state === 'title') {
    titleT += dt * 0.06;
    camera.position.set(SPAWN.x + Math.cos(titleT) * 40, SPAWN.y + 24, SPAWN.z + Math.sin(titleT) * 40);
    camera.lookAt(SPAWN.x, SPAWN.y + 4, SPAWN.z);
  } else {
    if (state === 'sleep') updateSleep(dt);
    const active = state === 'play' && !menuOpen();
    if (!touchMode) {
      input.forward = (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0) - (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0);
      input.right = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0) - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0);
      input.jump = keys.has('Space');
      input.sprint = keys.has('ShiftLeft') || keys.has('ShiftRight');
    }
    const still = { forward: 0, right: 0, jump: false, sprint: false };
    if (state === 'play') player.update(dt, active ? input : still);
    if (player.splashed) sfx.splash();
    if (player.fallHurt > 0) {
      const n = player.fallHurt;
      player.fallHurt = 0;
      if (state === 'play' && game.hurt(n)) died('You fell from too high!');
    }
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
      game.tick(dt);
      updateTNT(dt);
      if (active) {
        const busy = input.mine || (input.sprint && Math.hypot(player.vel.x, player.vel.z) > 5);
        if (game.body(dt, busy) === 'starved') died('You starved! Your hunger bar ran out.');
        cactusClock -= dt;
        if (state === 'play' && cactusClock <= 0 && touchingCactus()) {
          cactusClock = 0.8;
          if (game.hurt(1)) died('Ouch! A cactus got you.');
        }
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
      if (active) checkBiome(dt);
      if (active) mobs.update(dt, { player, night, level: dayNight.level, maxZombies: 3 + Math.min(5, game.s.nights), hitPlayer: zombieHitsPlayer });
      ui.update();
      if (mobHit) {
        const m = mobHit.mob, hearts = '&#9829;'.repeat(Math.max(1, Math.ceil(m.hp / 2)));
        $('look-label').innerHTML = `${MOB_NAMES[m.kind]} &nbsp;<span class="cash">${hearts}${m.k.hostile ? ' +' + money(zombieMoney() * game.mult) : ''}</span>`;
      } else ui.setLook(hit, world);
    }
    target.show(hit, mining ? mining.p : 0);

    // Under water?
    const wet = camera.position.y < SEA - 0.1 && player.inWater;
    $('water-tint').classList.toggle('on', wet);
    if (wet) scene.fog.color.copy(WATER_FOG);
  }
  const under = state !== 'title' && camera.position.y < SEA - 0.1 && player.inWater;
  const far = view() * 16 - 6;
  scene.fog.near = under ? 2 : far * 0.45;
  scene.fog.far = under ? 28 : far;

  dayNight.update(game.dayTime);
  hand.light(Math.max(0.45, dayNight.level));
  if (!$('water-tint').classList.contains('on')) scene.fog.color.copy(dayNight.fog);
  bits.update(dt, world);
  popups.update(dt);
  sky.position.copy(camera.position);
  // Clouds drift by. They repeat every 640 blocks, so they are always around you.
  cloudDrift += dt * 1.2;
  clouds.position.x = cloudDrift + Math.floor((camera.position.x - cloudDrift - 320) / 640) * 640;
  clouds.position.z = Math.floor((camera.position.z - 320) / 640) * 640;
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
window.cave = { world, game, player, ui, input, camera, mobs, dayNight, SPAWN, sleep, openInv, startGame, openShop, closeShop, breakBlock, lightTNT, tryBuild, get state() { return state; }, get hit() { return hit; } };
