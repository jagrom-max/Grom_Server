# Home Ops

Escopo da segunda maquina dedicada a automacao residencial e resiliencia.

## Ownership atual

O repositorio canonico desta maquina e o projeto `HA_Back`.

Neste `Grom_Server`, este diretorio permanece apenas como referencia de
arquitetura e ponto de integracao com o `hp-core`.

## Responsabilidades

- Home Assistant OS.
- automacoes e dashboards.
- Matter e integracoes domesticas.
- backups nativos do Home Assistant.
- replica dos backups do HP.
- testes de restore e retencao secundaria.

## Nao pertence a este host

- Proxmox principal do `Grom Server`.
- `Grom.Seg`.
- MySQL principal.
- Frigate/NVR principal.
- DVR Intelbras como gravador continuo.

## Subdiretorios esperados

- `docs/`: runbooks e arquitetura da segunda maquina.
- `configs/`: configuracoes locais, backups e integracoes.
- `scripts/`: automacoes de backup, restore e operacao do Home Assistant.

Manter neste diretorio apenas o que for claramente especifico da segunda
maquina e estritamente necessario para explicar a integracao com o `hp-core`.
