import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const historias = defineCollection({
  loader: glob({ pattern: '**/*.md', base: '../content/historias' }),
  schema: z.object({
    id: z.string(), numero: z.number(), titulo: z.string(), planeta: z.string(), slug: z.string(),
    data: z.coerce.date(), imagem: z.string(), draft: z.boolean().default(true),
    publicacao: z.any().optional(), fonte: z.any().optional()
  })
});
export const collections = { historias };
