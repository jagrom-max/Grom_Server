# Changelog - Grom Server

## [1.2.1] - 2026-07-09

### Arquitetura em dois nos
- Consolidado o HP EliteDesk como no principal do ecossistema, focado em hospedagem, borda segura, Grom.Seg e VM130 Grom_Security/Frigate.
- Formalizada a segunda maquina dedicada para Home Assistant e servidor de backup definitivo, com papel de resiliencia e alivio de carga do HP.
- Reclassificado o CT112 como camada de backup local temporaria, mantendo a unidade USB de 1 TB apenas como copia operacional inicial.
- Atualizados README, inventario e runbooks centrais para refletir a nova separacao entre cerebro principal, video/NVR e automacao/backup.

### Estrutura de desenvolvimento
- Criado o diretorio `machines/` com separacao inicial entre `hp-core/` e `home-ops/`.
- Formalizada a regra de desenvolvimento por maquina em `docs/38-ESTRUTURA-POR-MAQUINA.md`.
- Preparados subdiretorios dedicados para `docs/`, `configs/` e `scripts/` de cada host.

### Migracao controlada
- Adicionada matriz de migracao em `docs/39-MIGRACAO-HA-BACK.md` para classificar o que migrar, manter e aposentar entre `Grom_Server` e `HA_Back`.

### Clarificacao de plataforma
- Esclarecida no `README` a diferenca entre a base Debian do host Proxmox no HP e o uso de Ubuntu Server 24.04 LTS nos guests principais.

### Integracao com HA_Back
- Adicionado `scripts/backup/setup-replica-user.sh` para provisionar no CT112 o usuario SSH restrito `grom-replica`.
- Atualizados `docs/07-BACKUP-STRATEGY.md` e `docs/19-RUNBOOK-PRIMEIRA-IMPLANTACAO.md` com o fluxo recomendado de replica segura entre HP e `HA_Back`.

## [1.2.0] - 2026-07-06

### Plataforma HP EliteDesk
- Substituido o hardware alvo Beelink pelo HP EliteDesk 800 G4 Mini com Intel Core i7-8700T, 16 GB DDR4 e SSD de 500 GB.
- Recalculados RAM, vCPU e discos virtuais para caber com margem no SSD de 500 GB.
- Definido o DVR Intelbras iMHDX 3008 como gravador continuo principal e o Frigate/Grom_Security como camada de deteccao, eventos, snapshots e videos curtos.
- Mantida unidade externa USB de 1 TB como backup operacional inicial.
- Home Assistant e servidor de backup definitivo passam a ser previstos em outra maquina.
- Atualizados os roteiros de bancada, instalacao definitiva e uso dos pendrives para o novo equipamento.
- Adicionado `docs/37-INVENTARIO-EVOLUCAO-HP-ELITEDESK.md` como ponto de retomada, inventario de capacidade e registro das pendencias.

## [1.1.3] - 2026-06-18

