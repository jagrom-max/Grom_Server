# Separacao por maquina

Este diretorio organiza o desenvolvimento por host operacional, mantendo
responsabilidades, artefatos e futuras automacoes separados.

## Estrutura

- `hp-core/`: HP EliteDesk como cerebro principal do ecossistema.
- `home-ops/`: segunda maquina dedicada a Home Assistant e backup.

## Regra de uso

- Tudo que for exclusivo do HP deve nascer em `machines/hp-core/`.
- Tudo que for exclusivo da segunda maquina deve nascer em `machines/home-ops/`.
- Componentes compartilhados entre os dois hosts continuam em `docs/`,
  `configs/` e `scripts/` na raiz, desde que sejam claramente multi-host.
- Quando um arquivo raiz deixar de ser multi-host, ele deve ser migrado para o
  diretorio da maquina correta.
