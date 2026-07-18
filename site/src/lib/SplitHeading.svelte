<script>
  import { onMount, tick } from 'svelte';
  import { t, lang, I18N } from './i18n.js';

  /* 逐词(中文逐字)升起标题。语言切换时按字典文案重新拆分。 */
  export let key;
  export let tag = 'h2';

  let el;
  let inView = false;
  let takeover = false; // true 后 DOM 由 split() 全权管理
  const reduced = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

  async function split(l) {
    takeover = true;
    await tick();
    if (!el) return;
    const text = I18N[l][key] ?? key;
    inView = false;
    el.textContent = '';
    const parts = l === 'zh' ? [...text] : text.split(/(\s+)/);
    let i = 0;
    parts.forEach(p => {
      if (!p.trim()) { el.append(p); return; }
      const line = document.createElement('span');
      line.className = 'wline';
      const w = document.createElement('span');
      w.className = 'w';
      w.style.setProperty('--wd', `${i * 0.05}s`);
      w.textContent = p;
      line.append(w);
      el.append(line);
      i++;
    });
    requestAnimationFrame(() => inView = true);
  }

  onMount(() => {
    if (reduced) return; // 保留 Svelte 管理的静态文本
    return lang.subscribe(l => split(l));
  });
</script>

<svelte:element this={tag} bind:this={el} class="split-h" class:in={inView}>{#if !takeover}{$t(key)}{/if}</svelte:element>

<style>
  .split-h :global(.wline) { display: inline-block; overflow: hidden; vertical-align: bottom; }
  .split-h :global(.w) {
    display: inline-block; transform: translateY(115%);
    transition: transform 0.75s var(--ease-out); transition-delay: var(--wd, 0s);
  }
  .split-h.in :global(.w) { transform: translateY(0); }
  @media (prefers-reduced-motion: reduce) {
    .split-h :global(.w) { transform: none; }
  }
</style>
