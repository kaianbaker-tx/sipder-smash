// Prices and money. Every upgrade costs DOUBLE the one before it.
import { B } from './blocks.js';

// Materials to mine. Copper is free. Each new one costs double the last.
// value = money you get for each block you mine.
// y = how deep the natural veins are, veins = how many are hidden in the world.
export const ORES = [
  { name: 'Copper', color: '#e8793a', value: 1, cost: 0, y: [4, 40], veins: 260 },
  { name: 'Iron', color: '#e2c3a4', value: 3, cost: 25, y: [4, 36], veins: 190 },
  { name: 'Gold', color: '#ffd21f', value: 6, cost: 50, y: [4, 30], veins: 150 },
  { name: 'Ruby', color: '#ff2d55', value: 12, cost: 100, y: [3, 26], veins: 120 },
  { name: 'Sapphire', color: '#2f7bff', value: 25, cost: 200, y: [3, 22], veins: 100 },
  { name: 'Amethyst', color: '#b44dff', value: 50, cost: 400, y: [3, 20], veins: 90 },
  { name: 'Lava Gem', color: '#ff7a00', value: 100, cost: 800, y: [2, 16], veins: 80 },
  { name: 'Ice Crystal', color: '#8ff4ff', value: 200, cost: 1600, y: [2, 14], veins: 70 },
  { name: 'Rainbow', color: '#ff66cc', value: 400, cost: 3200, y: [2, 12], veins: 60 },
  { name: 'Cosmic', color: '#6a5cff', value: 800, cost: 6400, y: [1, 10], veins: 50 },
].map((o, i) => ({ ...o, id: B.ORE0 + i, index: i }));

// Money Ore is where diamonds would be: deep down and rare. It is a jackpot.
export const MONEY_ORE = { y: [1, 11], veins: 70 };
export function moneyOreValue(oresUnlocked) {
  return Math.max(100, ORES[oresUnlocked - 1].value * 4);
}

// Pickaxes mine faster. Each one costs double the last.
export const PICKS = [
  { name: 'Wood Pickaxe', speed: 1, cost: 0, color: '#a0703f' },
  { name: 'Stone Pickaxe', speed: 1.6, cost: 40, color: '#9a9a9a' },
  { name: 'Iron Pickaxe', speed: 2.4, cost: 80, color: '#e8e1d6' },
  { name: 'Gold Pickaxe', speed: 3.5, cost: 160, color: '#ffd21f' },
  { name: 'Ruby Pickaxe', speed: 5, cost: 320, color: '#ff2d55' },
  { name: 'Sapphire Pickaxe', speed: 7, cost: 640, color: '#2f7bff' },
  { name: 'Money Pickaxe', speed: 10, cost: 1280, color: '#27c95a' },
  { name: 'Cosmic Pickaxe', speed: 15, cost: 2560, color: '#8a7dff' },
];

export const DOUBLE_MONEY_COST = 5000;

// Building blocks you can buy for building stuff.
export const PACKS = [
  { name: 'Planks', give: [[B.PLANKS, 16]], cost: 8, icon: B.PLANKS },
  { name: 'Cobblestone', give: [[B.COBBLE, 16]], cost: 8, icon: B.COBBLE },
  { name: 'Bricks', give: [[B.BRICK, 16]], cost: 15, icon: B.BRICK },
  { name: 'Glass', give: [[B.GLASS, 16]], cost: 15, icon: B.GLASS },
  { name: 'Color Wool', give: [[B.WHITE, 8], [B.RED, 8], [B.ORANGE, 8], [B.YELLOW, 8], [B.GREEN, 8], [B.BLUE, 8], [B.PINK, 8]], cost: 30, icon: B.RED },
  { name: 'House Kit', give: [[B.HOUSE_KIT, 1]], cost: 60, icon: B.HOUSE_KIT, about: 'Place it and a whole house pops up!' },
  { name: 'Lamps', give: [[B.LAMP, 8]], cost: 20, icon: B.LAMP },
  { name: 'Gold Blocks', give: [[B.GOLD_BLOCK, 8]], cost: 60, icon: B.GOLD_BLOCK },
  { name: 'Money Blocks', give: [[B.MONEY_BLOCK, 8]], cost: 150, icon: B.MONEY_BLOCK },
];

// Food fills your hunger bar.
export const FOODS = [
  { id: B.APPLE, name: 'Apple', cost: 3, count: 3 },
  { id: B.LEMONADE, name: 'Lemonade', cost: 6, count: 2 },
  { id: B.PIZZA_FOOD, name: 'Pizza', cost: 12, count: 2 },
];
export const HUNGER = { max: 10, drain: 45, starve: 4, heal: 3 };  // seconds per step

// Explosives. Light them by hitting them. Then RUN!
export const BOOMS = [
  { name: 'TNT', give: [[B.TNT, 3]], cost: 40, icon: B.TNT, about: '3 TNT. Makes a small hole.' },
  { name: 'MEGA TNT', give: [[B.MEGA_TNT, 1]], cost: 150, icon: B.MEGA_TNT, about: 'One HUGE boom!' },
];

export const MILESTONES = [
  [100, '$100! Nice start!'],
  [1000, '$1,000! You are rich!'],
  [10000, '$10,000! Super rich!'],
  [100000, '$100,000! Mega rich!'],
  [1000000, 'MILLIONAIRE!!!'],
  [10000000, 'TEN MILLION! Legend!'],
];

export function money(n) {
  n = Math.floor(n);
  if (n >= 1e9) return '$' + (n / 1e9).toFixed(2) + 'B';
  if (n >= 1e7) return '$' + (n / 1e6).toFixed(1) + 'M';
  return '$' + n.toLocaleString('en-US');
}
