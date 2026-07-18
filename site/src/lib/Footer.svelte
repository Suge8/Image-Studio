<script>
  import { t } from './i18n.js';
</script>

<footer>
  <div class="wrap">
    <span>{$t('ft.made')} <a href="https://github.com/Suge8">Suge8</a></span>
    <span class="sp">·</span>
    <span>Apache-2.0</span>
    <div class="right">
      <a href="https://github.com/Suge8/Image-Studio">GitHub</a>
      <a href="https://github.com/Suge8/Image-Studio/releases">{$t('ft.rel')}</a>
      <a href="https://github.com/Suge8/Image-Studio/issues">{$t('ft.iss')}</a>
    </div>
  </div>
</footer>

<style>
  footer { padding: 40px 0; font-size: 13.5px; color: var(--muted); }
  .wrap { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  .sp { opacity: 0.4; }
  .right { margin-left: auto; display: flex; gap: 20px; }
  a:hover { color: var(--ink); }
</style>
