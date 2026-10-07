// Day and night, like Minecraft. Zombies come out when it gets dark.
import * as THREE from '../lib/three.min.js';
import { smoothstep, rng } from './noise.js';

export const CYCLE = 420;          // seconds for a whole day and night
const NIGHT = 0.3;                 // how bright the sky is at night

// t goes 0..1 through one day.
// 0.00-0.58 day, 0.58-0.66 sunset, 0.66-0.94 night, 0.94-1.00 sunrise
export function dayLevel(t) {
  if (t < 0.58) return 1;
  if (t < 0.66) return 1 - smoothstep(0.58, 0.66, t) * (1 - NIGHT);
  if (t < 0.94) return NIGHT;
  return NIGHT + smoothstep(0.94, 1, t) * (1 - NIGHT);
}
export const isNight = (t) => t > 0.63 && t < 0.97;

const DAY_FOG = new THREE.Color('#bfe6ff');
const NIGHT_FOG = new THREE.Color('#0c1232');
const SUNSET = new THREE.Color('#ff9a6a');

export class DayNight {
  constructor(scene, sky, clouds, water, blockMat) {
    this.uDay = { value: 1 };
    this.level = 1;
    this.sky = sky;
    this.clouds = clouds;
    this.water = water;
    this.fog = new THREE.Color();
    // Blocks: sky light follows the time of day, lamp light stays bright.
    const uDay = this.uDay;
    blockMat.onBeforeCompile = (sh) => {
      sh.uniforms.uDay = uDay;
      sh.vertexShader = sh.vertexShader
        .replace('#include <common>', '#include <common>\nattribute vec2 lit;\nuniform float uDay;\nvarying float vLight;')
        .replace('#include <begin_vertex>', '#include <begin_vertex>\nvLight = max(mix(min(0.55, uDay + 0.1), uDay, lit.x), lit.y);');
      sh.fragmentShader = sh.fragmentShader
        .replace('#include <common>', '#include <common>\nvarying float vLight;')
        .replace('#include <color_fragment>', '#include <color_fragment>\ndiffuseColor.rgb *= vLight;');
    };
    // Square sun and moon.
    const quad = (size, color) => {
      const m = new THREE.Mesh(new THREE.PlaneGeometry(size, size), new THREE.MeshBasicMaterial({ color, fog: false, depthWrite: false, transparent: true }));
      sky.add(m);
      return m;
    };
    this.sun = quad(46, 0xfff3a0);
    this.moon = quad(30, 0xe8ecff);
    // Stars.
    const r = rng(42), pts = [];
    for (let i = 0; i < 400; i++) {
      const a = r() * Math.PI * 2, h = 0.08 + r() * 0.92, rad = Math.sqrt(1 - h * h);
      pts.push(Math.cos(a) * rad * 380, h * 380, Math.sin(a) * rad * 380);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pts, 3));
    this.stars = new THREE.Points(g, new THREE.PointsMaterial({ color: 0xffffff, size: 2, sizeAttenuation: false, transparent: true, opacity: 0, fog: false, depthWrite: false }));
    sky.add(this.stars);
  }

  update(t) {
    const L = dayLevel(t);
    this.level = L;
    // Screens show dark colors brighter than the numbers, so blocks get a darker night.
    this.uDay.value = 0.12 + ((L - NIGHT) / (1 - NIGHT)) * 0.88;
    const night = 1 - (L - NIGHT) / (1 - NIGHT);           // 0 day .. 1 night
    const dusk = Math.max(0, 1 - Math.abs(t - 0.62) / 0.05) + Math.max(0, 1 - Math.abs(((t + 0.5) % 1) - 0.47) / 0.04);
    this.fog.copy(DAY_FOG).lerp(NIGHT_FOG, night).lerp(SUNSET, Math.min(0.6, dusk * 0.6));
    this.sky.material.color.setRGB(1, 1, 1).lerp(new THREE.Color(0.1, 0.13, 0.32), night).lerp(SUNSET, Math.min(0.5, dusk * 0.5));
    this.clouds.children[0].material.color.setScalar(Math.max(0.2, L * L));
    this.water.material.color.setScalar(Math.max(0.22, L * L));
    this.stars.material.opacity = night;
    // The sun crosses the sky during the day, the moon at night.
    const place = (m, a) => {
      m.position.set(Math.cos(a) * 300, Math.sin(a) * 300, -90);
      m.lookAt(0, 0, 0);
    };
    const dayT = ((t + 0.04) % 1) / 0.66;
    place(this.sun, Math.PI * Math.min(1.05, Math.max(-0.05, dayT)));
    this.sun.visible = dayT < 1.05;
    const nightT = (t - 0.6) / 0.38;
    place(this.moon, Math.PI * Math.min(1.05, Math.max(-0.05, nightT)));
    this.moon.visible = nightT > -0.05 && nightT < 1.05;
  }
}
