import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://astronautinhas.com.br',
  integrations: [sitemap()],
  output: 'static'
});
