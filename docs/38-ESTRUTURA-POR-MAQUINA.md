# Estrutura de desenvolvimento por maquina

Este documento formaliza a separacao do desenvolvimento do `Grom Server` por
host operacional. A meta e aumentar seguranca, reduzir acoplamento acidental e
dar mais liberdade para evoluir cada maquina com autonomia.

## Principio

Cada maquina possui papel consolidado:

- `HP EliteDesk`: cerebro principal, borda segura, hospedagem e video
  analitico.
- `segunda maquina`: Home Assistant, resiliencia e backup dedicado.

Com isso, o desenvolvimento tambem passa a ser separado por maquina.

## Diretorios

```text
machines/
  hp-core/
    docs/
    configs/
    scripts/
  home-ops/
    docs/
    configs/
    scripts/
```

## Regra pratica

- Arquivos exclusivos do HP devem ficar em `machines/hp-core/`.
- Arquivos exclusivos da segunda maquina devem ficar no repositorio
  `HA_Back`.
- `machines/home-ops/` neste repositorio fica apenas como ponto de referencia
  da arquitetura e da integracao entre hosts.
- Artefatos compartilhados continuam na raiz somente enquanto forem realmente
  comuns aos dois hosts.
- Se um componente compartilhado passar a atender apenas uma maquina, ele deve
  ser migrado para o diretorio correspondente.

## O que continua centralizado

Permanece na raiz:

- documentacao institucional e visao geral;
- padroes comuns de rede, seguranca e governanca;
- changelog consolidado;
- materiais que ainda descrevem a arquitetura completa.

## O que deve nascer separado a partir de agora

No `hp-core`:
- runbooks de Proxmox, OPNsense, VM130, validadores e operacao do HP.

No `home-ops`:
- runbooks de Home Assistant;
- rotinas de replica de backup;
- restore drills da segunda maquina;
- integracoes domesticas e automacoes locais.

Observacao: a partir da separacao consolidada, esse conjunto deve nascer no
repositorio dedicado `HA_Back`, nao mais no `Grom_Server`.

## Resultado esperado

Essa divisao permite:

- menor risco de misturar configuracoes de hosts diferentes;
- maior clareza de ownership por maquina;
- evolucao paralela com menos colisao entre funcionalidades;
- rollback e auditoria mais previsiveis.
