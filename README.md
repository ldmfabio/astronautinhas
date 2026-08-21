# Astronautinhas 🚀🍝

Acervo editorial das aventuras do **Astronauta Espaguete** e da **Astronauta Penne**.

Os arquivos em `content/` e `assets/` são a fonte única. Site, PDF e EPUB são produtos derivados.

```text
content/*.md + assets/
        |
        +-- Astro ------------> astronautinhas.com.br
        +-- Pandoc + LaTeX ---> PDF do livro
        +-- Pandoc -----------> EPUB
```

## Estado do acervo

A estrutura inicial contém **39 aventuras catalogadas**, em ordem cronológica. Todas permanecem em `draft: true` até que o texto e a ilustração originais do projeto Historinhas sejam recuperados e conferidos. Isso evita transformar reconstruções em registros históricos.

## Estrutura

- `content/historias/`: uma história por Markdown
- `content/paginas/`: páginas editoriais do livro/site
- `assets/historias/`: ilustrações originais
- `archive/`: prompts, conversas e referências de origem
- `site/`: site Astro
- `publishing/`: templates de PDF/EPUB
- `scripts/`: validação e geração

## Comandos

```bash
make validate
make site-install
make site-dev
make site-build
make pdf
make epub
```

Histórias com `draft: true` não aparecem no site e não entram no livro/eBook.

O PDF é preparado para começar cada história em página esquerda (par) e colocar a respectiva ilustração na página direita (ímpar).

Veja `docs/IMPORTACAO.md` e `docs/ARQUITETURA.md`.
