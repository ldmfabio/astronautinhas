# Arquitetura editorial

`content/` e `assets/` formam a fonte única do acervo.

```text
content/*.md + assets/
        |
        +-- site/ -----------------> site estático Astro
        +-- scripts/build_book.py -> PDF (Pandoc + XeLaTeX)
        +--------------------------> EPUB (Pandoc)
```

## Princípios

- Markdown contém conteúdo e metadados neutros.
- Não inserir componentes Astro, comandos LaTeX ou marcação exclusiva de EPUB nas histórias.
- Layout e regras de cada destino ficam em `site/`, `publishing/` e `scripts/`.
- `archive/` preserva o processo de criação sem ser publicado automaticamente.
