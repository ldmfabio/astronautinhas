# Publicação no GitHub Pages

O site Astro é publicado a partir da mesma fonte Markdown usada pelo livro e pelo EPUB.

## URL

`https://ldmfabio.github.io/astronautinhas/`

## Configurar o GitHub Pages

1. Abra **Settings → Pages** no repositório.
2. Em **Build and deployment → Source**, selecione **Deploy from a branch**.
3. Em **Branch**, escolha `gh-pages`.
4. Em **Folder**, escolha `/ (root)`.
5. Salve.

A branch `gh-pages` deve conter somente o site compilado. O conteúdo editorial continua em `main`.

## Publicar o site

A partir de `main`, com o repositório limpo e Git/Node/Python instalados, execute:

```bash
make deploy-pages
```

O comando:

```text
valida o conteúdo
→ instala dependências do site
→ gera o build Astro para /astronautinhas/
→ cria ou atualiza a branch gh-pages
→ envia o site compilado ao GitHub
```

A publicação usa `site/dist/` e adiciona `.nojekyll` à branch pública.

## Publicar uma história

Uma história aparece no site apenas quando seu frontmatter estiver com:

```yaml
draft: false
publicacao:
  site: true
```

A ilustração também deve existir no caminho indicado por `imagem`.

## Segurança do deploy

`make deploy-pages` interrompe a publicação se houver alterações locais não commitadas. Assim evitamos publicar um build que não corresponda a um commit conhecido.

A branch `gh-pages` é tratada como artefato gerado. Não edite arquivos nela manualmente.

## Domínio próprio

Enquanto o endereço for `https://ldmfabio.github.io/astronautinhas/`, o build usa automaticamente o prefixo `/astronautinhas/`.

Quando `astronautinhas.com.br` for configurado como domínio próprio, será necessário ajustar a configuração do Astro para publicar na raiz do domínio.
