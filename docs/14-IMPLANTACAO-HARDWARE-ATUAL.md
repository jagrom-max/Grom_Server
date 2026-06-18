# Implantacao com hardware atual

Este documento fixa a decisao operacional: o desenvolvimento e a primeira implantacao seguem com os equipamentos ja disponiveis.

## Equipamentos em uso

- Mini PC Beelink i5-1035G7, 16 GB RAM, SSD 1 TB.
- Adaptador Ugreen USB-A 3.0 para RJ45 2.5G.
- Switch TP-Link TL-SG108 8 portas Gigabit, nao gerenciavel.
- HD externo Toshiba 1 TB para backup.
- Roteador Mercusys MR80X/AX3000.
- Internet fibra 650 Mbps.

## Arquitetura aprovada para a Fase 1

```text
Internet/ONT ou roteador em bridge/AP
  -> Mini PC porta onboard: WAN
  -> OPNsense VM100
  -> Mini PC adaptador Ugreen: LAN
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

## Evolucao futura

O switch gerenciavel com VLAN continua recomendado para a rede definitiva, mas nao e requisito para continuar o desenvolvimento agora.

Quando adquirido, migrar para:

| Rede | Uso |
|---|---|
| VLAN servidores | Proxmox, containers, OPNsense LAN |
| VLAN administracao | PC de manutencao e acesso a paineis |
| VLAN usuarios | Estacoes comuns |
| VLAN isolada | Visitantes/IoT, se existir |
