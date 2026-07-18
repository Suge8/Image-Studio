<script>
  import { onMount } from 'svelte';
  import { t } from './i18n.js';
  import { subscribe, clamp01 } from './motion.js';
  import Reveal from './Reveal.svelte';
  import SplitHeading from './SplitHeading.svelte';

  let tl, fill;
  let active = [false, false, false];
  const steps = [
    { num: '01', h: 's1.h', p: null, code: 'git clone github.com/Suge8/Image-Studio\ncd Image-Studio && make install' },
    { num: '02', h: 's2.h', p: 's2.p', code: null },
    { num: '03', h: 's3.h', p: 's3.p', code: null },
  ];

  onMount(() => {
    const stepEls = [...tl.querySelectorAll('.step')];
    const io = new IntersectionObserver(es => es.forEach(e => {
      const idx = stepEls.indexOf(e.target);
      if (idx >= 0) { active[idx] = e.isIntersecting; active = [...active]; }
    }), { rootMargin: '-38% 0px -38% 0px' });
    stepEls.forEach(s => io.observe(s));
    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    let un = () => {};
    if (!reduced) un = subscribe(() => {
      const r = tl.getBoundingClientRect();
      fill.style.setProperty('--p', clamp01((innerHeight * 0.62 - r.top) / r.height).toFixed(3));
    });
    return () => { io.disconnect(); un(); };
  });
</script>

<section class="steps-wrap" id="steps">
  <div class="wrap">
    <Reveal>
      <div class="sec-head">
        <SplitHeading key="steps.h" />
      </div>
    </Reveal>
    <div class="tl" bind:this={tl}>
      <div class="tl-rail"></div>
      <div class="tl-fill" bind:this={fill}></div>
      {#each steps as s, i}
        <div class="step" class:on={active[i]}>
          <span class="num">{s.num}</span>
          <div>
            <h3>{$t(s.h)}</h3>
            {#if s.code}<code>{s.code}</code>{/if}
            {#if s.p}<p>{$t(s.p)}</p>{/if}
          </div>
        </div>
      {/each}
    </div>
  </div>
</section>

<style>
  .tl { position: relative; margin-top: clamp(48px, 7vw, 72px); }
  .tl-rail, .tl-fill {
    position: absolute; top: 10px; bottom: 10px; left: calc(clamp(3.2rem, 6.4vw, 5.2rem) / 2);
    width: 3px; border-radius: 2px;
  }
  .tl-rail { background: oklch(0.92 0.006 290); }
  .tl-fill { background: var(--grad); transform-origin: 50% 0; transform: scaleY(var(--p, 0)); }
  .step {
    position: relative;
    display: grid; grid-template-columns: clamp(3.2rem, 6.4vw, 5.2rem) 1fr;
    gap: clamp(24px, 4.5vw, 56px); align-items: start;
    padding-block: clamp(30px, 4.5vw, 46px);
  }
  .num {
    font: 700 clamp(3.2rem, 6.4vw, 5.2rem) / 1 var(--font-display);
    text-align: center; color: transparent;
    -webkit-text-stroke: 2px oklch(0.62 0.05 290 / 0.4);
    transition: color 0.6s var(--ease-out), -webkit-text-stroke-color 0.6s;
    position: relative; z-index: 1;
  }
  .step.on .num { color: var(--coral); -webkit-text-stroke-color: var(--coral); }
  h3 { font-size: clamp(1.35rem, 2.4vw, 1.7rem); }
  p { margin-top: 10px; color: var(--muted); max-width: 52ch; text-wrap: pretty; }
  code {
    display: inline-block; margin-top: 16px; padding: 14px 18px; border-radius: 14px;
    background: oklch(0.26 0.015 290); color: oklch(0.93 0.02 100);
    font: 13px/1.7 ui-monospace, "SF Mono", Menlo, monospace; white-space: pre;
    box-shadow: 0 14px 34px -14px oklch(0.3 0.04 290 / 0.5);
  }
  @media (max-width: 860px) { .tl-rail, .tl-fill { display: none; } }
</style>
