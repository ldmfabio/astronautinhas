# Pacote automatizado de história

Este documento define o formato aceito por \`scripts/importar_historia.ps1\`.

## Objetivo

O pacote permite importar uma história completa para o repositório sem alterar diretamente \`main\` ou \`gh-pages\`. O script cria uma feature branch, valida o conteúdo, executa o build, faz commit/push e abre uma Pull Request. O merge permanece manual.

## Estrutura do ZIP

O ZIP pode conter os arquivos diretamente na raiz ou dentro de uma única pasta superior.

\`\`\`text
NNN-slug/
├── historia.md
├── prompt.md
├── ilustracao.png
├── quadrinhos/
│   └── pagina-01.png
└── livrinho/
    ├── pagina-01.png
    ├── pagina-02.png
    └── ...
\`\`\`

Itens obrigatórios:

- \`historia.md\`
- \`prompt.md\`
- \`ilustracao.png\`
- pelo menos um \`.png\` diretamente em \`quadrinhos/\`
- pelo menos um \`.png\` diretamente em \`livrinho/\`

## historia.md

O arquivo deve seguir o schema já usado em \`content/historias/\`. O número e o slug definem automaticamente o destino final.

Exemplo para a história 135:

\`\`\`yaml
---
id: "135"
numero: 135
titulo: "O Planeta Exemplo"
planeta: "Exemplo"
slug: "planeta-exemplo"
categoria: "diversos"
data: 2026-11-19
imagem: "../../assets/historias/135-planeta-exemplo/ilustracao.png"
draft: false
publicacao:
  site: true
  livro: true
  epub: true
fonte:
  projeto: "Historinhas"
  titulo_conversa: "Planeta Exemplo"
  autor_prompt: "..."
  prompt_arquivo: "../../archive/prompts/135-planeta-exemplo.md"
  status_importacao: "original-importado"
  prompt_original_importado: true
  texto_original_importado: true
  imagem_original_importada: true
---
\`\`\`

Para conteúdo publicado (\`draft: false\`), o validador existente exige \`status_importacao: "original-importado"\` e a imagem principal.

## Destino final

Um pacote com \`numero: 135\` e \`slug: planeta-exemplo\` será importado para:

\`\`\`text
content/historias/135-planeta-exemplo.md
archive/prompts/135-planeta-exemplo.md
assets/historias/135-planeta-exemplo/
├── ilustracao.png
└── quadrinhos/
    ├── pagina-01.png
    └── livrinho/
        ├── pagina-01.png
        ├── pagina-02.png
        └── ...
\`\`\`

## Execução

Com o repositório sem alterações locais:

\`\`\`powershell
.\scripts\importar_historia.ps1 "C:\caminho\135-planeta-exemplo.zip"
\`\`\`

O script:

1. confirma Git, GitHub CLI, Python e npm;
2. exige árvore de trabalho limpa;
3. bloqueia execução iniciada em \`gh-pages\`;
4. troca para \`main\` e executa \`git pull --ff-only origin main\`;
5. valida o pacote e procura colisões de número e slug;
6. cria \`feature/historia-NNN-slug\`;
7. copia texto, prompt, ilustração, quadrinhos e Livrinho;
8. executa \`python scripts/validate_content.py\`;
9. executa \`npm --prefix site run build\`;
10. faz commit e push somente da feature branch;
11. abre uma PR para \`main\` com \`gh pr create\`;
12. nunca executa merge e nunca modifica \`gh-pages\`.

Se alguma validação ou build falhar, a PR não é aberta.
