// The town: THE MINE, the SHOP, paths, and the 3 business buildings.
import { B } from './blocks.js';
import { ORES } from './data.js';
import { H, GROUND, R } from './world.js';

export const SPAWN = { x: 64.5, y: GROUND + 1, z: 62.5 };

// The big mine pit. Its walls grow back ore after you mine them.
export const MINE = { x0: 52, x1: 76, z0: 30, z1: 50, ring: 2, bottom: 8 };

export const SHOP = { x0: 80, z0: 56, w: 9, d: 9 };

// The Money Cave: stairs go down from town to a big cave full of ore.
export const CAVE = { x: 47, z0: 57, z1: 59, room: { x: 27, y: 9, z: 58, rx: 9, ry: 4.5, rz: 9 } };

// Business plots. The front (door) faces north, toward spawn.
export const PLOTS = [
  { key: 'lemon', region: R.LEMON, x0: 43, z0: 70, w: 9, d: 9, wall: B.YELLOW, trim: B.WHITE, ring: B.YELLOW },
  { key: 'pizza', region: R.PIZZA, x0: 77, z0: 70, w: 10, d: 10, wall: B.RED, trim: B.WHITE, ring: B.RED },
  { key: 'factory', region: R.FACTORY, x0: 55, z0: 72, w: 19, d: 16, wall: B.METAL, trim: B.BRICK, ring: B.GOLD_BLOCK },
];

// Where each plot's floating sign goes (changes with the building height).
export function plotSignPos(p, level) {
  const top = level > 0 ? GROUND + 3 * level + (p.key === 'lemon' ? 5 : 9) : GROUND + 4;
  return { x: p.x0 + p.w / 2, y: top, z: p.z0 - 0.5 };
}

const mineDepth = (x, z) => {
  const e = Math.min(x - MINE.x0, MINE.x1 - 1 - x, z - MINE.z0, MINE.z1 - 1 - z);
  return Math.min(11, 1 + e);
};

export function isMineCell(x, y, z) {
  const m = MINE;
  if (x < m.x0 - m.ring || x >= m.x1 + m.ring || z < m.z0 - m.ring || z >= m.z1 + m.ring) return false;
  if (y < m.bottom || y > GROUND - 1) return false;
  const inPit = x >= m.x0 && x < m.x1 && z >= m.z0 && z < m.z1;
  return inPit ? y <= GROUND - mineDepth(x, z) : true;
}

// What grows in a mine wall: mostly stone and ore you have unlocked.
export function mineRoll(r, unlocked, y) {
  const deep = y < 14 ? 2 : 1;
  if (r() < 0.006 * deep) return B.MONEY_ORE;
  if (r() < 0.42) return B.STONE;
  let total = 0;
  for (let i = 0; i < unlocked; i++) total += i + 1;
  let pick = r() * total;
  for (let i = 0; i < unlocked; i++) {
    pick -= i + 1;
    if (pick <= 0) return ORES[i].id;
  }
  return ORES[unlocked - 1].id;
}

function box(world, x0, y0, z0, x1, y1, z1, id, region) {
  for (let y = y0; y <= y1; y++) for (let z = z0; z <= z1; z++) for (let x = x0; x <= x1; x++) {
    if (!world.inside(x, y, z)) continue;
    const i = world.idx(x, y, z);
    world.data[i] = id;
    if (region !== undefined) world.region[i] = region;
  }
}

