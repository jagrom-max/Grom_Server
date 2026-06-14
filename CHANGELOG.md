# Changelog - Grom Server

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
- Proxmox VE 8.x como hypervisor
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
- web.grom.seg.br (Grom_web)
- docs.grom.seg.br (Grom Documental)
- vpn.grom.seg.br (WireGuard VPN)
- monitor.grom.seg.br (Monitoramento - futuro)
