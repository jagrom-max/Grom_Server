# Migracao controlada para HA_Back

Este documento define como migrar, com seguranca, o conteudo relacionado a
`Home Assistant` e `backup dedicado` do `Grom_Server` para o projeto
`HA_Back`, evitando retrabalho, perda de contexto e limpeza prematura.

## Objetivo

Separar responsabilidades por projeto sem degradar robustez, seguranca,
confiabilidade, longevidade do sistema ou depender de alta interferencia
humana.

## Regra principal

- O `Grom_Server` continua dono do `hp-core`.
- O `HA_Back` passa a ser dono da segunda maquina.
- Integracoes entre os dois continuam documentadas no `Grom_Server`.
- Conteudo exclusivo da segunda maquina deve sair gradualmente do
  `Grom_Server` ou permanecer aqui apenas como resumo de referencia.
- Nada deve ser apagado antes de existir versao valida e revisada no
  `HA_Back`.

## Estado atual da migracao

Em `2026-07-09`, a base operacional do `HA_Back` ja existe com:

- arquitetura e plataforma da segunda maquina;
- politica de storage;
- replica dos backups do HP;
- restore drill;
- automacao local com `systemd`;
- validacao local antes de empacotamento;
- pacote remoto-first para implantacao.

Com isso, o `Grom_Server` entra na fase de consolidacao:

- manter aqui apenas o que pertence ao `hp-core`;
- manter apenas resumos de integracao sobre `home-ops`;
- evitar novos runbooks operacionais da segunda maquina neste repositorio.

## Classificacao dos artefatos

### Migrar para HA_Back

Esses artefatos devem ser reescritos ou absorvidos pelo `HA_Back`, porque o
foco principal agora pertence a segunda maquina:

| Origem no Grom_Server | Acao | Motivo |
|---|---|---|
| `docs/26-HOME-ASSISTANT-GROM-SECURITY.md` | Migrar a parte de Home Assistant, backup dedicado, restore e operacao do segundo host | Mistura hoje conteudo de dois hosts distintos |
| `docs/07-BACKUP-STRATEGY.md` | Migrar a estrategia do backup dedicado e da replica do HP | O documento ainda e centrado no CT112 e precisa de versao propria do segundo host |
| `docs/19-RUNBOOK-PRIMEIRA-IMPLANTACAO.md` | Extrair apenas as etapas futuras que tratam da segunda maquina | O runbook principal deve continuar focado no HP |
| `docs/18-DIAGRAMAS-E-MATRIZES.md` | Migrar os diagramas especificos do host Home Assistant/backup | A parte multi-host fica; o operacional da segunda maquina sai |
| `docs/25-DNS-REGISTRO-BR.md` | Migrar somente notas locais de acesso ao Home Assistant via VPN/LAN, se precisarem de runbook proprio | No `Grom_Server`, DNS publico continua central |
| `docs/27-GROM-SECURITY-IMPLANTACAO.md` | Migrar apenas a secao de integracao operacional com Home Assistant | A VM130 continua no HP, mas o lado Home Assistant e do outro projeto |

### Manter no Grom_Server

Esses artefatos permanecem aqui porque continuam descrevendo o `hp-core`, a
arquitetura compartilhada ou a integracao entre hosts:

| Arquivo | Motivo |
|---|---|
| `README.md` | Visao geral do ecossistema e da arquitetura em dois nos |
| `docs/01-PLANO-IMPLANTACAO.md` | Continua sendo plano do HP e do deploy inicial do `Grom_Server` |
| `docs/02-HARDWARE-REDE.md` | Rede principal, reservas e topologia do `hp-core` |
| `docs/04-OPNSENSE-FIREWALL.md` | Firewall e matriz de trafego entre os hosts |
| `docs/13-CHECKLIST-PRE-IMPLANTACAO.md` | Checklist do HP, CT112 e fase provisoria |
| `docs/14-IMPLANTACAO-HARDWARE-ATUAL.md` | Consolidacao do HP e separacao fisica das cargas |
| `docs/22-VALIDACAO-POS-DEPLOY.md` | Validador do `Grom_Server` e do host HP |
| `docs/23-RELATORIO-OPERACIONAL-MENSAL.md` | Saude do HP, CT112, VM130 e rotinas do host principal |
| `docs/28-CAMERAS-DVR-VIDEO.md` | DVR, Frigate, streams e video analitico permanecem no HP |
| `docs/29-GROM-SECURITY-REGRAS.md` | Motor de regras do `Grom_Security` no HP |
| `docs/37-INVENTARIO-EVOLUCAO-HP-ELITEDESK.md` | Inventario do host HP |
| `scripts/backup/*` | Ainda sao scripts do CT112 no HP, que seguem ativos na fase provisoria |
| `scripts/proxmox/*` | Sao automacoes do HP e do Proxmox host |

### Reduzir no Grom_Server, depois da migracao

Esses trechos devem ser reduzidos ou removidos daqui somente apos o `HA_Back`
ter sua versao consolidada:

| Origem | Condicao para aposentar | Resultado esperado |
|---|---|---|
| Secoes de Home Assistant em `docs/26-HOME-ASSISTANT-GROM-SECURITY.md` | Existir documento equivalente e melhor no `HA_Back` | Aqui fica apenas resumo de integracao |
| Partes de servidor futuro em `docs/07-BACKUP-STRATEGY.md` | Estrategia do segundo host estiver fechada no `HA_Back` | Aqui fica apenas backup provisoria do HP e ponto de replica |
| Referencias operacionais detalhadas a restore da segunda maquina | Restore drill da segunda maquina documentado no `HA_Back` | Aqui fica so a exigencia de teste |
| Diagramas detalhados do host Home Assistant | Diagramas proprios existirem no `HA_Back` | Aqui ficam apenas fluxos entre hosts |

## Sequencia de migracao recomendada

1. Migrar primeiro a documentacao da segunda maquina no `HA_Back`.
2. Validar hardware, storage, restore e rotina de replica no `HA_Back`.
3. Revisar o `Grom_Server` e substituir secoes detalhadas por resumos e
   referencias ao `HA_Back`.
4. So depois remover conteudo duplicado ou obsoleto do `Grom_Server`.

## Ordem de prioridade

### Prioridade alta

- alinhar README e estrutura por ownership;
- manter no `Grom_Server` apenas o lado HP da replica;
- revisar documentos mistos e transformalos em documentos de integracao.

### Prioridade media

- diagramas especificos do segundo host;
- rotina de retencao secundaria;
- integracao Home Assistant <-> Grom_Security.

### Prioridade baixa

- limpeza final de duplicidades no `Grom_Server`;
- consolidacao estetica e reorganizacao secundaria.

## Criterio de limpeza segura

Um conteudo do `Grom_Server` so pode ser limpo quando:

- houver versao correspondente no `HA_Back`;
- essa versao estiver tecnicamente melhor;
- as referencias cruzadas tiverem sido atualizadas;
- nao houver risco de quebrar runbook do HP;
- o historico de integracao entre os hosts continuar claro.

## Decisao operacional atual

Por enquanto:

- nao apagar historico util;
- nao mover scripts do CT112 para fora do `Grom_Server`;
- nao remover referencias a Home Assistant do ecossistema;
- tratar o `HA_Back` como fonte operacional da segunda maquina;
- manter o `Grom_Server` como fonte de arquitetura do HP e integracao entre
  hosts.