// Build the town once, right after the land is made.
export function buildTown(world, r) {
  const m = MINE;
  // Mine pit with steps down, walls full of copper.
  for (let z = m.z0 - m.ring; z < m.z1 + m.ring; z++) for (let x = m.x0 - m.ring; x < m.x1 + m.ring; x++) {
    for (let y = m.bottom; y <= GROUND + 6; y++) {
      const i = world.idx(x, y, z);
      if (isMineCell(x, y, z)) {
        world.data[i] = mineRoll(r, 1, y);
        world.region[i] = R.MINE;
        world.mineCells.push(i);
      } else if (y >= GROUND && x >= m.x0 && x < m.x1 && z >= m.z0 && z < m.z1) world.data[i] = 0;
      else if (y < GROUND && x >= m.x0 && x < m.x1 && z >= m.z0 && z < m.z1) world.data[i] = 0;
    }
  }
  // Paths and the spawn plaza.
  const path = (x0, z0, x1, z1, id = B.PATH) => box(world, x0, GROUND, z0, x1, GROUND, z1, id);
  path(61, 59, 67, 65, B.COBBLE);
  path(63, 52, 65, 58);
  path(49, 58, 60, 59);
  path(68, 59, 79, 60);
  path(46, 66, 83, 67);
  path(46, 68, 48, 69);
  path(81, 68, 83, 69);
  path(63, 68, 65, 71);

  // The shop: a wooden house with a money counter.
  const s = SHOP, sx1 = s.x0 + s.w - 1, sz1 = s.z0 + s.d - 1;
  box(world, s.x0, GROUND, s.z0, sx1, GROUND + 7, sz1, 0, R.SHOP);
  box(world, s.x0, GROUND, s.z0, sx1, GROUND, sz1, B.PLANKS);
  for (let y = GROUND + 1; y <= GROUND + 4; y++) for (let z = s.z0; z <= sz1; z++) for (let x = s.x0; x <= sx1; x++) {
    const edgeX = x === s.x0 || x === sx1, edgeZ = z === s.z0 || z === sz1;
    if (!edgeX && !edgeZ) continue;
    const corner = edgeX && edgeZ;
    const win = y === GROUND + 2 && !corner && ((edgeX ? z - s.z0 : x - s.x0) % 3 !== 1);
    world.data[world.idx(x, y, z)] = corner ? B.LOG : win ? B.GLASS : B.PLANKS;
  }
  const doorZ = s.z0 + (s.d >> 1);
  box(world, s.x0, GROUND + 1, doorZ - 1, s.x0, GROUND + 2, doorZ, 0);
  box(world, s.x0 - 1, GROUND + 5, s.z0 - 1, sx1 + 1, GROUND + 5, sz1 + 1, B.BRICK, R.SHOP);
  box(world, s.x0 + 1, GROUND + 6, s.z0 + 1, sx1 - 1, GROUND + 6, sz1 - 1, B.BRICK, R.SHOP);
  box(world, s.x0 + 3, GROUND + 7, doorZ - 1, s.x0 + 4, GROUND + 7, doorZ, B.MONEY_BLOCK, R.SHOP);
  box(world, sx1 - 2, GROUND + 1, s.z0 + 2, sx1 - 2, GROUND + 1, sz1 - 2, B.MONEY_BLOCK);
  box(world, sx1 - 1, GROUND + 1, s.z0 + 3, sx1 - 1, GROUND + 2, s.z0 + 3, B.GOLD_BLOCK);
  box(world, sx1 - 1, GROUND + 1, sz1 - 3, sx1 - 1, GROUND + 2, sz1 - 3, B.GOLD_BLOCK);

  // Empty business plots.
  for (const p of PLOTS) {
    box(world, p.x0, GROUND, p.z0, p.x0 + p.w - 1, H - 1, p.z0 + p.d - 1, 0, p.region);
    buildBusiness(world, p, 0, false);
  }
}

