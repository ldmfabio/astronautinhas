import { readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const historiasRoot = fileURLToPath(new URL('../../../assets/historias/', import.meta.url));

function getAssetFolder(story) {
  const imagePath = String(story.data.imagem ?? '').replace(/\\/g, '/');
  const marker = 'assets/historias/';
  const relative = imagePath.includes(marker) ? imagePath.split(marker)[1] : '';
  return relative.split('/')[0] || null;
}

export async function getComicPages(story) {
  const folder = getAssetFolder(story);
  if (!folder) return [];

  const dir = join(historiasRoot, folder, 'quadrinhos');

  try {
    const entries = await readdir(dir, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith('.png'))
      .map((entry) => entry.name)
      .sort((a, b) => a.localeCompare(b, 'pt-BR', { numeric: true }))
      .map((name) => `assets/historias/${folder}/quadrinhos/${name}`);
  } catch {
    return [];
  }
}
