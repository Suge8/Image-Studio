/* Singleton lerped-scroll rAF loop. Components subscribe; loop runs while anyone is subscribed. */
const subs = new Set();
let running = false;
let target = 0, cur = 0, vel = 0;
let mx = -600, my = -600;

function onScroll() { target = window.scrollY; }
function onMove(e) { mx = e.clientX; my = e.clientY; }

function frame() {
  const prev = cur;
  cur += (target - cur) * 0.085;
  vel += (cur - prev - vel) * 0.12;
  subs.forEach(fn => fn({ scrollY: cur, vel, mx, my }));
  if (subs.size) requestAnimationFrame(frame);
  else running = false;
}

export function subscribe(fn) {
  subs.add(fn);
  if (!running) {
    running = true;
    target = window.scrollY; cur = target;
    addEventListener('scroll', onScroll, { passive: true });
    addEventListener('pointermove', onMove, { passive: true });
    requestAnimationFrame(frame);
  }
  return () => {
    subs.delete(fn);
    if (!subs.size) {
      removeEventListener('scroll', onScroll);
      removeEventListener('pointermove', onMove);
    }
  };
}

export const clamp01 = v => Math.min(1, Math.max(0, v));
export const viewportP = (el, bias = 1) => {
  const r = el.getBoundingClientRect();
  return clamp01((innerHeight - r.top) / (innerHeight * bias));
};
