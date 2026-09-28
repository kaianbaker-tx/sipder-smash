// Every block in the world. Tiles are painted in atlas.js.

export const TILE_NAMES = [
  'grass_top', 'grass_side', 'dirt', 'stone', 'sand', 'log_side', 'log_top', 'leaves',
  'planks', 'bedrock', 'brick', 'glass', 'gold_block', 'white', 'yellow', 'red',
  'green', 'blue', 'metal', 'money_block', 'lemon', 'pizza', 'window', 'path',
  'cobble', 'orange', 'pink', 'money_ore', 'lamp',
  'ore_copper', 'ore_iron', 'ore_gold', 'ore_ruby', 'ore_sapphire', 'ore_amethyst',
  'ore_lava', 'ore_ice', 'ore_rainbow', 'ore_cosmic',
  'crack0', 'crack1', 'crack2', 'crack3', 'crack4',
];
export const T = {};
TILE_NAMES.forEach((n, i) => (T[n] = i));

export const B = {
  AIR: 0, GRASS: 1, DIRT: 2, STONE: 3, SAND: 4, LOG: 5, LEAVES: 6, PLANKS: 7,
  BEDROCK: 8, BRICK: 9, GLASS: 10, GOLD_BLOCK: 11, WHITE: 12, YELLOW: 13, RED: 14,
  GREEN: 15, BLUE: 16, METAL: 17, MONEY_BLOCK: 18, LEMON: 19, PIZZA: 20, WINDOW: 21,
  PATH: 22, COBBLE: 23, ORANGE: 24, PINK: 25, LAMP: 26,
  // Ores 30..39 (see ORES in data.js), then the money ore that replaces diamonds.
  ORE0: 30, MONEY_ORE: 40,
};

// id -> { name, tiles: [top, bottom, side], hard (seconds with a wood pickaxe), drop, see (see-through) }
export const BLOCKS = [];
function def(id, name, tiles, hard, extra = {}) {
  const t = Array.isArray(tiles) ? tiles : [tiles, tiles, tiles];
  BLOCKS[id] = { id, name, tiles: t.map((n) => T[n]), hard, drop: id, see: false, ...extra };
}

def(B.GRASS, 'Grass', ['grass_top', 'dirt', 'grass_side'], 0.4, { drop: B.DIRT });
def(B.DIRT, 'Dirt', 'dirt', 0.35);
def(B.STONE, 'Stone', 'stone', 1.0);
def(B.SAND, 'Sand', 'sand', 0.35);
def(B.LOG, 'Wood', ['log_top', 'log_top', 'log_side'], 0.8);
def(B.LEAVES, 'Leaves', 'leaves', 0.15, { see: true });
def(B.PLANKS, 'Planks', 'planks', 0.6);
def(B.BEDROCK, 'Bedrock', 'bedrock', Infinity, { drop: 0 });
def(B.BRICK, 'Bricks', 'brick', 1.0);
def(B.GLASS, 'Glass', 'glass', 0.2, { see: true });
def(B.GOLD_BLOCK, 'Gold Block', 'gold_block', 1.2);
def(B.WHITE, 'White Wool', 'white', 0.3);
def(B.YELLOW, 'Yellow Wool', 'yellow', 0.3);
def(B.RED, 'Red Wool', 'red', 0.3);
def(B.GREEN, 'Green Wool', 'green', 0.3);
def(B.BLUE, 'Blue Wool', 'blue', 0.3);
def(B.METAL, 'Metal', 'metal', 1.5);
def(B.MONEY_BLOCK, 'Money Block', 'money_block', 1.0);
def(B.LEMON, 'Lemon Block', 'lemon', 0.3);
def(B.PIZZA, 'Pizza Block', 'pizza', 0.3);
def(B.WINDOW, 'Window', 'window', 0.3);
def(B.PATH, 'Path', 'path', 0.35, { drop: B.DIRT });
def(B.COBBLE, 'Cobblestone', 'cobble', 1.0);
def(B.ORANGE, 'Orange Wool', 'orange', 0.3);
def(B.PINK, 'Pink Wool', 'pink', 0.3);
def(B.LAMP, 'Lamp', 'lamp', 0.3, { glow: true });

const ORE_TILES = ['ore_copper', 'ore_iron', 'ore_gold', 'ore_ruby', 'ore_sapphire',
  'ore_amethyst', 'ore_lava', 'ore_ice', 'ore_rainbow', 'ore_cosmic'];
const ORE_NAMES = ['Copper Ore', 'Iron Ore', 'Gold Ore', 'Ruby Ore', 'Sapphire Ore',
  'Amethyst Ore', 'Lava Gem Ore', 'Ice Crystal Ore', 'Rainbow Ore', 'Cosmic Ore'];
ORE_TILES.forEach((t, i) => def(B.ORE0 + i, ORE_NAMES[i], t, 1.1 + i * 0.28, { ore: i }));
def(B.MONEY_ORE, 'Money Ore', 'money_ore', 3.0, { money: true });

export const isOre = (id) => id >= B.ORE0 && id < B.ORE0 + 10;

// Fast lookups for meshing and physics.
export const SOLID = new Uint8Array(256);   // you bump into it
export const OPAQUE = new Uint8Array(256);  // hides the face next to it
export const SHADOW = new Uint8Array(256);  // blocks the sky
export const GLOW = new Uint8Array(256);    // always bright
for (const b of BLOCKS) {
  if (!b) continue;
  SOLID[b.id] = 1;
  OPAQUE[b.id] = b.see ? 0 : 1;
  SHADOW[b.id] = b.id === B.GLASS ? 0 : 1;
  GLOW[b.id] = b.glow ? 1 : 0;
}

// Blocks you can place, in hotbar order.
export const PLACEABLE = [B.DIRT, B.STONE, B.SAND, B.LOG, B.LEAVES, B.PLANKS, B.COBBLE,
  B.BRICK, B.GLASS, B.WHITE, B.RED, B.ORANGE, B.YELLOW, B.GREEN, B.BLUE, B.PINK,
  B.GOLD_BLOCK, B.MONEY_BLOCK, B.LAMP];
