# Implantacao com hardware atual

Este documento fixa a decisao operacional: o desenvolvimento e a primeira implantacao seguem com os equipamentos ja disponiveis.

## Equipamentos em uso

- HP EliteDesk 800 G4 Mini, Intel Core i7-8700T (6C/12T), 16 GB DDR4.
- SSD original de 256 GB a ser substituido por SSD de 500 GB antes da instalacao.
- Adaptador Ugreen USB-A 3.0 para RJ45 2.5G.
- Switch TP-Link TL-SG108 8 portas Gigabit, nao gerenciavel.
- Unidade externa USB de 1 TB para backup operacional.
- DVR Intelbras iMHDX 3008 como gravador continuo principal.
- Roteador Mercusys MR80X/AX3000.
- Internet fibra 650 Mbps.

## Arquitetura aprovada para a Fase 1

```text
Internet/ONT ou roteador em bridge/AP
  -> HP EliteDesk porta onboard: WAN
  -> OPNsense VM100
  -> HP EliteDesk adaptador Ugreen: LAN
  -> Switch TP-Link TL-SG108
  -> LAN restrita 10.0.1.0/24
```

## O que ja fica separado

- Internet/WAN fica fisicamente separada da LAN.
- Todo trafego de entrada passa pelo OPNsense.
- Containers e VM ficam na rede interna `10.0.1.0/24`.
- Administracao remota deve passar por WireGuard.

## O que ainda nao fica separado

Sem switch gerenciavel, nao ha VLAN fisica para separar:

- Servidores.
- Administracao local.
- Usuarios comuns.
- Visitantes.
- Impressoras/IoT.

Por isso, durante a Fase 1, o switch deve receber apenas dispositivos confiaveis e necessarios.

## Regras de operacao da Fase 1

1. Nao conectar dispositivos de visitantes no switch do servidor.
2. Nao expor Proxmox, OPNsense, SSH, MySQL, Netdata ou Uptime Kuma na internet.
3. Publicar externamente apenas HTTPS dos sistemas e WireGuard, quando necessario.
4. Manter backup em HD externo e testar restauracao antes de colocar dados reais.
5. Documentar qualquer dispositivo fisico conectado ao switch.
6. Manter o DVR Intelbras responsavel pela gravacao continua.
7. Limitar o Frigate a deteccao, snapshots, eventos e videos curtos no SSD interno.

## Separacao de cargas

Neste HP EliteDesk ficam:

- Proxmox, OPNsense e os containers do Grom Server;
- VM130 Grom_Security com Frigate/NVR;
- cache, banco de eventos, snapshots e videos curtos;
- CT112 coordenando backups para a unidade USB de 1 TB.

Ficam fora deste equipamento:

- Home Assistant, previsto para outra maquina;
- servidor de backup definitivo, previsto para outra maquina;
- gravacao continua de todas as cameras, mantida no DVR Intelbras iMHDX 3008.

A unidade USB de 1 TB e o CT112 formam a camada de backup inicial. Quando o
servidor de backup dedicado entrar em operacao, ele deve receber uma replica
adicional sem eliminar imediatamente a copia USB local.

## Evolucao futura

O switch gerenciavel com VLAN continua recomendado para a rede definitiva, mas nao e requisito para continuar o desenvolvimento agora.

Quando adquirido, migrar para:

| Rede | Uso |
|---|---|
| VLAN servidores | Proxmox, containers, OPNsense LAN |
| VLAN administracao | PC de manutencao e acesso a paineis |
| VLAN usuarios | Estacoes comuns |
| VLAN isolada | Visitantes/IoT, se existir |