export function buildCave(world, r) {
  const c = CAVE, room = c.room;
  const air = (x, y, z) => { if (world.inside(x, y, z) && world.data[world.idx(x, y, z)] !== B.BEDROCK) world.data[world.idx(x, y, z)] = 0; };
  const put = (x, y, z, id) => { if (world.inside(x, y, z)) world.data[world.idx(x, y, z)] = id; };
  // Big room.
  for (let y = room.y - 6; y <= room.y + 6; y++) for (let z = room.z - room.rz - 2; z <= room.z + room.rz + 2; z++) for (let x = room.x - room.rx - 2; x <= room.x + room.rx + 2; x++) {
    const n = (r() - 0.5) * 0.25;
    const d = ((x - room.x) / room.rx) ** 2 + ((y - room.y) / room.ry) ** 2 + ((z - room.z) / room.rz) ** 2;
    if (d < 1 + n && y > 1) air(x, y, z);
  }
  // Ore everywhere on the walls. Locked ones look like stone until you buy them.
  for (let y = room.y - 7; y <= room.y + 7; y++) for (let z = room.z - room.rz - 3; z <= room.z + room.rz + 3; z++) for (let x = room.x - room.rx - 3; x <= room.x + room.rx + 3; x++) {
    if (!world.inside(x, y, z) || world.data[world.idx(x, y, z)] !== B.STONE) continue;
    const k = r();
    if (k < 0.035) put(x, y, z, B.MONEY_ORE);
    else if (k < 0.3) put(x, y, z, ORES[Math.min(9, Math.floor(r() * r() * 10))].id);
  }
  // Stairs down from town, all the way to the cave floor (so you can always walk back up).
  const isAir = (x, y, z) => world.inside(x, y, z) && world.data[world.idx(x, y, z)] === 0;
  for (let k = 0; k < 40; k++) {
    const x = c.x - k, floor = GROUND - k;
    const zm = c.z0 + 1;
    // Is this step inside the big room? Then find the room's floor.
    let roomFloor = -1;
    if (k > 4 && isAir(x, floor + 4, zm)) {
      let y = floor + 4;
      while (y > 1 && isAir(x, y - 1, zm)) y--;
      roomFloor = y - 1;
    }
    for (let z = c.z0; z <= c.z1; z++) {
      put(x, floor, z, k < 4 ? B.COBBLE : B.STONE);
      for (let y = floor - 1; y > roomFloor && roomFloor >= 0; y--) put(x, y, z, B.STONE);
      for (let y = floor + 1; y <= floor + 3; y++) air(x, y, z);
    }
    if (k % 4 === 2) for (const z of [c.z0 - 1, c.z1 + 1]) if (!isAir(x, floor + 2, z)) put(x, floor + 2, z, B.LAMP);
    if (roomFloor >= 0 && floor <= roomFloor + 1) break;
  }
  // Border around the hole in town.
  for (let x = c.x - 3; x <= c.x + 1; x++) for (const z of [c.z0 - 1, c.z1 + 1]) put(x, GROUND, z, B.COBBLE);
  for (let z = c.z0 - 1; z <= c.z1 + 1; z++) put(c.x + 1, GROUND, z, B.COBBLE);
  // Lamps in the room.
  for (let a = 0; a < 10; a++) {
    const ang = (a / 10) * Math.PI * 2;
    let x = Math.round(room.x + Math.cos(ang) * room.rx), z = Math.round(room.z + Math.sin(ang) * room.rz), y = room.y;
    // Walk inward until we find the wall.
    for (let t = 0; t < 12 && world.inside(x, y, z) && world.data[world.idx(x, y, z)] !== 0; t++) {
      x -= Math.sign(x - room.x); z -= Math.sign(z - room.z);
    }
    x += Math.sign(x - room.x); z += Math.sign(z - room.z);
    put(x, y, z, B.LAMP);
  }
  // A lucky pile of Money Ore in the middle.
  const fy = (() => { let y = room.y; while (y > 1 && world.data[world.idx(room.x, y - 1, room.z)] === 0) y--; return y; })();
  for (const [dx, dz, dy] of [[0, 0, 0], [1, 0, 0], [0, 1, 0], [-1, 0, 0], [0, -1, 0], [0, 0, 1]]) put(room.x + dx, fy + dy, room.z + dz, B.MONEY_ORE);
}

