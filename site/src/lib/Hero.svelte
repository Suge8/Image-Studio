<script>
  import { onMount } from 'svelte';
  import { t, lang } from './i18n.js';
  import { subscribe, viewportP } from './motion.js';
  import Icon from './Icon.svelte';

  let stage, glow, h1a, h1b;
  const reduced = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;
  const fine = typeof matchMedia !== 'undefined' && matchMedia('(pointer: fine)').matches;

  onMount(() => {
    if (!reduced) {
      [h1a, h1b].forEach((s, i) => {
        s.style.transform = 'translateY(110%)';
        s.style.transition = `transform 1s cubic-bezier(0.22,1,0.36,1) ${0.08 + i * 0.1}s`;
        requestAnimationFrame(() => requestAnimationFrame(() => s.style.transform = 'translateY(0)'));
      });
    }
    if (reduced) return;
    let gcx = -600, gcy = -600;
    const un = subscribe(({ scrollY, mx, my }) => {
      stage.style.setProperty('--tilt', `${(9 - viewportP(stage, 1) * 9).toFixed(2)}deg`);
      gcx += (mx - gcx) * 0.07; gcy += (my - gcy) * 0.07;
      glow.style.left = gcx + 'px'; glow.style.top = gcy + 'px';
    });
    return un;
  });

  /* 磁吸按钮 */
  function magnetic(node) {
    if (!fine || reduced) return;
    const move = e => {
      const r = node.getBoundingClientRect();
      const dx = (e.clientX - r.left - r.width / 2) / (r.width / 2);
      const dy = (e.clientY - r.top - r.height / 2) / (r.height / 2);
      node.style.transform = `translate(${(dx * 7).toFixed(1)}px, ${(dy * 5).toFixed(1)}px)`;
    };
    const leave = () => node.style.transform = '';
    node.addEventListener('pointermove', move);
    node.addEventListener('pointerleave', leave);
    return { destroy() { node.removeEventListener('pointermove', move); node.removeEventListener('pointerleave', leave); } };
  }
</script>

<header class="hero" id="top">
  <div class="glow" bind:this={glow}></div>

  <div class="hero-inner">
    <h1>
      <span class="line"><span bind:this={h1a}>{$t('h1.a')}</span></span>
      <span class="line"><span bind:this={h1b}>{$t('h1.b')}</span></span>
    </h1>
    <p class="sub">{$t('hero.sub')}</p>
    <div class="ctas">
      <a class="btn" use:magnetic href="https://github.com/Suge8/Image-Studio/releases/latest/download/Image-Studio-macOS.zip">
        <Icon name="download" size={16} />
        <span>{$t('cta.dl')}</span>
      </a>
      <a class="btn ghost" use:magnetic href="https://github.com/Suge8/Image-Studio">
        <span>{$t('cta.gh')}</span>
      </a>
    </div>
    <p class="meta">{$t('hero.meta')}</p>
  </div>

  <div class="shot-stage" bind:this={stage}>
    <div class="shot" class:show-zh={$lang === 'zh'}>
      <img class="en" src="assets/app-shot-en.webp" alt="Image Studio app window with a generated batch" fetchpriority="high" width="1280" height="800">
      <img class="zh" src="assets/app-shot-zh.webp" alt="Image Studio 应用窗口与一批生成结果" loading="lazy" width="1280" height="800">
    </div>
  </div>

  <img class="mascot m-waving" src="assets/mascot-waving.webp" alt="" data-px="0.12" width="480" height="480">
  <img class="mascot m-sleeping" src="assets/mascot-sleeping.webp" alt="" data-px="-0.08" width="480" height="480">
</header>

<style>
  .hero {
    position: relative; min-height: 100svh; overflow: clip;
    display: flex; flex-direction: column; align-items: center;
    padding-top: clamp(120px, 16vh, 168px);
  }
  .glow {
    position: absolute; width: 560px; height: 560px; border-radius: 50%;
    background: radial-gradient(circle, oklch(0.74 0.13 42 / 0.16), transparent 65%);
    pointer-events: none; left: 0; top: 0; transform: translate3d(-50%, -50%, 0);
  }
  .hero-inner { position: relative; text-align: center; z-index: 1; }
  h1 { font-size: clamp(2.35rem, 7.2vw, 5.6rem); font-weight: 700; }
  h1 .line { display: block; overflow: hidden; }
  h1 .line > span { display: inline-block; }
  .sub {
    max-width: 58ch; margin: 26px auto 0; font-size: clamp(1rem, 1.5vw, 1.13rem);
    color: var(--muted); text-wrap: pretty;
  }
  .ctas { display: flex; gap: 14px; justify-content: center; margin-top: 36px; flex-wrap: wrap; }
  .hero .meta { margin-top: 18px; font-size: 13px; color: var(--muted); }
  .shot-stage { position: relative; width: min(980px, 92vw); margin: clamp(44px, 7vh, 72px) auto 0; perspective: 1400px; z-index: 1; }
  .shot {
    position: relative; border-radius: 22px; overflow: hidden;
    box-shadow: 0 40px 90px -18px oklch(0.42 0.06 300 / 0.4), 0 4px 18px oklch(0.42 0.06 300 / 0.14);
    transform: rotateX(var(--tilt, 9deg));
    transform-origin: 50% 100%;
    will-change: transform;
  }
  .shot img { width: 100%; height: auto; transition: opacity .4s; }
  .shot img.zh { position: absolute; inset: 0; opacity: 0; }
  .shot.show-zh img.zh { opacity: 1; }
  .mascot { position: absolute; pointer-events: none; z-index: 2; filter: drop-shadow(0 16px 22px oklch(0.4 0.05 300 / 0.25)); }
  .m-waving { width: clamp(120px, 15vw, 190px); right: max(2vw, calc(50% - 590px)); bottom: 6vh; }
  .m-sleeping { width: clamp(90px, 11vw, 140px); left: max(2vw, calc(50% - 580px)); top: 20vh; opacity: .95; }
  @media (max-width: 860px) { .m-sleeping { display: none; } }
  @media (pointer: coarse) { .glow { display: none; } }
</style>
