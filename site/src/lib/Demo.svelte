<script>
  import { onMount } from 'svelte';
  import { t } from './i18n.js';
  import { subscribe, viewportP } from './motion.js';
  import Reveal from './Reveal.svelte';
  import SplitHeading from './SplitHeading.svelte';

  let stageEl, video;

  onMount(() => {
    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    const vio = new IntersectionObserver(es => es.forEach(e => {
      if (e.isIntersecting) { video.preload = 'auto'; video.play().catch(() => {}); }
      else video.pause();
    }), { threshold: 0.25 });
    vio.observe(video);
    let un = () => {};
    if (!reduced) un = subscribe(() => {
      const dp = viewportP(stageEl, 1.2);
      stageEl.style.transform = `scale(${(0.94 + dp * 0.06).toFixed(3)})`;
    });
    return () => { vio.disconnect(); un(); };
  });
</script>

<section class="demo" id="demo">
  <div class="wrap">
    <Reveal>
      <div class="sec-head">
        <SplitHeading key="demo.h" />
        <p>{$t('demo.p')}</p>
      </div>
    </Reveal>
    <Reveal delay={0.1}>
      <div class="demo-stage">
        <div bind:this={stageEl} class="stage-inner">
          <video bind:this={video} src="assets/demo-generate.mp4" poster="assets/app-shot-en.webp" muted loop playsinline preload="none"></video>
        </div>
      </div>
    </Reveal>
  </div>
</section>

<style>
  .demo { overflow: clip; }
  .demo-stage { width: min(880px, 92vw); margin: 52px auto 0; }
  .stage-inner { will-change: transform; }
  video {
    width: 100%; height: auto; border-radius: 18px;
    box-shadow:
      0 34px 80px -22px oklch(0.68 0.14 20 / 0.5),
      0 34px 120px -40px oklch(0.55 0.14 312 / 0.55),
      0 2px 10px oklch(0.42 0.05 300 / 0.12);
  }
</style>