// Build (or rebuild) a business at its level. Level 0 = empty plot for sale.
export function buildBusiness(world, p, level, live = true) {
  const x1 = p.x0 + p.w - 1, z1 = p.z0 + p.d - 1;
  const put = (x, y, z, id) => {
    if (y >= H) return;
    if (live) world.set(x, y, z, id, false);
    else world.data[world.idx(x, y, z)] = id;
  };
  // Clear it.
  for (let y = GROUND + 1; y < H; y++) for (let z = p.z0; z <= z1; z++) for (let x = p.x0; x <= x1; x++)
    if (world.data[world.idx(x, y, z)]) put(x, y, z, 0);
  for (let z = p.z0; z <= z1; z++) for (let x = p.x0; x <= x1; x++) {
    const edge = x === p.x0 || x === x1 || z === p.z0 || z === z1;
    put(x, GROUND, z, level === 0 ? (edge ? p.ring : B.GRASS) : B.PLANKS);
  }
  if (level === 0) return;

  // Floors: 3 blocks each. More levels = taller building!
  const midX = p.x0 + (p.w >> 1);
  for (let f = 0; f < level; f++) {
    const y0 = GROUND + 1 + f * 3;
    for (let z = p.z0; z <= z1; z++) for (let x = p.x0; x <= x1; x++) {
      const ex = x === p.x0 || x === x1, ez = z === p.z0 || z === z1;
      const edge = ex || ez, corner = ex && ez;
      if (edge) {
        const along = ex ? z - p.z0 : x - p.x0;
        put(x, y0, z, corner ? p.trim : p.wall);
        put(x, y0 + 1, z, corner ? p.trim : along % 3 === 1 ? p.wall : p.key === 'factory' ? B.WINDOW : B.GLASS);
        put(x, y0 + 2, z, p.trim);
      } else put(x, y0 + 2, z, B.PLANKS);
    }
  }
  // Front door.
  const doorW = p.key === 'factory' ? 3 : 2;
  const dx0 = midX - (doorW >> 1);
  for (let x = dx0; x < dx0 + doorW; x++) {
    put(x, GROUND + 1, p.z0, 0);
    put(x, GROUND + 2, p.z0, 0);
  }
  // Something inside: a counter.
  const inside = p.key === 'lemon' ? B.LEMON : p.key === 'pizza' ? B.PIZZA : B.MONEY_BLOCK;
  for (let x = p.x0 + 2; x <= x1 - 2; x++) put(x, GROUND + 1, z1 - 2, inside);

  // Roof decorations.
  const roof = GROUND + 1 + level * 3;
  if (p.key === 'lemon') {
    for (let z = p.z0; z <= z1; z++) for (let x = p.x0; x <= x1; x++) {
      const edge = x === p.x0 || x === x1 || z === p.z0 || z === z1;
      if (edge) put(x, roof, z, (x + z) % 2 ? B.RED : B.WHITE);
    }
    const cx = midX - 1, cz = p.z0 + (p.d >> 1) - 1;
    for (let y = 0; y < 3; y++) for (let z = 0; z < 3; z++) for (let x = 0; x < 3; x++) {
      if ((y === 0 || y === 2) && x !== 1 && z !== 1) continue;
      put(cx + x, roof + y, cz + z, B.LEMON);
    }
    put(cx + 1, roof + 3, cz + 1, B.LEAVES);
  } else if (p.key === 'pizza') {
    // A giant pizza standing up on the roof.
    const cx = midX, cy = roof + 3, zz = p.z0 + 1;
    for (let y = -3; y <= 3; y++) for (let x = -3; x <= 3; x++) {
      const d = x * x + y * y;
      if (d > 11) continue;
      put(cx + x, cy + y, zz, d > 7 ? B.ORANGE : B.PIZZA);
    }
  } else {
    // Money Factory: chimneys and a giant gold $ sign.
    for (const cx of [p.x0 + 1, x1 - 2]) {
      for (let y = roof; y < roof + 5; y++) for (let z = z1 - 2; z <= z1 - 1; z++) for (let x = cx; x <= cx + 1; x++) put(x, y, z, B.BRICK);
    }
    const DOLLAR = ['..#..', '.####', '#.#..', '.###.', '..#.#', '####.', '..#..'];
    DOLLAR.forEach((row, j) => [...row].forEach((ch, i) => {
      if (ch === '#') put(midX - 2 + i, roof + 6 - j, p.z0 + 1, B.GOLD_BLOCK);
    }));
  }
}

// Chimney tops for the green money smoke.
export function chimneys(level) {
  const p = PLOTS[2];
  const roof = GROUND + 1 + level * 3 + 5;
  return [
    { x: p.x0 + 2, y: roof, z: p.z0 + p.d - 2 },
    { x: p.x0 + p.w - 2, y: roof, z: p.z0 + p.d - 2 },
  ];
}

