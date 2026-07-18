<script>
  import { t } from './i18n.js';
  import Reveal from './Reveal.svelte';
  import SplitHeading from './SplitHeading.svelte';
  import Icon from './Icon.svelte';

  const tips = [
    { icon: 'clipboard-paste', key: 't1' },
    { icon: 'space', key: 't2' },
    { icon: 'image-plus', key: 't3' },
    { icon: 'rotate-ccw', key: 't4' },
  ];
</script>

<section class="tips">
  <div class="wrap">
    <Reveal>
      <div class="sec-head">
        <SplitHeading key="tips.h" />
      </div>
    </Reveal>
    <div class="row">
      {#each tips as tip, i}
        <Reveal delay={i * 0.08}>
          <div class="tip">
            <span class="tic"><Icon name={tip.icon} size={21} /></span>
            <span class="tlabel">{$t(tip.key)}</span>
          </div>
        </Reveal>
      {/each}
    </div>
  </div>
</section>

<style>
  .tips { padding-top: 0; }
  .row {
    display: flex; justify-content: center; flex-wrap: wrap;
    gap: clamp(24px, 5vw, 64px); margin-top: 44px;
  }
  .tip { display: flex; align-items: center; gap: 12px; }
  .tic {
    display: inline-flex; align-items: center; justify-content: center;
    width: 42px; height: 42px; border-radius: 13px;
    background: oklch(1 0 0 / 0.7); border: 1px solid oklch(0.92 0.006 290);
    color: oklch(0.58 0.12 42);
    box-shadow: 0 2px 10px oklch(0.3 0.02 290 / 0.05);
  }
  .tlabel { font-size: 14.5px; font-weight: 500; color: var(--muted); white-space: nowrap; }
</style>
