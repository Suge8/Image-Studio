<script>
  import { onMount } from 'svelte';
  import { lang, t, setLang } from './i18n.js';
  import Icon from './Icon.svelte';

  let scrolled = false;
  onMount(() => {
    const onScroll = () => scrolled = scrollY > 24;
    addEventListener('scroll', onScroll, { passive: true });
    return () => removeEventListener('scroll', onScroll);
  });

  function switchLang(l) {
    if (document.startViewTransition) document.startViewTransition(() => setLang(l));
    else setLang(l);
  }
</script>

<nav class:scrolled>
  <div class="wrap">
    <a class="brand" href="#top">
      <img src="assets/logo.webp" alt="Image Studio icon">
      <span>Image Studio</span>
    </a>
    <div class="links">
      <a href="#wall">{$t('nav.wall')}</a>
      <a href="#features">{$t('nav.features')}</a>
      <a href="#demo">{$t('nav.demo')}</a>
      <a href="#download">{$t('nav.download')}</a>
    </div>
    <div class="langswitch" role="group" aria-label="Language">
      <button aria-pressed={$lang === 'en'} on:click={() => switchLang('en')}>EN</button>
      <button aria-pressed={$lang === 'zh'} on:click={() => switchLang('zh')}>中文</button>
    </div>
    <a class="gh" href="https://github.com/Suge8/Image-Studio" aria-label="GitHub">
      <svg width="21" height="21" viewBox="0 0 16 16" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z"/></svg>
    </a>
  </div>
</nav>

<style>
  nav { position: fixed; inset: 0 0 auto; z-index: 10; transition: background .35s, box-shadow .35s; }
  nav.scrolled {
    background: oklch(0.99 0.002 290 / 0.72);
    backdrop-filter: blur(18px) saturate(1.5);
    -webkit-backdrop-filter: blur(18px) saturate(1.5);
    box-shadow: 0 1px 0 oklch(0.92 0.006 290);
  }
  .wrap { width: min(1120px, 100% - 48px); margin-inline: auto; display: flex; align-items: center; gap: 28px; height: 64px; }
  .brand { display: flex; align-items: center; gap: 10px; font-family: var(--font-display); font-weight: 600; font-size: 17px; }
  .brand img { width: 30px; height: 30px; }
  .links { display: flex; gap: 24px; margin-left: auto; font-size: 14.5px; font-weight: 500; color: var(--muted); }
  .links a { transition: color .2s; }
  .links a:hover { color: var(--ink); }
  .langswitch { display: flex; background: oklch(0.93 0.006 290 / 0.7); border-radius: 999px; padding: 3px; }
  .langswitch button {
    border: 0; background: none; cursor: pointer; font: 600 12.5px var(--font-body);
    padding: 4px 11px; border-radius: 999px; color: var(--muted); transition: all .25s;
  }
  .langswitch button[aria-pressed="true"] { background: white; color: var(--ink); box-shadow: 0 1px 4px oklch(0.3 0.02 290 / 0.15); }
  .gh { display: flex; color: var(--muted); transition: color .2s; }
  .gh:hover { color: var(--ink); }
  @media (max-width: 860px) { .links { display: none; } }
</style>
