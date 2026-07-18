import adapter from '@sveltejs/adapter-vercel';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').SvelteConfig} */
const config = {
  preprocess: vitePreprocess(),
  kit: { adapter: adapter({ runtime: 'nodejs22.x' }) }
};

export default config;
