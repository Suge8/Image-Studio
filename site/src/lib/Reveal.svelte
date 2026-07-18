<script>
  import { onMount } from 'svelte';

  /* IntersectionObserver 渐显容器。无 JS / reduced-motion 时内容默认可见。 */
  export let delay = 0;
  export let pop = false;
  let el;
  let inView = false;

  onMount(() => {
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) { inView = true; return; }
    const io = new IntersectionObserver(es => es.forEach(e => {
      if (e.isIntersecting) { inView = true; io.unobserve(el); }
    }), { threshold: 0.18 });
    io.observe(el);
    return () => io.disconnect();
  });
</script>

<div bind:this={el} class="rv" class:pop class:in={inView} style="--d:{delay}s">
  <slot />
</div>

<style>
  .rv { opacity: 0; translate: 0 30px; }
  .rv.in {
    opacity: 1; translate: 0 0;
    transition: opacity 0.8s var(--ease-out), translate 0.8s var(--ease-out);
    transition-delay: var(--d, 0s);
  }
  .pop { scale: 0.86; }
  .pop.in { scale: 1; transition: opacity 0.7s var(--ease-out), scale 0.7s var(--ease-out); transition-delay: var(--d, 0s); }
  @media (prefers-reduced-motion: reduce) {
    .rv, .pop { opacity: 1; translate: 0 0; scale: 1; }
  }
</style>
