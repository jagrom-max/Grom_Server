# Principios de baixo custo sem comprometer seguranca

Este projeto deve usar ao maximo os equipamentos ja disponiveis, evitando compras prematuras. Baixo custo, neste contexto, nao significa reduzir seguranca; significa comprar apenas quando a compra reduz risco real, aumenta confiabilidade ou remove um gargalo comprovado.

## Decisao atual

Prosseguir com:

- HP EliteDesk 800 G4 Mini, i7-8700T, 16 GB RAM e SSD de 500 GB.
- Adaptador Ugreen USB 2.5G para separar WAN/LAN.
- Switch TP-Link TL-SG108 atual como LAN restrita.
- Unidade externa USB de 1 TB para backup inicial.
- DVR Intelbras iMHDX 3008 para gravacao continua, evitando consumir o SSD do servidor.
- OPNsense, Proxmox, WireGuard, Nginx, MySQL e BorgBackup.

## O que nao compraremos agora

- Switch PoE, pois nao ha AP/camera/telefone IP para alimentar.
- Switch gerenciavel por impulso, pois o Ugreen ja separa WAN/LAN fisicamente.
- Appliance dedicado de firewall, enquanto a carga e o risco operacional estiverem dentro da capacidade do HP EliteDesk.
- NAS, enquanto o backup com HD externo e rotacao manual atender ao RPO/RTO definidos.

## Compras que podem ser justificadas

| Prioridade | Item | Justificativa |
|---|---|---|
| Alta | Nobreak | Evita corrupcao de filesystem e banco em queda de energia |
| Media | Segundo HD externo | Permite rotacao offline e reduz risco de perda/ransomware |
| Media futura | Switch gerenciavel 8 portas | Necessario apenas quando houver segmentacao fisica por VLAN |
| Baixa futura | NAS/SSD externo | Conveniencia e redundancia local adicional |
| Baixa futura | Firewall dedicado | Separacao de responsabilidades se disponibilidade crescer |

## Criterios para aprovar uma compra

Uma compra so deve ser aprovada se responder "sim" a pelo menos um criterio:

1. Reduz risco de perda de dados.
2. Reduz superficie de ataque.
3. Aumenta disponibilidade em falha comum.
4. Remove gargalo comprovado por medicao.
5. Diminui manutencao manual recorrente.

## Limites que nao podem ser negociados

- Sem exposicao publica de paineis administrativos.
- Sem senhas no repositorio.
- Sem backup sem criptografia.
- Sem servico novo exposto antes de revisar firewall, logs e autenticacao.
- Sem conectar dispositivos nao confiaveis no switch da LAN restrita.

## Indicadores para reavaliar hardware

Reavaliar compras se ocorrer qualquer item:

- Mais de 6 acessos simultaneos frequentes.
- Uploads/documentos ficando lentos por rede ou disco.
- HD externo ocupando mais de 75%.
- Falhas de energia recorrentes sem nobreak.
- Necessidade de conectar usuarios/visitantes/dispositivos comuns na mesma rede fisica.
- Necessidade de cameras IP ou access points PoE.
