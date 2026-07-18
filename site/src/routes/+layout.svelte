<script>
  import '../app.css';
  import { onMount } from 'svelte';
  import { setLang, lang } from '$lib/i18n.js';

  let { children } = $props();

  onMount(() => {
    // 初始化 html lang 与标题
    let cur;
    const un = lang.subscribe(l => cur = l);
    setLang(cur);
    un();
  });
</script>

{@render children()}
