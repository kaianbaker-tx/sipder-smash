// All the sounds are made with code, no sound files needed.
let ctx = null, master = null, musicGain = null, noiseBuf = null;
let musicOn = true, nextNote = 0, beat = 0;

export function startAudio() {
  if (ctx) { if (ctx.state === 'suspended') ctx.resume(); return; }
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return;
  ctx = new AC();
  master = ctx.createGain();
  master.gain.value = 0.55;
  master.connect(ctx.destination);
  musicGain = ctx.createGain();
  musicGain.gain.value = musicOn ? 0.09 : 0;
  musicGain.connect(master);
  noiseBuf = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
  const d = noiseBuf.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  nextNote = ctx.currentTime + 0.2;
  setInterval(music, 100);
}

function tone(freq, t, len, type = 'square', vol = 0.2, slideTo = 0, out = master) {
  if (!ctx) return;
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + len);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.008);
  g.gain.exponentialRampToValueAtTime(0.0001, t + len);
  o.connect(g).connect(out);
  o.start(t);
  o.stop(t + len + 0.02);
}

function noise(t, len, freq, q = 1, vol = 0.3, type = 'bandpass') {
  if (!ctx) return;
  const s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
  s.buffer = noiseBuf;
  f.type = type;
  f.frequency.value = freq;
  f.Q.value = q;
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + len);
  s.connect(f).connect(g).connect(master);
  s.start(t, Math.random() * 0.5);
  s.stop(t + len + 0.02);
}

const now = () => (ctx ? ctx.currentTime : 0);

// hard = how hard the block is (stone sounds higher than dirt)
export function dig(hard) {
  const t = now();
  noise(t, 0.07, hard > 0.9 ? 2400 : 900, 1.2, 0.25);
}
export function breakBlock(hard) {
  const t = now();
  noise(t, 0.16, hard > 0.9 ? 1800 : 700, 0.8, 0.4);
  tone(hard > 0.9 ? 180 : 110, t, 0.1, 'triangle', 0.25, 60);
}
export function place() {
  const t = now();
  noise(t, 0.08, 500, 1, 0.35);
  tone(140, t, 0.07, 'triangle', 0.25, 90);
}
export function coin(big = false) {
  const t = now();
  tone(988, t, 0.08, 'square', 0.12);
  tone(1319, t + 0.07, big ? 0.35 : 0.22, 'square', 0.12);
  if (big) tone(1976, t + 0.14, 0.3, 'square', 0.08);
}
export function jackpot() {
  const t = now();
  noise(t, 0.12, 5000, 2, 0.2);
  [1047, 1319, 1568, 2093, 2637].forEach((f, i) => tone(f, t + 0.06 * i, 0.4, 'square', 0.1));
  tone(2093, t + 0.35, 0.8, 'sine', 0.2);
}
export function buy() {
  const t = now();
  [523, 659, 784, 1047].forEach((f, i) => tone(f, t + i * 0.07, 0.18, 'square', 0.12));
}
export function levelUp() {
  const t = now();
  [392, 523, 659, 784, 659, 784, 1047].forEach((f, i) => tone(f, t + i * 0.09, 0.2, 'square', 0.12));
  tone(1047, t + 0.63, 0.6, 'triangle', 0.2);
}
export function nope() {
  const t = now();
  tone(160, t, 0.18, 'sawtooth', 0.12, 110);
}
export function step() {
  const t = now();
  noise(t, 0.05, 300 + Math.random() * 200, 0.7, 0.12);
}
export function splash() {
  const t = now();
  noise(t, 0.4, 1200, 0.5, 0.35, 'lowpass');
}
export function click() {
  tone(880, now(), 0.04, 'square', 0.06);
}

// A calm little tune that loops.
const SCALE = [262, 294, 330, 392, 440, 523, 587, 659, 784];
const SONG = [0, 4, 7, 4, 2, 5, 7, 5, 3, 5, 8, 5, 1, 4, 6, 4];
const BASS = [131, 131, 110, 110, 87, 87, 98, 98];
function music() {
  if (!ctx) return;
  while (nextNote < ctx.currentTime + 0.3) {
    const i = beat % SONG.length;
    if (beat % 32 < 28 || i % 2 === 0) tone(SCALE[SONG[i]], nextNote, 0.35, 'triangle', 0.5, 0, musicGain);
    if (beat % 4 === 0) tone(BASS[((beat / 4) | 0) % BASS.length], nextNote, 0.9, 'sine', 0.8, 0, musicGain);
    nextNote += 0.3;
    beat++;
  }
}

export function setMusic(on) {
  musicOn = on;
  if (musicGain) musicGain.gain.value = on ? 0.09 : 0;
}
export const isMusicOn = () => musicOn;
