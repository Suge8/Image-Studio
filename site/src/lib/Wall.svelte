<script>
  import { onMount } from 'svelte';
  import { t, lang } from './i18n.js';
  import { subscribe } from './motion.js';
  import Reveal from './Reveal.svelte';
  import SplitHeading from './SplitHeading.svelte';

  const rows = [
    {
      dir: 1,
      imgs: [
        ["wall-isometric-studio", "Isometric artist studio diorama, generated with Image Studio", "等距艺术家工作室模型，Image Studio 生成"],
        ["wall-neon-portrait", "Neon-lit portrait in the rain, generated with Image Studio", "霓虹雨夜人像，Image Studio 生成"],
        ["wall-ukiyoe-cat", "Ukiyo-e cat riding a great wave, generated with Image Studio", "浮世绘冲浪猫，Image Studio 生成"],
        ["wall-dewdrop-macro", "Macro dewdrop on a purple petal, generated with Image Studio", "紫色花瓣上的微距露珠，Image Studio 生成"],
        ["wall-paper-city", "Miniature paper craft city at night, generated with Image Studio", "夜晚的纸艺微缩城市，Image Studio 生成"],
        ["wall-art-nouveau", "Art nouveau floral portrait poster, generated with Image Studio", "新艺术风格花卉人像海报，Image Studio 生成"],
      ]
    },
    {
      dir: -1,
      imgs: [
        ["wall-mars-poster", "Retro Mars travel poster, generated with Image Studio", "复古火星旅行海报，Image Studio 生成"],
        ["wall-watercolor-fox", "Watercolor fox in an autumn forest, generated with Image Studio", "水彩秋林狐狸，Image Studio 生成"],
        ["wall-origami-crane", "Gradient origami crane, generated with Image Studio", "渐变折纸鹤，Image Studio 生成"],
        ["wall-brutalist-fog", "Brutalist architecture in thick fog, generated with Image Studio", "雾中粗野主义建筑，Image Studio 生成"],
        ["wall-galaxy-painter", "Double exposure painter silhouette with galaxy, generated with Image Studio", "双重曝光星河画师剪影，Image Studio 生成"],
        ["wall-ocean-aerial", "Aerial turquoise waves meeting the beach, generated with Image Studio", "绿松石色海浪航拍，Image Studio 生成"],
      ]
    }
  ];

  let tracks = [];
  onMount(() => {
    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    const measure = () => tracks.forEach(t => t && (t.half = t.el.scrollWidth / 2));
    measure();
    addEventListener('resize', measure);
    if (reduced) return () => removeEventListener('resize', measure);
    const un = subscribe(({ vel }) => {
      tracks.forEach(t => {
        if (!t || !t.half) return;
        t.hover += (t.hoverT - t.hover) * 0.08;
        const speed = (0.55 + Math.min(Math.abs(vel) * 0.35, 9)) * t.hover * t.dir;
        t.off = ((t.off + speed) % t.half + t.half) % t.half;
        t.el.style.transform = `translate3d(${(-t.off - (t.dir < 0 ? t.half : 0)).toFixed(1)}px, 0, 0)`;
      });
    });
    return () => { un(); removeEventListener('resize', measure); };
  });

  function bindTrack(node, dir) {
    const rec = { el: node, dir, off: 0, half: 0, hover: 1, hoverT: 1 };
    tracks.push(rec);
    const row = node.parentElement;
    const enter = () => rec.hoverT = 0.12;
    const leave = () => rec.hoverT = 1;
    row.addEventListener('pointerenter', enter);
    row.addEventListener('pointerleave', leave);
    return { destroy() {
      tracks = tracks.filter(x => x !== rec);
      row.removeEventListener('pointerenter', enter);
      row.removeEventListener('pointerleave', leave);
    } };
  }
</script>

<section class="wall" id="wall">
  <div class="wrap">
    <Reveal>
      <div class="sec-head">
        <SplitHeading key="wall.h" />
        <p>{$t('wall.cap')}</p>
      </div>
    </Reveal>
  </div>
  <div class="mq">
    {#each rows as row}
      <div class="mq-row">
        <div class="mq-track" use:bindTrack={row.dir}>
          {#each [...row.imgs, ...row.imgs] as [src, altEn, altZh], i}
            <img
              src="assets/{src}.webp" width="640" height="640" loading="lazy" decoding="async"
              alt={i < row.imgs.length ? ($lang === 'zh' ? altZh : altEn) : ''}
              aria-hidden={i >= row.imgs.length}
            >
          {/each}
        </div>
      </div>
    {/each}
  </div>
</section>

<style>
  .wall { overflow: clip; }
  .wall .sec-head { margin-bottom: 52px; }
  @media (max-width: 860px) { .wall { --mq-s: 170px; } }
  .mq { display: grid; gap: 20px; }
  .mq-row {
    overflow: hidden;
    -webkit-mask-image: linear-gradient(90deg, transparent, black 9%, black 91%, transparent);
    mask-image: linear-gradient(90deg, transparent, black 9%, black 91%, transparent);
  }
  .mq-track { display: flex; gap: 20px; width: max-content; will-change: transform; }
  .mq-track img {
    width: var(--mq-s, 250px); height: var(--mq-s, 250px); object-fit: cover;
    border-radius: 20px;
    box-shadow: 0 10px 28px -8px oklch(0.4 0.05 300 / 0.28);
    transition: transform 0.45s var(--ease-out);
  }
  .mq-track img:nth-child(odd) { transform: rotate(-1.2deg); }
  .mq-track img:nth-child(even) { transform: rotate(1.1deg); }
  .mq-track img:hover { transform: rotate(0deg) scale(1.045); z-index: 1; position: relative; }
</style>
