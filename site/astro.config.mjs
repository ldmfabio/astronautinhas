import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://astronautinhas.com.br',
  base: '/',
  trailingSlash: 'always',
  integrations: [sitemap()],
  output: 'static'
});
