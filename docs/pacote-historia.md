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


## Comando oficial de preparacao

Dentro de uma conversa de uma historia do projeto Astronautinhas, depois que o texto da historia e a ilustracao principal estiverem aprovados, a frase:

```text
Prepare esta historia completa para o site.
```

e o gatilho oficial para preparar o pacote completo daquela historia.

A preparacao deve:

1. preservar integralmente a historia aprovada;
2. preservar a ilustracao principal aprovada;
3. usar a ilustracao principal como referencia mestre de identidade visual;
4. dividir a narrativa em exatamente 6 cenas diferentes, em ordem cronologica;
5. manter Espaguete, Penne e quaisquer outros personagens visualmente consistentes em todas as cenas;
6. gerar uma pagina de quadrinhos com exatamente 6 quadros, um para cada cena e na mesma ordem cronologica;
7. gerar um livrinho com exatamente 6 imagens separadas, correspondentes as mesmas 6 cenas;
8. nunca reutilizar a ilustracao principal como pagina do livrinho ou como pagina de quadrinhos;
9. nunca repetir a mesma imagem em duas paginas do livrinho;
10. usar a historia "Planeta Caca ao Tesouro" como referencia estrutural e visual para quadrinhos e livrinho;
11. gerar o ZIP final compativel com `scripts/importar_historia.ps1`.

### Padrao visual oficial

A historia "Planeta Caca ao Tesouro" define o comportamento esperado e deve ser tratada como referencia obrigatoria nao apenas de conteudo, mas tambem de composicao visual, enquadramento, hierarquia e posicionamento dos elementos.

#### Quadrinhos

A pagina de quadrinhos deve manter o mesmo padrao visual aprovado em "Planeta Caca ao Tesouro":

- exatamente 6 quadros, organizados em sequencia cronologica;
- cada quadro deve ter uma legenda propria posicionada na faixa superior do respectivo quadro;
- a legenda deve permanecer visualmente separada da ilustracao por uma faixa/faixa de pergaminho no topo, seguindo o mesmo padrao de "Planeta Caca ao Tesouro";
- os baloes de fala devem ficar dentro do quadro correspondente e proximos ao personagem que fala;
- a cauda do balao deve apontar claramente para o personagem correto;
- os baloes nao devem cobrir rostos, elementos narrativos importantes ou a legenda;
- o tamanho, formato, contorno e estilo tipografico dos baloes devem seguir o mesmo padrao visual aprovado;
- a leitura visual deve acontecer naturalmente da esquerda para a direita e de cima para baixo;
- a composicao geral da pagina deve seguir a mesma logica de distribuicao dos quadros usada em "Planeta Caca ao Tesouro".

#### Livrinho

Cada pagina do livrinho deve manter o mesmo padrao visual aprovado das paginas individuais de "Planeta Caca ao Tesouro":

- uma unica cena grande por pagina;
- a legenda da cena deve ficar na faixa superior da pagina, sempre na mesma regiao visual usada no modelo aprovado;
- a legenda deve usar o mesmo tipo de faixa/pergaminho, hierarquia e estilo tipografico;
- o balao de fala deve ficar na regiao superior ou superior-lateral da cena, conforme o modelo aprovado, sempre associado visualmente ao personagem que fala;
- a cauda do balao deve apontar claramente para o personagem correspondente;
- o balao nao deve cobrir o rosto dos personagens nem elementos narrativos importantes;
- o posicionamento relativo entre legenda, balao, personagens e cena deve permanecer consistente entre pagina-01.png e pagina-06.png;
- as seis paginas devem parecer partes do mesmo livrinho, com composicao, margens, bordas, proporcoes e hierarquia visual consistentes;
- pagina-01.png estabelece o modelo de composicao para pagina-02.png a pagina-06.png;
- a cena muda de acordo com a cronologia, mas o padrao de layout nao deve mudar arbitrariamente entre paginas.


- `ilustracao.png`: imagem-resumo da historia;
- `quadrinhos/pagina-01.png`: uma pagina em formato de quadrinhos contendo 6 quadros cronologicos distintos;
- `livrinho/pagina-01.png` a `pagina-06.png`: as mesmas 6 etapas narrativas, uma cena por pagina;
- legenda, baloes, personagens e elementos narrativos devem respeitar o mesmo posicionamento relativo do modelo aprovado;
- a identidade dos personagens deve permanecer constante entre todas as imagens.

O fluxo de geracao visual deve acontecer na propria conversa da historinha. O importador local nao gera imagens: ele recebe o ZIP pronto, valida a estrutura e impede que imagens exatamente repetidas sejam publicadas.

### Validacoes visuais estruturais do importador

O script exige:

- exatamente `quadrinhos/pagina-01.png`;
- exatamente seis paginas:
  - `livrinho/pagina-01.png`
  - `livrinho/pagina-02.png`
  - `livrinho/pagina-03.png`
  - `livrinho/pagina-04.png`
  - `livrinho/pagina-05.png`
  - `livrinho/pagina-06.png`
- as seis paginas do livrinho precisam ter hashes SHA-256 diferentes;
- nenhuma pagina do livrinho pode ser copia exata de `ilustracao.png`;
- `quadrinhos/pagina-01.png` nao pode ser copia exata de `ilustracao.png`;
- a pagina de quadrinhos nao pode ser copia exata de uma pagina do livrinho.

Essas verificacoes nao substituem a revisao visual humana, mas evitam automaticamente o erro de empacotar a mesma imagem repetida.