### Dashboard e preparo local
- Atualizado dashboard operacional para modo visualizacao em tela unica, com cursor oculto em desktop e atualizacao automatica.
- Integrada identidade visual Grom na sidebar, com logo versionada em `apps/grom-seg/public/server/assets/`.
- Endurecido carregamento do dashboard com timeout, fallback seguro e bloqueio de requisicoes concorrentes.
- Adicionado `scripts/lab/preview-dashboard.ps1` para visualizar o painel por HTTP local sem depender do preview do editor.
- Adicionado `scripts/lab/prepare-local-release.ps1` para validar laboratorio, preview e gerar pacote candidato local.
- Adicionado `scripts/lab/export-release-usb.ps1` para copiar pacote/checksum e gerar instrucoes de transferencia para o Proxmox.
- Adicionado `scripts/lab/create-install-media.ps1` para gerar midia completa assistida em `D:\`, com pacote, checksum, instalador pos-Proxmox e roteiro de formatacao.
- Adicionado `scripts/lab/download-proxmox-iso.ps1` para baixar e validar o ISO oficial do Proxmox VE dentro da midia de instalacao.
- Auditoria local passou a exigir os assets do dashboard antes de liberar pacote.
- Adicionado `scripts/proxmox/final-local-deploy.sh` como orquestrador do host definitivo, reunindo auditoria, pre-deploy, baseline, deploy, pos-deploy, healthcheck e Go/No-Go.
- Adicionado `docs/33-IMPLANTACAO-DEFINITIVA-EQUIPAMENTO.md` como roteiro curto de transferencia e execucao no mini PC definitivo.
- Adicionado `docs/34-IMPLANTACAO-EM-BANCADA.md` para orientar a implantacao no equipamento definitivo antes da rede destinataria.
- Adicionado `docs/35-MIDIA-INSTALACAO-COMPLETA.md` para orientar o pacote completo de instalacao assistida.

## [1.1.2] - 2026-06-18

### Desenvolvimento seguro
- Adicionado fluxo de laboratorio em `scripts/lab/run-safe-lab-checks.sh` e `.ps1` para validar o repositorio sem tocar Proxmox, `/etc`, rede, containers ou servicos reais.
- Adicionado `scripts/lab/simulate-deploy-plan.sh` para gerar plano auditavel da implantacao sem executar comandos reais.
- Adicionado ambiente ficticio `.lab/grom.env` gerado localmente, com segredos falsos fortes e dominio `.invalid`.
- Formalizado o amadurecimento em unidade separada antes de qualquer implantacao definitiva.

## [1.1.1] - 2026-06-17

### Confiabilidade operacional
- Separado o desenvolvimento do `Grom_Security` como sistema/repositorio irmao do `Grom_Server`.
- Adicionado `scripts/proxmox/audit-repository.sh` para auditar pacote local antes do deploy.
- Adicionado `scripts/build-release.sh` para gerar pacote de release com manifesto e checksum.
- Adicionado `scripts/proxmox/capacity-baseline.sh` para medir CPU, RAM, disco, rede, backup externo e margem para SigePol/Security.
- Adicionado `scripts/proxmox/production-readiness-check.sh` como gate Go/No-Go antes de producao.
- Adicionado `scripts/proxmox/restore-drill.sh` para ensaio seguro de restore sem sobrescrever producao.
- Adicionado `scripts/proxmox/operational-health-check.sh` para monitorar VM/CT, servicos, recursos, backups e portas administrativas.
- Deploy passa a instalar `grom-operational-health-check.sh` e agenda-lo a cada 15 minutos no Proxmox host.
- Adicionado dashboard operacional em `apps/grom-seg/public/server/`, com acesso restrito por LAN/VPN.
- Adicionado `docs/31-GO-NOGO-PRODUCAO.md` com criterios de liberacao do Server, Grom_SigePol e Grom_Security.
- Integrada auditoria local ao `scripts/deploy-all.sh` antes da validacao de ambiente.
- Validador pre-deploy passou a exigir a presenca do auditor local no pacote.

### Seguranca
- Auditoria local verifica sintaxe Bash, arquivos essenciais, CRLF em scripts, possiveis segredos operacionais versionados e aninhamento indevido do `Grom_Security`.

## [1.1.0] - 2026-06-15

### Segurança e LGPD
- Definida transicao arquitetural para `Grom.Seg` como sistema unificado.
- Documentado plano DNS para `grom.seg.br` no Registro.br/Dominios.br.
- Adicionada arquitetura com VM120 Home Assistant OS e VM130 Grom_Security.
- Adicionado baseline de arquitetura segura e compromisso LGPD.
- Adicionado checklist de pre-implantacao para os proximos 45 dias.
- Adicionada matriz de riscos e controles com rotina mensal de auditoria.
- Adicionada politica operacional de automacao e baixa manutencao.
- Adicionado principio de baixo custo sem comprometer seguranca, solidez e confiabilidade.
- Adicionada politica para conta Google dedicada e uso de Drive apenas com backups criptografados.
- Integrada a conta operacional `grom.servidor@gmail.com` em alertas, SSL e runbooks.
- Monitoramento definido como acesso apenas por LAN/VPN.
- CrowdSec deixou de ser instalacao automatica via script remoto; agora e opcional controlado.
- Removido patch fragil no JavaScript do Proxmox para ocultar aviso de assinatura.
- FastAPI base sem OpenAPI/Swagger publico.
- Pagina temporaria PHP trocada por healthcheck minimo.

### Backup e recuperacao
- Adicionado `scripts/proxmox/backup-containers.sh` para backup `vzdump` da VM OPNsense e containers.
- Backup de arquivos deixou de depender de SSH root entre containers.
- Backup logico de banco mantido no CT112 com BorgBackup.
- Rotina de backup Proxmox integrada ao orquestrador quando o HD externo estiver montado.

### Rede e acesso remoto
- Resolvido conflito de IDs: VM100 para OPNsense; CT110-CT114 para servicos.
- Adicionado script de revogacao de clientes WireGuard.
- Ajustado template WireGuard e permissoes dos arquivos de clientes.
- Formalizada a Fase 1 com hardware atual: separacao WAN/LAN via adaptador Ugreen e switch TL-SG108 como LAN restrita sem VLAN.

### Confiabilidade operacional
- Adicionado `.gitattributes` para preservar LF em scripts Linux.
- Adicionados diagramas Mermaid, matriz de portas, matriz de hosts e runbook da primeira implantacao.
- Adicionado validador pre-deploy para bloquear pacote incompleto, variaveis ausentes e placeholders.
- Adicionado validador pos-deploy para verificar VM/CT, servicos, backup e exposicao publica.
- Adicionado relatorio operacional mensal com envio por e-mail quando SMTP estiver ativo.
- Adicionado banco principal `grom_seg` e usuario `grom_seg_user` para a aplicacao unificada.
- Adicionado script de criacao das VMs Home Assistant/Grom_Security e compose base do Grom_Security.
- Adicionado runbook inicial de implantacao do Grom_Security com MQTT, compose e retencao.
- Adicionada matriz de cameras/DVR com inventario exemplo para RTSP/ONVIF, OCR, garagem e lista branca.
- Definida politica de gravacao: continua no DVR, eventos no Grom_Security e evidencias importantes em backup externo criptografado.
- Definida preferencia por OpenVINO com GPU integrada Intel no Grom_Security, com fallback por CPU e Coral apenas como compra futura se necessario.
- Adicionado suporte opcional a segundo HD externo em `/mnt/backup-external-2` para copia B/offline e evidencias importantes.
- Criado motor de regras inicial do Grom_Security com regras de rua, pedestre, corredor lateral, fundos, garagem, sensor+camera e sabotagem.
- Criada pasta raiz `Grom_Security/` como subprojeto separado, preparada para futuro repositorio GitHub privado.
- Adicionada API FastAPI inicial do Grom_Security, Dockerfile, testes, scripts de instalacao/deploy e deploy remoto via Proxmox.
- Adicionados scripts de preparacao offline para dependencias Python e imagens Docker do Grom_Security.
- Adicionada persistencia SQLite de eventos, protecao opcional por `X-Grom-Token`, healthcheck Docker e scripts MQTT/OpenVINO.
- Adicionado painel interno `/panel` para visualizar eventos e editar ativacao/severidade das regras do Grom_Security.
- Adicionados simulador de eventos e auditoria de alteracoes de regras no painel interno.
- Adicionado preflight automatizado do Grom_Security para validar prontidao da VM antes/depois do deploy.
- Endurecido o deploy do Grom_Security com token local automatico, `.env` preservado e storage de evidencias preparado.
- Adicionado rollback local do Grom_Security a partir dos snapshots operacionais gerados antes do deploy remoto.
- Adicionados modos operacionais de alarme no Grom_Security para tablet/celular com auditoria.
- Adicionado monitor operacional para TV com mosaico, overlay de alerta e destaque de zona no mapa.
- Adicionado reconhecimento auditavel de alertas ativos do monitor operacional.
- Adicionada outbox de notificacoes externas para Telegram, WhatsApp, SMS e e-mail em modo dry-run.
- Adicionado processamento seguro da outbox de notificacoes, com endpoint protegido e script para automacao.
- Preparado provedor SMTP/e-mail para notificacoes reais, com falha segura quando credenciais nao estiverem completas.
- Definida a conta tecnica `grom.servidor@gmail.com` como disparador oficial de e-mail do Grom_Security.
- Padronizada `grom.servidor@gmail.com` como comunicacao externa oficial do ecossistema Grom.
- Scripts sensiveis agora exigem variaveis de segredo antes do deploy.
- Composer passou a ser instalado com verificacao de assinatura.
- Adicionados scripts de preparo offline/downloads e pacote `dist/grom-scripts.zip`.
- Adicionado verificador de prontidao do Proxmox host.
- Adicionado relay SMTP via Gmail com `msmtp`, usando senha de app apenas em ambiente local.
- Adicionado sync externo opcional via `rclone crypt` para Google Drive.

## [1.0.0] - 2026-06-14

### Adicionado
- Estrutura completa do projeto
- Documentação de 12 capítulos cobrindo toda a infraestrutura
- Scripts de automação para todas as fases de implantação
- Script orquestrador `deploy-all.sh` para implantação automatizada
- Configurações prontas para Nginx, MySQL, Fail2Ban, WireGuard
- Hardening de segurança em 7 camadas
- Backup automatizado com BorgBackup (3-2-1 strategy)
- Monitoramento com Netdata + Uptime Kuma
- Watchdog com auto-recovery de serviços
- VPN WireGuard com 5 clientes pré-configurados
- Health check automático a cada 6 horas
- Atualizações de segurança automáticas

### Infraestrutura
- Proxmox VE 9.x como hypervisor
- OPNsense como firewall com IDS/IPS (Suricata)
- Ubuntu 24.04 LTS como SO base dos containers
- Nginx como web server / reverse proxy
- PHP 8.3-FPM para Grom_web
- Python 3.12 / FastAPI para Grom Documental
- MySQL 8.0 otimizado para 3GB RAM
- WireGuard VPN para acesso remoto
- SSL/TLS via Let's Encrypt com renovação automática

### Hardware
- Beelink Mini PC i5-1035G7, 16GB RAM, 1TB SSD
- Adaptador Ugreen USB-A 3.0 to RJ45 2.5G
- Switch TP-Link TL-SG108 (8 portas gigabit)
- HD Externo 1TB para backup
- Rede: 650Mbps cabo, Mercusys AX3000 Wi-Fi 6

### Domínio
- grom.seg.br (domínio principal)
- grom.seg.br (Grom.Seg unificado)
- web.grom.seg.br e docs.grom.seg.br (legados/transicao)
- vpn.grom.seg.br (WireGuard VPN)
- monitoramento interno/VPN apenas, sem subdominio publico
