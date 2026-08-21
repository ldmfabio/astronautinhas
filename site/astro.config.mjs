import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

const isGitHubPages = process.env.GITHUB_PAGES === 'true';

export default defineConfig({
  site: isGitHubPages ? 'https://ldmfabio.github.io' : 'https://astronautinhas.com.br',
  base: isGitHubPages ? '/astronautinhas' : '/',
  trailingSlash: 'always',
  integrations: [sitemap()],
  output: 'static'
});
