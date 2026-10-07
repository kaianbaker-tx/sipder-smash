// Phone and tablet controls: a stick to walk, drag to look, buttons to mine, build and jump.
const $ = (id) => document.getElementById(id);

export function setupTouch(input, look, onBuild) {
  document.body.classList.add('touch');
  $('touch').classList.remove('hidden');

  // Walk stick.
  const stick = $('stick'), knob = $('stick-knob');
  let stickId = null;
  const moveStick = (e) => {
    const r = stick.getBoundingClientRect();
    let dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
    const max = r.width / 2 - 10, len = Math.hypot(dx, dy);
    if (len > max) { dx *= max / len; dy *= max / len; }
    knob.style.transform = `translate(${dx}px, ${dy}px)`;
    input.right = dx / max;
    input.forward = -dy / max;
    input.sprint = len > max * 0.98;
  };
  stick.addEventListener('pointerdown', (e) => { stickId = e.pointerId; stick.setPointerCapture(e.pointerId); moveStick(e); e.preventDefault(); });
  stick.addEventListener('pointermove', (e) => { if (e.pointerId === stickId) moveStick(e); });
  const endStick = (e) => {
    if (e.pointerId !== stickId) return;
    stickId = null;
    knob.style.transform = '';
    input.right = input.forward = 0;
    input.sprint = false;
  };
  stick.addEventListener('pointerup', endStick);
  stick.addEventListener('pointercancel', endStick);

  // Drag anywhere else to look around.
  const canvas = $('game');
  let lookId = null, lx = 0, ly = 0;
  canvas.addEventListener('pointerdown', (e) => {
    if (e.pointerType === 'mouse' || lookId !== null) return;
    lookId = e.pointerId; lx = e.clientX; ly = e.clientY;
  });
  window.addEventListener('pointermove', (e) => {
    if (e.pointerId !== lookId) return;
    look(e.clientX - lx, e.clientY - ly, 0.0062);
    lx = e.clientX; ly = e.clientY;
  });
  const endLook = (e) => { if (e.pointerId === lookId) lookId = null; };
  window.addEventListener('pointerup', endLook);
  window.addEventListener('pointercancel', endLook);

  // Buttons.
  const hold = (id, on, off) => {
    const b = $(id);
    b.addEventListener('pointerdown', (e) => { e.preventDefault(); b.classList.add('down'); on(); });
    const up = () => { b.classList.remove('down'); off(); };
    b.addEventListener('pointerup', up);
    b.addEventListener('pointercancel', up);
    b.addEventListener('pointerleave', up);
  };
  hold('t-mine', () => (input.mine = true), () => (input.mine = false));
  hold('t-jump', () => (input.jump = true), () => (input.jump = false));
  hold('t-build', () => { input.build = true; onBuild(); }, () => (input.build = false));
}
