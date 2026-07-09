# Home Ops

Escopo da segunda maquina dedicada a automacao residencial e resiliencia.

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
maquina.
