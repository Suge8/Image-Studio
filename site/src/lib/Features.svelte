<script>
  import { onMount } from 'svelte';
  import { t } from './i18n.js';
  import { subscribe, viewportP } from './motion.js';
  import Reveal from './Reveal.svelte';
  import Icon from './Icon.svelte';

  const feats = [
    { icon: 'key-round', hue: 'coral', mascot: 'painting', h: 'f1.h', p: 'f1.p' },
    { icon: 'layers', hue: 'violet', mascot: 'hero', h: 'f2.h', p: 'f2.p' },
    { icon: 'folder-open', hue: 'sky', mascot: 'frame', h: 'f3.h', p: 'f3.p' },
    { icon: 'shield-check', hue: 'rose', mascot: 'studio', h: 'f4.h', p: 'f4.p' },
  ];

  let figs = [];
  onMount(() => {
    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduced) return;
    return subscribe(() => {
      figs.forEach((el, i) => {
        if (!el) return;
        const p = viewportP(el, 1.15);
        const rot = ((i % 2 ? -1 : 1) * (1 - p) * 5).toFixed(2);
        const dy = ((1 - p) * 26).toFixed(1);
        el.style.transform = `translate3d(0, ${dy}px, 0) rotate(${rot}deg)`;
      });
    });
  });
</script>

<section id="features">
  <div class="wrap">
    {#each feats as f, i}
      <Reveal>
        <div class="feat" class:reverse={i % 2 === 1}>
          <figure bind:this={figs[i]} class={f.hue}>
            <img src="assets/mascot-{f.mascot}.webp" alt="" width={f.mascot === 'studio' ? 640 : 480} height={f.mascot === 'studio' ? 640 : 480}>
          </figure>
          <div class="copy">
            <span class="badge {f.hue}"><Icon name={f.icon} size={22} /></span>
            <h3>{$t(f.h)}</h3>
            <p>{$t(f.p)}</p>
          </div>
        </div>
      </Reveal>
    {/each}
  </div>
</section>

<style>
  #features .wrap { display: grid; gap: clamp(72px, 10vw, 120px); }
  .feat {
    display: grid; grid-template-columns: 0.85fr 1fr; gap: clamp(32px, 6vw, 88px);
    align-items: center; max-width: 980px; margin-inline: auto; width: 100%;
  }
  .feat.reverse { grid-template-columns: 1fr 0.85fr; }
  .feat.reverse figure { order: 2; }
  figure { display: flex; justify-content: center; will-change: transform; }
  figure img { width: clamp(180px, 24vw, 280px); filter: drop-shadow(0 24px 30px oklch(0.4 0.05 300 / 0.22)); }
  .badge {
    display: inline-flex; align-items: center; justify-content: center;
    width: 46px; height: 46px; border-radius: 15px; margin-bottom: 18px;
  }
  .badge.coral { background: oklch(0.74 0.13 42 / 0.14); color: oklch(0.6 0.14 42); }
  .badge.violet { background: oklch(0.6 0.14 312 / 0.13); color: oklch(0.52 0.13 312); }
  .badge.sky { background: oklch(0.66 0.12 258 / 0.13); color: oklch(0.55 0.12 258); }
  .badge.rose { background: oklch(0.67 0.15 12 / 0.12); color: oklch(0.56 0.15 12); }
  h3 { font-size: clamp(1.45rem, 2.6vw, 1.9rem); }
  .copy p { margin-top: 14px; color: var(--muted); max-width: 46ch; text-wrap: pretty; }
  @media (max-width: 860px) {
    .feat, .feat.reverse { grid-template-columns: 1fr; text-align: center; gap: 24px; }
    .feat.reverse figure { order: 0; }
    .copy p { margin-inline: auto; }
  }
</style>
