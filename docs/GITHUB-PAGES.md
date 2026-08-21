# Publicação no GitHub Pages

O site Astro é publicado a partir da mesma fonte Markdown usada pelo livro e pelo EPUB.

## URL inicial

Enquanto não houver domínio próprio configurado, o endereço esperado é:

`https://ldmfabio.github.io/astronautinhas/`

## Ativar no GitHub

1. Abra **Settings → Pages** no repositório.
2. Em **Build and deployment → Source**, selecione **GitHub Actions**.
3. Salve, se o GitHub solicitar confirmação.

A partir daí, todo push no `main` que alterar `site/`, `content/` ou `assets/` executará `.github/workflows/site.yml` e publicará o site.

## Repositório privado

GitHub Pages em repositório privado requer um plano GitHub que ofereça Pages para repositórios privados. Se a conta não tiver esse recurso, não torne este repositório público sem revisar `archive/`, pois ele contém os registros históricos dos prompts.

Uma alternativa segura é manter este repositório privado e publicar apenas o resultado compilado em outro repositório público ou em outro provedor.

## Publicar uma história

Uma história aparece no site apenas quando seu frontmatter estiver com:

```yaml
draft: false
publicacao:
  site: true
```

E a ilustração deve existir no caminho indicado por `imagem`.

Antes de liberar uma história, rode:

```bash
make validate
```

## Publicação automática

O workflow faz:

```text
Markdown + imagens
       ↓
validação
       ↓
Astro build
       ↓
GitHub Pages artifact
       ↓
deploy
```

## Domínio próprio

Quando `astronautinhas.com.br` for configurado como domínio do Pages, a configuração do Astro pode ser simplificada para publicar diretamente na raiz do domínio. Até lá, o build usa automaticamente o prefixo `/astronautinhas/`.
