<script>
  import { onMount } from 'svelte';
  import { t } from './i18n.js';
  import { subscribe } from './motion.js';
  import Reveal from './Reveal.svelte';
  import SplitHeading from './SplitHeading.svelte';
  import Icon from './Icon.svelte';

  let studio, hero, video;
  const fine = typeof matchMedia !== 'undefined' && matchMedia('(pointer: fine)').matches;
  const reduced = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

  onMount(() => {
    /* showreel 接近视口才加载播放 */
    const vio = new IntersectionObserver(es => es.forEach(e => {
      if (e.isIntersecting) { video.preload = 'auto'; video.play().catch(() => {}); }
      else video.pause();
    }), { rootMargin: '400px' });
    vio.observe(video);

    let un = () => {};
    if (!reduced) un = subscribe(({ scrollY }) => {
      studio.style.transform = `translate3d(0, ${(scrollY * 0.06).toFixed(1)}px, 0)`;
      hero.style.transform = `translate3d(0, ${(scrollY * -0.05).toFixed(1)}px, 0)`;
    });
    return () => { vio.disconnect(); un(); };
  });

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

<section class="download" id="download">
  <video bind:this={video} class="reel" src="assets/showreel.mp4" muted loop playsinline preload="none" aria-hidden="true"></video>
  <div class="veil"></div>
  <img bind:this={studio} class="mascot m-studio" src="assets/mascot-studio.webp" alt="" width="640" height="640">
  <img bind:this={hero} class="mascot m-hero" src="assets/mascot-hero.webp" alt="" width="480" height="480">
  <div class="wrap">
    <Reveal>
      <div class="dl-head"><SplitHeading key="dl.h" /></div>
    </Reveal>
    <Reveal delay={0.1}>
      <div class="cta-wrap">
        <a class="btn dl-btn" use:magnetic href="https://github.com/Suge8/Image-Studio/releases/latest/download/Image-Studio-macOS.zip">
          <Icon name="download" size={17} />
          <span>{$t('dl.btn')}</span>
        </a>
        <p class="note">{$t('dl.note')}</p>
      </div>
    </Reveal>
  </div>
</section>

<style>
  .download { overflow: clip; text-align: center; color: white; position: relative; }
  .reel {
    position: absolute; inset: 0; width: 100%; height: 100%;
    object-fit: cover; z-index: 0;
  }
  .veil {
    position: absolute; inset: 0; z-index: 1;
    background: linear-gradient(160deg,
      oklch(0.42 0.12 42 / 0.82),
      oklch(0.34 0.12 312 / 0.85) 52%,
      oklch(0.36 0.12 258 / 0.85));
  }
  .wrap { position: relative; z-index: 2; }
  .dl-head :global(h2) { font-size: clamp(2rem, 4.4vw, 3.2rem); }
  .dl-btn {
    margin-top: 34px; background: white; color: var(--ink);
    box-shadow: 0 10px 30px oklch(0.2 0.03 290 / 0.35);
    font-size: 16.5px; padding: 15px 32px;
  }
  .note { margin-top: 18px; font-size: 13.5px; color: oklch(1 0 0 / 0.75); }
  .mascot { position: absolute; pointer-events: none; z-index: 2; filter: drop-shadow(0 16px 22px oklch(0.2 0.05 300 / 0.4)); }
  .m-studio { width: clamp(110px, 13vw, 170px); left: max(4vw, calc(50% - 560px)); bottom: -8px; }
  .m-hero { width: clamp(100px, 12vw, 150px); right: max(4vw, calc(50% - 560px)); top: 20px; }
  @media (max-width: 860px) { .m-studio, .m-hero { opacity: 0.35; } }
</style>
