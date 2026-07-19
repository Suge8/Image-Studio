<script>
  import { onMount } from 'svelte';
  import ShaderBG from '$lib/ShaderBG.svelte';
  import Nav from '$lib/Nav.svelte';
  import Hero from '$lib/Hero.svelte';
  import Wall from '$lib/Wall.svelte';
  import Demo from '$lib/Demo.svelte';
  import Features from '$lib/Features.svelte';
  import Tips from '$lib/Tips.svelte';
  import Download from '$lib/Download.svelte';
  import Footer from '$lib/Footer.svelte';
  import { subscribe } from '$lib/motion.js';

  let progressEl;
  onMount(() => {
    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduced) { progressEl.style.display = 'none'; return; }
    return subscribe(({ scrollY }) => {
      const max = document.body.scrollHeight - innerHeight;
      progressEl.style.transform = `scaleX(${(max > 0 ? scrollY / max : 0).toFixed(4)})`;
    });
  });
</script>

<ShaderBG />
<div class="noise"></div>
<div class="progress" bind:this={progressEl}></div>

<Nav />
<Hero />
<main>
  <Wall />
  <Demo />
  <Features />
  <Tips />
  <Download />
</main>
<Footer />
