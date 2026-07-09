# HP Core

Escopo do HP EliteDesk 800 G4 Mini como cerebro principal do `Grom Server`.

## Responsabilidades

- Proxmox VE.
- OPNsense.
- `Grom.Seg`.
- MySQL.
- monitoramento.
- WireGuard.
- `Grom_Security/Frigate`.
- integracao controlada com o DVR Intelbras iMHDX 3008.
- backup local temporario via `CT112` e unidade USB.

## Nao pertence a este host

- Home Assistant.
- backup definitivo e replica fisicamente separada.
- gravacao continua principal de video.

## Subdiretorios esperados

- `docs/`: runbooks e decisoes exclusivas do HP.
- `configs/`: configs exclusivas do host e dos servicos nele executados.
- `scripts/`: automacoes de implantacao, validacao e manutencao do HP.

Manter neste diretorio apenas o que for claramente especifico do HP.
