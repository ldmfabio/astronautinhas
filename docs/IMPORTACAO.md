# Migração do acervo do projeto Historinhas

## Regra de fidelidade

Uma aventura só pode sair de `draft: true` depois que o texto original da resposta do ChatGPT e a ilustração original tiverem sido recuperados e conferidos. Não reconstruir, resumir ou reescrever durante a migração.

Para cada aventura:

1. localizar a conversa original;
2. copiar integralmente o texto para o Markdown correspondente;
3. preservar o pedido original em `archive/prompts/` quando disponível;
4. salvar a ilustração em `assets/historias/NNN-slug/ilustracao.png`;
5. alterar `fonte.status_importacao` para `original-importado`;
6. executar `make validate`;
7. revisar visualmente;
8. somente então alterar `draft` para `false`.

Enquanto `draft: true`, a aventura não aparece no site nem entra no PDF/EPUB oficial.
